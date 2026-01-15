// routes/ai-recommendations.js - 🔥 FIXED VERSION
const express = require('express');
const router = express.Router();
const axios = require('axios');
const admin = require('firebase-admin');
const Rental = require('../models/Rental');

// 🔥 PYTHON ML SERVICE URL
const ML_SERVICE_URL = process.env.PYTHON_ML_URL || 'http://python-ml:8001';

// ==================== MIDDLEWARE ====================
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token', error: err.message });
  }
};
/**
 * 🎨 Xác định marker color dựa trên user preferences
 */
function _getMarkerColorScheme(userPreferences) {
  // Ví dụ:
  // - User thích trọ rẻ → marker đỏ/cam (giá rẻ)
  // - User thích biệt thự cao cấp → marker xanh (cao cấp)
  // - User không có preference → marker xanh trung lập
  
  return {
    primary: '#1E40AF',      // Xanh (recommended)
    secondary: '#DC2626',    // Đỏ (far/expensive)
    accent: '#059669',       // Xanh lá (perfect match)
    neutral: '#6B7280'       // Xám (low confidence)
  };
}

// ==================== 🤖 AI PERSONALIZED RECOMMENDATIONS ====================

/**
 * GET /api/ai/recommendations/personalized
 * Lấy gợi ý cá nhân hóa từ AI model - 🔥 INCLUDES COORDINATES
 */
