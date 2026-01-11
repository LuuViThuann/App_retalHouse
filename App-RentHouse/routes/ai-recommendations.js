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

module.exports = router;