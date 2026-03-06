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
      limit,
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

    const totalRentals = await Rental.countDocuments({ status: 'available' });
    const n_recommendations = totalRentals;
    const n_recommendations_fetch = totalRentals;

    console.log(`   Requesting ${n_recommendations} recommendations (capped at 50)`);

    let aiRecommendations = [];
    let isAIRecommendation = false;

    // 🔥 STEP 1: Get user's own rental IDs to exclude
    let userOwnRentalIds = [];
    try {
      const userRentals = await Rental.find({
        userId: userId,
        status: { $in: ['available', 'rented'] }  // All active rentals
      })
        .select('_id')
        .lean();

      userOwnRentalIds = userRentals.map(r => r._id.toString());

      if (userOwnRentalIds.length > 0) {
        console.log(`   🚫 Found ${userOwnRentalIds.length} own rentals to exclude`);
      }
    } catch (err) {
      console.error('⚠️ Error fetching user rentals:', err.message);
      // Continue anyway, just won't exclude
    }

    // 🔥 STEP 2: Call Python ML Service
    try {
      console.log(`🔗 Calling ML service: ${ML_SERVICE_URL}/recommend/personalized`);

      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/personalized`,
        {
          userId: userId,
          user_id: userId,
          n_recommendations: totalRentals,
          use_location: true,
          radius_km: parseInt(radius) || 20,
          exclude_items: userOwnRentalIds,  // 🔥 PASS OWN RENTAL IDS
          context: {
            map_center: latitude && longitude
              ? [parseFloat(longitude), parseFloat(latitude)]
              : null,
            zoom_level: 15,
            search_radius: parseInt(radius) || 10,
            time_of_day: _getTimeOfDay(),
            device_type: 'mobile',
            impressions: [],
            scroll_depth: 0.5
          }
        },
        {
          timeout: 10000,
          headers: { 'Content-Type': 'application/json' }
        }
      );

      if (mlResponse.data && mlResponse.data.recommendations) {
        aiRecommendations = mlResponse.data.recommendations;
        isAIRecommendation = true;
        console.log(`✅ AI returned ${aiRecommendations.length} recommendations`);

        if (aiRecommendations.length > 0) {
          const first = aiRecommendations[0];
          console.log(`   Top recommendation:`);
          console.log(`     - rentalId: ${first.rentalId}`);
          console.log(`     - finalScore: ${first.finalScore.toFixed(2)}`);
          console.log(`     - distance: ${first.distance_km}km`);
        }
      }
    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      if (mlError.response?.status === 422) {
        console.error('   🔴 Request validation error (422)');
        console.error('   Request body:', mlError.config?.data);
        console.error('   Response:', mlError.response?.data);
      }
      console.log('⚠️ Falling back to popularity-based recommendations');
      isAIRecommendation = false;
    }

    // 🔥 STEP 3: Build MongoDB query
    let rentalIds = [];

    if (isAIRecommendation && aiRecommendations.length > 0) {
      rentalIds = aiRecommendations.map(r => r.rentalId);
      console.log(`📌 Using AI recommendations: ${rentalIds.length} items`);
    } else {
      // Fallback: Popularity-based (exclude own rentals)
      const popularRentals = await Rental.find({
        status: 'available',
        userId: { $ne: userId }  // 🔥 EXCLUDE OWN RENTALS
      })
        .sort({ views: -1, createdAt: -1 })
        .select('_id')
        .lean();

      rentalIds = popularRentals.map(r => r._id.toString());
      console.log(`📊 Using popularity fallback: ${rentalIds.length} items`);
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

    // Location filter
    let geoFilter = {};
    if (latitude && longitude) {
      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);
      // Tăng radius * 3 để lấy nhiều bài hơn, sort theo score sau
      const searchRadius = parseFloat(radius) * 3;
      const radiusInMeters = searchRadius * 1000;
    
      if (!isNaN(lat) && !isNaN(lon) && lat !== 0 && lon !== 0) {
        geoFilter = {
          'location.coordinates': {
            $geoWithin: {
              $centerSphere: [[lon, lat], radiusInMeters / 6378100]
            }
          }
        };
        console.log(`📍 Geo filter: ${searchRadius}km (3x expanded from ${radius}km)`);
      }
    }

    // Price filter
    let priceFilter = {};
    if (minPrice || maxPrice) {
      priceFilter.price = {};
      if (minPrice) priceFilter.price.$gte = Number(minPrice);
      if (maxPrice) priceFilter.price.$lte = Number(maxPrice);
      console.log(`💰 Price filter:`, priceFilter.price);
    }

    //--------------- < 
    // 🔥 STEP 4: Query MongoDB with DOUBLE-CHECK exclusion
    const query = {
      _id: { $in: rentalIds },
      status: 'available',
      userId: { $ne: userId },  // 🔥 DOUBLE-CHECK: Exclude own rentals
      ...geoFilter,
      ...priceFilter
    };

    const rentals = await Rental.find(query).lean();

    console.log(`✅ Found ${rentals.length} rentals matching criteria`);

    // 🔥 STEP 5: Merge AI metadata
    const rentalsWithScore = rentals.map(rental => {
      const aiRec = aiRecommendations.find(
        r => r.rentalId === rental._id.toString()
      );

      const coords = aiRec?.coordinates || {
        longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
        latitude: rental.location?.coordinates?.coordinates?.[1] || 0
      };

      return {
        ...rental,
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
        locationBonus: aiRec?.locationBonus || 1.0,
        finalScore: aiRec?.finalScore || aiRec?.score || 0,
        confidence: aiRec?.confidence || 0.5,
        isAIRecommended: isAIRecommendation,
        recommendationReason: aiRec?.method || 'Popular'
      };
    });

    rentalsWithScore.sort((a, b) => (b.finalScore || 0) - (a.finalScore || 0));

    console.log(`✅ Response ready: ${rentalsWithScore.length} rentals`);
    console.log(`   🚫 Excluded ${userOwnRentalIds.length} own rentals`);

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

// Helper function
function _getTimeOfDay() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/**
 * GET /api/ai/recommendations/nearby
 * Lấy AI recommendations kết hợp với nearby search - 🔥 INCLUDES COORDINATES
 */
router.get('/recommendations/nearby/:rentalId', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.params;
    const { limit, radius = 10 } = req.query;
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
    const totalAvailable = await Rental.countDocuments({ status: 'available' });

    try {
      console.log(`🔗 Calling ML service: ${ML_SERVICE_URL}/recommend/similar`);

      // 🔥 FIX: Gửi rentalId và enable location
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/similar`,
        {
          rentalId: rentalId,  // 🔥 SỬA: rental_id -> rentalId
          n_recommendations: totalAvailable,
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
      { $limit: totalAvailable }
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

    const effectiveLimit = limit ? parseInt(limit) : rentalsWithAI.length;
    const finalRentals = rentalsWithAI.slice(0, effectiveLimit);

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
      limit,
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
      const totalAvailable = await Rental.countDocuments({ status: 'available' });
      // 🔥 CALL ML SERVICE WITH CONTEXT
      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/personalized`,
        {
          userId,
          n_recommendations: totalAvailable,
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
      }).lean();

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
        .limit(totalAvailable)
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

router.post('/recommendations/personalized/with-poi', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const {
      latitude,
      longitude,
      selectedCategories = [],
      radius = 10,
      poiRadius = 3,
      limit,
      minPrice,
      maxPrice
    } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu latitude và longitude'
      });
    }

    if (!selectedCategories || selectedCategories.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn ít nhất một POI category'
      });
    }

    console.log(`🤖🏢 [AI-POI-PERSONALIZED] User: ${userId}`);
    console.log(`   Location: (${latitude}, ${longitude}), radius: ${radius}km`);
    console.log(`   POI Categories: ${selectedCategories.join(', ')}`);
    console.log(`   POI Radius: ${poiRadius}km`);

    // =====================================================
    // STEP 1: Lấy AI personalized recommendations
    // =====================================================
    let aiRecommendations = [];
    let isAIRecommendation = false;
    const totalAvailable = await Rental.countDocuments({ status: 'available' });

    try {
      console.log(`🔗 [AI-POI] Calling ML service for personalized recommendations...`);

      

      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/personalized`,
        {
          userId: userId,
          n_recommendations: totalAvailable,
          use_location: true,
          radius_km: parseInt(radius),
          exclude_items: [],
          context: {
            map_center: [parseFloat(longitude), parseFloat(latitude)],
            zoom_level: 15,
            search_radius: parseInt(radius),
            time_of_day: _getTimeOfDay(),
            device_type: 'mobile',
            impressions: [],
            scroll_depth: 0.5
          }
        },
        { timeout: 10000, headers: { 'Content-Type': 'application/json' } }
      );

      if (mlResponse.data?.recommendations) {
        aiRecommendations = mlResponse.data.recommendations;
        isAIRecommendation = true;
        console.log(`✅ AI returned ${aiRecommendations.length} personalized recommendations`);
      }
    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      isAIRecommendation = false;
    }

    // =====================================================
    // STEP 2: Lấy POI cho các categories đã chọn
    // =====================================================
    console.log(`📍 [AI-POI] Fetching POIs for selected categories...`);

    const poiService = new (require('../service/poi-service')).POIService();
    const poiData = {};
    const allPOIs = [];

    // Parallel fetch POIs
    const poiPromises = selectedCategories.map(async (category) => {
      try {
        const pois = await poiService.getPOIsByCategory(
          latitude,
          longitude,
          category,
          poiRadius + 1
        );
        poiData[category] = pois;
        allPOIs.push(...pois);
        console.log(`   ✅ ${category}: ${pois.length} POIs`);
        return pois;
      } catch (error) {
        console.error(`   ⚠️ ${category}: ${error.message}`);
        poiData[category] = [];
        return [];
      }
    });

    await Promise.all(poiPromises);
    console.log(`✅ Total POIs found: ${allPOIs.length}`);

    if (allPOIs.length === 0) {
      return res.json({
        success: true,
        rentals: [],
        total: 0,
        message: 'Không tìm thấy tiện ích nào trong khu vực'
      });
    }

    // =====================================================
    // STEP 3: 🔥 CALCULATE POI PROXIMITY SCORES
    // =====================================================
    // Cho mỗi POI, tính score dựa trên gần nhất/đặc biệt
    console.log(`🎯 [AI-POI] Calculating POI proximity scores...`);

    const poiProximityScores = {};

    // Gọi rental để tính distance đến mỗi POI
    const rentalIds = aiRecommendations.map(r => r.rentalId);
    const rentals = await Rental.find({
      _id: { $in: rentalIds },
      status: 'available'
    }).lean();

    for (const rental of rentals) {
      const rentalId = rental._id.toString();
      const rentalLat = rental.location?.coordinates?.coordinates?.[1] || 0;
      const rentalLon = rental.location?.coordinates?.coordinates?.[0] || 0;

      if (rentalLat === 0 || rentalLon === 0) continue;

      // 🔥 Tính distance đến từng POI
      const poiDistances = [];

      for (const poi of allPOIs) {
        const distance = _haversineDistance(rentalLon, rentalLat, poi.longitude, poi.latitude);

        // Chỉ count nếu trong poiRadius
        if (distance <= poiRadius) {
          poiDistances.push({
            category: poi.category,
            name: poi.name,
            distance: distance
          });
        }
      }

      // 🔥 Tính POI proximity score
      if (poiDistances.length > 0) {
        // Score = số POI gần + weighted by distance
        const poiProximityScore = poiDistances.length * 10 + // Base: số POI
          (1 - (poiDistances[0].distance / poiRadius)) * 5; // Bonus: gần nhất

        poiProximityScores[rentalId] = {
          proximityScore: poiProximityScore,
          nearestPOIs: poiDistances.slice(0, 3),
          poiCount: poiDistances.length,
          nearestDistance: poiDistances[0].distance
        };
      }
    }

    console.log(`✅ Calculated POI proximity for ${Object.keys(poiProximityScores).length} rentals`);

    // =====================================================
    // STEP 4: 🔥 COMBINE AI + POI SCORES
    // =====================================================
    console.log(`🔀 [AI-POI] Combining AI + POI scores...`);

    const combinedScores = aiRecommendations.map(aiRec => {
      const rentalId = aiRec.rentalId;
      const poiScore = poiProximityScores[rentalId] || {
        proximityScore: 0,
        nearestPOIs: [],
        poiCount: 0
      };

      // 🔥 COMBINED SCORE = AI score (70%) + POI proximity (30%)
      const combinedScore = (aiRec.finalScore * 0.7) + (poiScore.proximityScore * 0.3);

      return {
        ...aiRec,
        poiScore: poiScore.proximityScore,
        poiCount: poiScore.poiCount,
        nearestPOIs: poiScore.nearestPOIs,
        nearestDistance: poiScore.nearestDistance,
        combinedScore: combinedScore, // 🔥 NEW: Combined score
        method: 'ai_personalized_with_poi'
      };
    });

    // =====================================================
    // STEP 5: Sort by combined score (không phải AI score)
    // =====================================================
    combinedScores.sort((a, b) => (b.combinedScore || 0) - (a.combinedScore || 0));

    // =====================================================
    // STEP 6: Fetch rental details từ MongoDB
    // =====================================================
    const effectiveLimit = limit ? parseInt(limit) : combinedScores.length;
    const topRentalIds = combinedScores.slice(0, effectiveLimit).map(r => r.rentalId);
    const topRentals = await Rental.find({
      _id: { $in: topRentalIds },
      status: 'available'
    }).lean();

    // =====================================================
    // STEP 7: Merge scores vào rental details
    // =====================================================
    const finalRentals = topRentalIds.map(rentalId => {
      const rental = topRentals.find(r => r._id.toString() === rentalId);
      const score = combinedScores.find(s => s.rentalId === rentalId);

      if (!rental || !score) return null;

      return {
        ...rental,
        aiScore: score.score || 0,
        poiScore: score.poiScore || 0,
        combinedScore: score.combinedScore || 0,
        finalScore: score.combinedScore, // 🔥 Use combined score
        confidence: score.confidence || 0.5,
        poiCount: score.poiCount || 0,
        nearestPOIs: score.nearestPOIs || [],
        nearestDistance: score.nearestDistance || null,
        // For visualization
        markerSize: Math.max(1, Math.min(5, (score.combinedScore || 0) / 20)),
        markerOpacity: (score.confidence || 0.5) * 0.9 + 0.1,
        isAIRecommended: isAIRecommendation,
        recommendationMethod: 'ai_poi_personalized'
      };
    }).filter(Boolean);

    console.log(`✅ Final rentals: ${finalRentals.length}`);
    console.log(`   Sample: ${finalRentals.length > 0 ? `Score: ${finalRentals[0].combinedScore?.toFixed(2)}, POI Count: ${finalRentals[0].poiCount}` : 'N/A'}`);

    // =====================================================
    // STEP 8: Return response
    // =====================================================
    res.json({
      success: true,
      rentals: finalRentals,
      total: finalRentals.length,
      isAIRecommendation,
      method: 'ai_personalized_with_poi_filter',
      selectedCategories,
      poiStats: {
        totalPOIsFound: allPOIs.length,
        poiRadius: poiRadius,
        categories: selectedCategories.length
      },
      filters: {
        location: { latitude, longitude, radius },
        price: { minPrice, maxPrice }
      },
      message: `🤖🏢 Gợi ý cá nhân hóa kết hợp tiện ích: ${finalRentals.length} bài gần ${allPOIs.length} địa điểm`
    });

  } catch (err) {
    console.error('❌ Error in AI+POI recommendations:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get personalized recommendations with POI',
      error: err.message
    });
  }
});