router.get('/recommendations/personalized', authMiddleware, async (req, res) => {
  try {
    const { 
      limit = 10, 
      latitude, 
      longitude, 
      radius = 10,
      minPrice,
      maxPrice 
    } = req.query;
    
    const userId = req.userId;

    console.log(`🤖 [AI-RECOMMEND] User: ${userId}`);
    console.log(`   Location: (${latitude}, ${longitude}), radius: ${radius}km`);
    console.log(`   Price: ${minPrice || 'any'} - ${maxPrice || 'any'}`);

    // ✅ BƯỚC 1: Gọi Python ML service
    let aiRecommendations = [];
    let isAIRecommendation = false;
    
    try {
      console.log(`🔗 Calling ML service: ${ML_SERVICE_URL}/recommend/personalized`);
      
      // 🔥 FIX: Gửi request với đầy đủ thông tin
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/personalized`,
        {
          userId: userId,  // 🔥 SỬA: user_id -> userId (match Python API)
          n_recommendations: parseInt(limit) * 3,
          use_location: true  // 🔥 THÊM: enable geographic features
        },
        {
          timeout: 5000,
          headers: { 'Content-Type': 'application/json' }
        }
      );

      if (mlResponse.data && mlResponse.data.recommendations) {
        aiRecommendations = mlResponse.data.recommendations;
        isAIRecommendation = true;
        console.log(`✅ AI returned ${aiRecommendations.length} recommendations`);
        
        // 🔥 DEBUG: Log first recommendation structure
        if (aiRecommendations.length > 0) {
          const first = aiRecommendations[0];
          console.log(`   Sample recommendation:`);
          console.log(`     - rentalId: ${first.rentalId}`);
          console.log(`     - score: ${first.score}`);
          console.log(`     - coordinates: ${JSON.stringify(first.coordinates)}`);
          console.log(`     - locationBonus: ${first.locationBonus}`);
          console.log(`     - finalScore: ${first.finalScore}`);
        }
      }
    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      console.log('⚠️ Falling back to popularity-based recommendations');
      isAIRecommendation = false;
    }

    // ✅ BƯỚC 2: Xây dựng query MongoDB
    let rentalIds = [];
    
    if (isAIRecommendation && aiRecommendations.length > 0) {
      // Dùng AI recommendations
      rentalIds = aiRecommendations.map(r => r.rentalId);
      console.log(`📌 Using AI recommendations: ${rentalIds.length} items`);
    } else {
      // Fallback: Lấy popular posts
      console.log('📊 Using popularity fallback');
      const popularRentals = await Rental.find({ status: 'available' })
        .sort({ views: -1, createdAt: -1 })
        .limit(parseInt(limit) * 3)
        .select('_id')
        .lean();
      
      rentalIds = popularRentals.map(r => r._id.toString());
    }

    if (rentalIds.length === 0) {
      return res.json({
        success: true,
        rentals: [],
        total: 0,
        isAIRecommendation: false,
        message: 'No recommendations available'
      });
    }

    // ✅ BƯỚC 3: Lọc theo vị trí (nếu có)
    let geoFilter = {};
    
    if (latitude && longitude) {
      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);
      const radiusInMeters = parseFloat(radius) * 1000;

      if (!isNaN(lat) && !isNaN(lon) && lat !== 0 && lon !== 0) {
        geoFilter = {
          'location.coordinates': {
            $geoWithin: {
              $centerSphere: [[lon, lat], radiusInMeters / 6378100]
            }
          }
        };
        console.log(`📍 Geo filter applied: center (${lon}, ${lat}), radius ${radius}km`);
      }
    }

    // ✅ BƯỚC 4: Lọc theo giá (nếu có)
    let priceFilter = {};
    if (minPrice || maxPrice) {
      priceFilter.price = {};
      if (minPrice) priceFilter.price.$gte = Number(minPrice);
      if (maxPrice) priceFilter.price.$lte = Number(maxPrice);
      console.log(`💰 Price filter:`, priceFilter.price);
    }

    // ✅ BƯỚC 5: Query MongoDB
    const query = {
      _id: { $in: rentalIds },
      status: 'available',
      ...geoFilter,
      ...priceFilter
    };

    console.log(`🔍 MongoDB query with ${rentalIds.length} rental IDs`);

    const rentals = await Rental.find(query)
      .limit(parseInt(limit))
      .lean();

    console.log(`✅ Found ${rentals.length} rentals matching criteria`);

    // ✅ BƯỚC 6: Merge AI metadata + coordinates
    const rentalsWithScore = rentals.map(rental => {
      const aiRec = aiRecommendations.find(
        r => r.rentalId === rental._id.toString()
      );
      
      // 🔥 THÊM: Extract coordinates từ MongoDB hoặc từ AI response
      const coords = aiRec?.coordinates || {
        longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
        latitude: rental.location?.coordinates?.coordinates?.[1] || 0
      };
      
      return {
        ...rental,
        // 🔥 THÊM: Coordinates cho frontend map
        location: {
          ...rental.location,
          longitude: coords.longitude,
          latitude: coords.latitude,
          coordinates: {
            type: 'Point',
            coordinates: [coords.longitude, coords.latitude]
          }
        },
        aiScore: aiRec?.score || 0,
        locationBonus: aiRec?.locationBonus || 1.0,  // 🔥 THÊM
        finalScore: aiRec?.finalScore || aiRec?.score || 0,  // 🔥 THÊM
        isAIRecommended: isAIRecommendation,
        recommendationReason: aiRec?.method || 'Popular'
      };
    });

    // Sort by finalScore (cao -> thấp)
    rentalsWithScore.sort((a, b) => (b.finalScore || 0) - (a.finalScore || 0));

    console.log(`✅ Response ready: ${rentalsWithScore.length} rentals with AI metadata`);

    res.json({
      success: true,
      rentals: rentalsWithScore,
      total: rentalsWithScore.length,
      isAIRecommendation,
      filters: {
        location: latitude && longitude ? { latitude, longitude, radius } : null,
        price: { minPrice, maxPrice }
      },
      message: isAIRecommendation 
        ? '🤖 Gợi ý riêng cho bạn từ trợ lý AI'
        : '📊 Gợi ý phổ biến'
    });

  } catch (err) {
    console.error('❌ Error in AI recommendations:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get AI recommendations',
      error: err.message
    });
  }
});

/**
 * GET /api/ai/recommendations/nearby
 * Lấy AI recommendations kết hợp với nearby search - 🔥 INCLUDES COORDINATES
 */
router.get('/recommendations/nearby/:rentalId', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.params;
    const { limit = 10, radius = 10 } = req.query;
    const userId = req.userId;

    console.log(`🤖 [AI-NEARBY] User: ${userId}, Rental: ${rentalId}`);
    console.log(`   Radius: ${radius}km, Limit: ${limit}`);

    // Lấy rental chính
    const mainRental = await Rental.findById(rentalId).lean();
    if (!mainRental) {
      return res.status(404).json({ 
        success: false, 
        message: 'Rental not found' 
      });
    }

    const [lon, lat] = mainRental.location?.coordinates?.coordinates || [0, 0];

    if (lat === 0 && lon === 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid coordinates for this rental'
      });
    }

    console.log(`📍 Main rental coordinates: (${lon}, ${lat})`);

    // Gọi AI recommendations
    let aiRecommendations = [];
    let isAIRecommendation = false;

    try {
      console.log(`🔗 Calling ML service: ${ML_SERVICE_URL}/recommend/similar`);
      
      // 🔥 FIX: Gửi rentalId và enable location
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/similar`,
        {
          rentalId: rentalId,  // 🔥 SỬA: rental_id -> rentalId
          n_recommendations: parseInt(limit) * 2,
          use_location: true  // 🔥 THÊM: enable geographic proximity
        },
        { 
          timeout: 5000, 
          headers: { 'Content-Type': 'application/json' } 
        }
      );

      if (mlResponse.data?.recommendations) {
        aiRecommendations = mlResponse.data.recommendations;
        isAIRecommendation = true;
        console.log(`✅ AI returned ${aiRecommendations.length} similar recommendations`);
        
        // 🔥 DEBUG: Log sample
        if (aiRecommendations.length > 0) {
          const first = aiRecommendations[0];
          console.log(`   Sample:`);
          console.log(`     - rentalId: ${first.rentalId}`);
          console.log(`     - distance_km: ${first.distance_km}`);
          console.log(`     - coordinates: ${JSON.stringify(first.coordinates)}`);
        }
      }
    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      console.log('⚠️ Falling back to geospatial search');
    }

    // Query nearby với AI priority
    const radiusInMeters = parseFloat(radius) * 1000;

    const nearbyRentals = await Rental.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: [lon, lat] },
          distanceField: 'distance',
          maxDistance: radiusInMeters,
          spherical: true,
          query: {
            _id: { $ne: mainRental._id },
            status: 'available'
          }
        }
      },
      { $limit: parseInt(limit) * 2 }
    ]);

    console.log(`📍 Found ${nearbyRentals.length} nearby rentals`);

    // Merge AI scores + coordinates
    const rentalsWithAI = nearbyRentals.map(rental => {
      const aiRec = aiRecommendations.find(
        r => r.rentalId === rental._id.toString()
      );
      
      // 🔥 THÊM: Coordinates từ AI atau MongoDB
      const coords = aiRec?.coordinates || {
        longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
        latitude: rental.location?.coordinates?.coordinates?.[1] || 0
      };
      
      return {
        ...rental,
        // 🔥 THÊM: Coordinates cho frontend map
        location: {
          ...rental.location,
          longitude: coords.longitude,
          latitude: coords.latitude,
          coordinates: {
            type: 'Point',
            coordinates: [coords.longitude, coords.latitude]
          }
        },
        aiScore: aiRec?.score || 0,
        locationBonus: aiRec?.locationBonus || 1.0,  // 🔥 THÊM
        finalScore: aiRec?.finalScore || aiRec?.score || 0,  // 🔥 THÊM
        distance_km: aiRec?.distance_km || (rental.distance / 1000).toFixed(2),
        isAIRecommended: !!aiRec,
        distanceKm: (rental.distance / 1000).toFixed(2)
      };
    });

    // Sort: finalScore trước, sau đó distance
    rentalsWithAI.sort((a, b) => {
      if ((b.finalScore || 0) !== (a.finalScore || 0)) {
        return (b.finalScore || 0) - (a.finalScore || 0);
      }
      return (a.distance || 0) - (b.distance || 0);
    });

    const finalRentals = rentalsWithAI.slice(0, parseInt(limit));

    console.log(`✅ Response ready: ${finalRentals.length} rentals`);
    console.log(`   AI recommended: ${finalRentals.filter(r => r.isAIRecommended).length}`);

    res.json({
      success: true,
      rentals: finalRentals,
      total: finalRentals.length,
      isAIRecommendation,
      mainRental: {
        id: mainRental._id,
        title: mainRental.title,
        coordinates: [lon, lat]  // 🔥 THÊM
      },
      message: isAIRecommendation 
        ? '🤖 Gợi ý thông minh dành riêng cho bạn'
        : '📍 Gợi ý gần đây'
    });

  } catch (err) {
    console.error('❌ Error in AI nearby recommendations:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get AI nearby recommendations',
      error: err.message
    });
  }
});
/**
 * 🎯 GET /api/ai/recommendations/personalized/context
 * Gợi ý cá nhân hóa với context (map center, zoom, device, etc.)
 * 
 * 🔥 UPDATED: Include explanation & marker priority
 */