function _haversineDistance(lon1, lat1, lon2, lat2) {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}



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

/**
 * 🤖 POST /api/ai/recommendations/similar
 * Similar rentals filtered by propertyType
 * Flutter gọi endpoint này, Node.js proxy sang Python ML
 */
router.post('/recommendations/similar', authMiddleware, async (req, res) => {
  try {
    const { rentalId, propertyType, limit } = req.body;
    const userId = req.userId;

    if (!rentalId) {
      return res.status(400).json({
        success: false,
        message: 'rentalId is required'
      });
    }

    console.log(`🤖 [SIMILAR] User: ${userId}, Rental: ${rentalId}`);
    console.log(`   PropertyType filter: ${propertyType || 'none'}`);
    console.log(`   Limit: ${limit}`);

    // 🔥 STEP 1: Gọi Python ML với property_type filter
    let recommendations = [];
    let isAIRecommendation = false;

    const totalAvailable = await Rental.countDocuments({ status: 'available' });
    try {
      console.log(`🔗 Calling ML: ${ML_SERVICE_URL}/recommend/similar`);

      const mlResponse = await axios.post(
        `${ML_SERVICE_URL}/recommend/similar`,
        {
          rentalId: rentalId,
          n_recommendations: totalAvailable,
          use_location: true,
          property_type: propertyType || null,  // 🔥 pass propertyType
        },
        {
          timeout: 10000,
          headers: { 'Content-Type': 'application/json' }
        }
      );

      if (mlResponse.data?.recommendations) {
        recommendations = mlResponse.data.recommendations;
        isAIRecommendation = true;
        console.log(`✅ ML returned ${recommendations.length} similar items`);
      }
    } catch (mlError) {
      console.error('⚠️ ML Service error:', mlError.message);
      // Fallback: MongoDB query cùng loại
    }

    // 🔥 STEP 2: Nếu ML thất bại → fallback MongoDB
    if (!isAIRecommendation || recommendations.length === 0) {
      console.log('⚠️ ML failed or empty, using MongoDB fallback');

      const mongoQuery = {
        _id: { $ne: rentalId },
        status: 'available',
      };
      if (propertyType) {
        mongoQuery.propertyType = propertyType;
      }

      const fallbackRentals = await Rental.find(mongoQuery)
        .sort({ createdAt: -1 })
        .limit(totalAvailable) 
        .select('_id propertyType location price title images')
        .lean();

      // Format để giống ML response
      recommendations = fallbackRentals.map(r => ({
        rentalId: r._id.toString(),
        score: 0.5,
        confidence: 0.3,
        finalScore: 0.5,
        coordinates: {
          longitude: r.location?.coordinates?.coordinates?.[0] || 0,
          latitude: r.location?.coordinates?.coordinates?.[1] || 0,
        },
        propertyType: r.propertyType,
        method: 'fallback',
      }));

      console.log(`✅ MongoDB fallback: ${recommendations.length} items`);
    }

    // 🔥 STEP 3: Enrich với data từ MongoDB
    const rentalIds = recommendations.map(r => r.rentalId);
    const rentals = await Rental.find({
      _id: { $in: rentalIds },
      status: 'available',
    }).lean();

    // Build map để lookup nhanh
    const rentalMap = {};
    rentals.forEach(r => {
      rentalMap[r._id.toString()] = r;
    });

    // Merge ML metadata + rental details
    const enrichedResults = recommendations
      .map(rec => {
        const rental = rentalMap[rec.rentalId];
        if (!rental) return null;

        const coords = rec.coordinates || {
          longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
          latitude: rental.location?.coordinates?.coordinates?.[1] || 0,
        };

        return {
          ...rec,
          // Rental details
          title: rental.title,
          price: rental.price,
          propertyType: rental.propertyType,
          images: rental.images || [],
          location: {
            ...rental.location,
            longitude: coords.longitude,
            latitude: coords.latitude,
          },
          area: rental.area,
        };
      })
      .filter(Boolean);

    console.log(`✅ [SIMILAR] Response: ${enrichedResults.length} similar rentals`);

    res.json({
      success: true,
      recommendations: enrichedResults,
      total: enrichedResults.length,
      isAIRecommendation,
      filter: { propertyType: propertyType || null },
    });

  } catch (err) {
    console.error('❌ Error in similar recommendations:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get similar recommendations',
      error: err.message
    });
  }
});


module.exports = router;