router.get('/recommendations/personalized/context', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const {
      latitude,
      longitude,
      radius = 10,
      zoom_level = 15,
      time_of_day = 'morning',
      device_type = 'mobile',
      limit = 10,
      impressions = '' // Comma-separated rental IDs already shown
    } = req.query;

    console.log(`🎯 [PERSONALIZED] User: ${userId}`);
    console.log(`   Map center: (${latitude}, ${longitude}), radius: ${radius}km`);
    console.log(`   Device: ${device_type}, Time: ${time_of_day}`);
    console.log(`   Impressions: ${impressions.split(',').length} items`);

    // Parse impressions
    const impressionList = impressions 
      ? impressions.split(',').filter(id => id.trim())
      : [];

    // Build context for ML service
    const context = {
      map_center: latitude && longitude ? [parseFloat(longitude), parseFloat(latitude)] : null,
      zoom_level: parseInt(zoom_level),
      search_radius: parseInt(radius),
      time_of_day,
      device_type,
      impressions: impressionList,
      scroll_depth: parseFloat(req.query.scroll_depth) || 0.5,
      weekday: new Date().toLocaleDateString('en-US', { weekday: 'long' })
    };

    try {
      // 🔥 CALL ML SERVICE WITH CONTEXT
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/personalized`,
        {
          userId,
          n_recommendations: parseInt(limit) * 2,
          use_location: true,
          radius_km: parseInt(radius),
          context  // 🔥 PASS CONTEXT
        },
        { timeout: 5000, headers: { 'Content-Type': 'application/json' } }
      );

      if (!mlResponse.data?.recommendations) {
        throw new Error('Invalid ML response');
      }

      const aiRecommendations = mlResponse.data.recommendations;
      console.log(`✅ AI returned ${aiRecommendations.length} personalized recommendations`);

      // Log sample with explanation
      if (aiRecommendations.length > 0) {
        const first = aiRecommendations[0];
        console.log(`   Top recommendation:`);
        console.log(`     - rentalId: ${first.rentalId}`);
        console.log(`     - finalScore: ${first.finalScore.toFixed(2)}`);
        console.log(`     - confidence: ${(first.confidence * 100).toFixed(0)}%`);
        console.log(`     - explanation:`, first.explanation);
      }

      // Get rental IDs
      const rentalIds = aiRecommendations.map(r => r.rentalId);

      // Query MongoDB
      let geoFilter = {};
      if (latitude && longitude) {
        const lat = parseFloat(latitude);
        const lon = parseFloat(longitude);
        const radiusInMeters = parseInt(radius) * 1000;

        if (!isNaN(lat) && !isNaN(lon)) {
          geoFilter = {
            'location.coordinates': {
              $geoWithin: {
                $centerSphere: [[lon, lat], radiusInMeters / 6378100]
              }
            }
          };
          console.log(`📍 Geo filter applied: ${radius}km`);
        }
      }

      // Fetch from MongoDB
      const rentals = await Rental.find({
        _id: { $in: rentalIds },
        status: 'available',
        ...geoFilter
      }).limit(parseInt(limit)).lean();

      console.log(`✅ Found ${rentals.length} rentals in MongoDB`);

      // 🔥 MERGE WITH AI METADATA
      const rentalsWithPersonalization = rentals.map((rental, idx) => {
        const aiRec = aiRecommendations.find(r => r.rentalId === rental._id.toString());
        
        const coords = aiRec?.coordinates || {
          longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
          latitude: rental.location?.coordinates?.coordinates?.[1] || 0
        };

        return {
          ...rental,
          // 🔥 PERSONALIZATION DATA
          location: {
            ...rental.location,
            longitude: coords.longitude,
            latitude: coords.latitude,
            coordinates: {
              type: 'Point',
              coordinates: [coords.longitude, coords.latitude]
            }
          },
          // 🔥 AI SCORES & EXPLANATION
          aiScore: aiRec?.score || 0,
          locationBonus: aiRec?.locationBonus || 1.0,
          preferenceBonus: aiRec?.preferenceBonus || 1.0,
          timeBonus: aiRec?.timeBonus || 1.0,
          finalScore: aiRec?.finalScore || 0,
          confidence: aiRec?.confidence || 0.5,  // 신용도
          markerPriority: aiRec?.markers_priority || idx + 1,  // Thứ tự trên map
          explanation: aiRec?.explanation || {},  // 🔥 WHY gợi ý?
          // For map visualization
          markerSize: Math.max(1, Math.min(5, (aiRec?.finalScore || 0) / 20)),  // 1-5
          markerOpacity: (aiRec?.confidence || 0.5) * 0.9 + 0.1,  // 0.1-1.0
          isAIRecommended: true,
          recommendationReason: aiRec?.method || 'similar'
        };
      });

      console.log(`✅ Response ready: ${rentalsWithPersonalization.length} rentals with AI metadata`);

      res.json({
        success: true,
        rentals: rentalsWithPersonalization,
        total: rentalsWithPersonalization.length,
        context,
        personalization: {
          isPersonalized: true,
          method: 'collaborative_filtering_with_preferences',
          avgConfidence: rentalsWithPersonalization.length > 0 
            ? rentalsWithPersonalization.reduce((s, r) => s + (r.confidence || 0), 0) / rentalsWithPersonalization.length
            : 0,
          avgMarkerSize: rentalsWithPersonalization.length > 0
            ? rentalsWithPersonalization.reduce((s, r) => s + r.markerSize, 0) / rentalsWithPersonalization.length
            : 1
        },
        mapHints: {
          // Gợi ý cách hiển thị map
          centerCoordinates: [parseFloat(longitude), parseFloat(latitude)],
          zoomLevel: parseInt(zoom_level),
          radiusKm: parseInt(radius),
          markerColorScheme: _getMarkerColorScheme(req.userProperties)  // Dựa trên preference
        }
      });

    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      
      // FALLBACK: popularity-based
      const popularRentals = await Rental.find({ status: 'available' })
        .sort({ views: -1, createdAt: -1 })
        .limit(parseInt(limit))
        .lean();

      const fallbackRentals = popularRentals.map((rental, idx) => ({
        ...rental,
        location: {
          ...rental.location,
          longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
          latitude: rental.location?.coordinates?.coordinates?.[1] || 0,
          coordinates: {
            type: 'Point',
            coordinates: rental.location?.coordinates?.coordinates || [0, 0]
          }
        },
        finalScore: 0,
        confidence: 0.3,
        markerPriority: idx + 1,
        markerSize: 2,
        markerOpacity: 0.6,
        explanation: { popularity: 'Bài đăng phổ biến' }
      }));

      res.json({
        success: true,
        rentals: fallbackRentals,
        total: fallbackRentals.length,
        isAIRecommendation: false,
        message: '⚠️ Sử dụng gợi ý phổ biến (ML service tạm thời không khả dụng)'
      });
    }

  } catch (err) {
    console.error('❌ Error in personalized recommendations:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get personalized recommendations',
      error: err.message
    });
  }
});

/**
 * 🤔 GET /api/ai/explain/:userId/:rentalId
 * Giải thích CHI TIẾT tại sao bài này được gợi ý
 */
router.get('/explain/:userId/:rentalId', authMiddleware, async (req, res) => {
  try {
    const { userId, rentalId } = req.params;

    // Check ownership
    if (req.userId !== userId && !req.isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    console.log(`🤔 [EXPLAIN] User: ${userId}, Rental: ${rentalId}`);

    try {
      // Call ML service to explain
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/explain`,
        null,
        {
          params: { userId, rentalId },
          timeout: 5000
        }
      );

      if (!mlResponse.data?.explanation) {
        return res.status(404).json({
          success: false,
          message: 'Explanation not found'
        });
      }

      const explanation = mlResponse.data.explanation;

      console.log(`✅ Explanation generated`);
      console.log(`   Confidence: ${(explanation.scores.confidence * 100).toFixed(0)}%`);
      console.log(`   Reasons:`, Object.keys(explanation.reasons));

      // Get rental details for enrichment
      const rental = await Rental.findById(rentalId)
        .select('title price propertyType location area')
        .lean();

      res.json({
        success: true,
        explanation: {
          ...explanation,
          rental: rental ? {
            id: rental._id,
            title: rental.title,
            price: rental.price,
            propertyType: rental.propertyType
          } : null
        }
      });

    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      res.status(503).json({
        success: false,
        message: 'ML service unavailable',
        error: mlError.message
      });
    }

  } catch (err) {
    console.error('❌ Error:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to generate explanation',
      error: err.message
    });
  }
});

/**
 * 👤 GET /api/ai/user-preferences/:userId
 * Lấy thông tin preferences của user
 */
router.get('/user-preferences/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.userId !== userId && !req.isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    console.log(`👤 [PREFERENCES] User: ${userId}`);

    try {
      const mlResponse = await axios.get(
        `${ML_SERVICE_URL}/user-preferences/${userId}`,
        { timeout: 5000 }
      );

      if (!mlResponse.data?.preferences) {
        return res.json({
          success: false,
          message: 'No preferences found',
          userId
        });
      }

      const prefs = mlResponse.data.preferences;

      // Format for frontend
      const formatted = {
        userId,
        summary: {
          totalInteractions: prefs.total_interactions,
          avgPrice: prefs.price_range.avg,
          priceRange: `${Math.round(prefs.price_range.min / 1000000)}M - ${Math.round(prefs.price_range.max / 1000000)}M`,
          favoritePropertyType: Object.entries(prefs.property_type_distribution)
            .sort((a, b) => b[1] - a[1])[0]?.[0],
          topLocations: Object.entries(prefs.top_locations)
            .slice(0, 3)
            .map(([location, count]) => ({ location, count }))
        },
        detailed: prefs
      };

      console.log(`✅ Preferences loaded:`, formatted.summary);

      res.json({
        success: true,
        preferences: formatted
      });

    } catch (mlError) {
      console.error('⚠️ ML error:', mlError.message);
      res.status(503).json({
        success: false,
        message: 'Failed to fetch preferences',
        error: mlError.message
      });
    }

  } catch (err) {
    console.error('❌ Error:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get user preferences',
      error: err.message
    });
  }
});

router.get('/recommendations/paginated', async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const skip = (page - 1) * limit;
  
  const recommendations = aiRecommendations.slice(skip, skip + limit);
  
  res.json({
    data: recommendations,
    pagination: {
      page,
      limit,
      total: aiRecommendations.length,
      pages: Math.ceil(aiRecommendations.length / limit)
    }
  });
});
// ==================== HELPER FUNCTIONS ====================




module.exports = router;