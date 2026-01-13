// routes/poi-routes.js - CẬP NHẬT
const express = require('express');
const router = express.Router();
const { POIService, POI_CATEGORIES } = require('../service/poi-service');
const Rental = require('../models/Rental');
const admin = require('firebase-admin');

const poiService = new POIService();

// ==================== MIDDLEWARE ====================
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ 
      success: false,
      message: 'No token provided' 
    });
  }
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ 
      success: false,
      message: 'Invalid token', 
      error: err.message 
    });
  }
};

/**
 * GET /api/poi/categories - Lấy danh sách POI categories
 */
router.get('/categories', async (req, res) => {
    try {
      const categories = Object.entries(POI_CATEGORIES).map(([id, config]) => ({
        id,
        name: config.name,
        icon: config.icon,
        tags: config.tags,
      }));
  
      console.log(`✅ [POI-CATEGORIES] Returning ${categories.length} categories`);
  
      res.json({
        success: true,
        categories,
        total: categories.length,
      });
    } catch (error) {
      console.error('❌ [POI-CATEGORIES] Error:', error.message);
      res.status(500).json({
        success: false,
        message: 'Lỗi khi lấy danh sách categories',
        error: error.message,
      });
    }
  });
/**
 * 🔥 CẬP NHẬT: POST /api/poi/filter-rentals-by-poi
 * Lọc rentals dựa trên tiện ích và khoảng cách
 */
router.post('/filter-rentals-by-poi', authMiddleware, async (req, res) => {
    try {
      const {
        latitude,
        longitude,
        selectedCategories = [],
        radius = 3,
        limit = 20,
        minPrice,
        maxPrice
      } = req.body;
  
      // Validate
      if (!latitude || !longitude) {
        return res.status(400).json({
          success: false,
          message: 'Thiếu tham số latitude và longitude',
        });
      }
  
      if (!selectedCategories || selectedCategories.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Vui lòng chọn ít nhất một loại tiện ích',
        });
      }
  
      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);
      const radiusKm = parseFloat(radius);

     
  
      if (isNaN(lat) || isNaN(lon) || isNaN(radiusKm)) {
        return res.status(400).json({
          success: false,
          message: 'Tham số không hợp lệ',
        });
      }
  
      console.log(`🔥 [POI-FILTER] Request:`, {
        latitude: lat,
        longitude: lon,
        selectedCategories,
        radius: radiusKm,
        minPrice,
        maxPrice
      });
  
      // Step 1: Fetch POIs for selected categories
      console.log(`📍 [POI-FILTER] Fetching POIs for categories: ${selectedCategories.join(', ')}`);
      
      const poiData = {};
      const allPOIs = [];
  
      
      for (const category of selectedCategories) {
        const pois = await poiService.getPOIsByCategory(lat, lon, category, radiusKm + 2);
        poiData[category] = pois;
        allPOIs.push(...pois);
        console.log(`   ✅ ${category}: ${pois.length} POIs`);
      }
  
      console.log(`✅ [POI-FILTER] Total POIs found: ${allPOIs.length}`);
  
     
      
      if (allPOIs.length === 0) {
        return res.json({
          success: true,
          rentals: [],
          pois: [],
          total: 0,
          message: 'Không tìm thấy tiện ích nào trong khu vực này',
          selectedCategories,
          radius: radiusKm,
        });
      }
  
      // Step 2: Get all rentals from database
      const query = {
        status: 'available',
      };
  
      // Price filter
      if (minPrice || maxPrice) {
        query.price = {};
        if (minPrice) query.price.$gte = Number(minPrice);
        if (maxPrice) query.price.$lte = Number(maxPrice);
      }
  
      const allRentals = await Rental.find(query)
        .select('title price location images videos propertyType createdAt area furniture amenities surroundings rentalTerms contactInfo status userId')
        .lean();
  
      console.log(`📍 [POI-FILTER] Total rentals in DB: ${allRentals.length}`);
  
      // Step 3: Filter rentals by POI distance
      console.log(`🔥 [POI-FILTER] Filtering rentals by distance from POIs...`);
      
      const filteredRentals = poiService.filterRentalsByMultiplePOIs(
        selectedCategories,
        poiData,
        allRentals,
        radiusKm
      );
  
      console.log(`✅ [POI-FILTER] Filtered result: ${filteredRentals.length} rentals within ${radiusKm}km`);
  
      // Step 4: Transform response
      const rentalsWithPOI = filteredRentals.slice(0, limit).map(rental => ({
        ...rental,
        nearestPOIs: rental.nearestPOIs || [],
        poisCount: rental.nearestPOIs?.length || 0,
      }));
  
      // Highlight POIs trên bản đồ
      const highlightPOIs = allPOIs.map(poi => ({
        id: poi.id,
        name: poi.name,
        category: poi.category,
        categoryName: poi.categoryName,
        categoryIcon: poi.categoryIcon,
        latitude: poi.latitude,
        longitude: poi.longitude,
        hasNearbyRentals: rentalsWithPOI.some(r => 
          r.nearestPOIs?.some(p => p.name === poi.name)
        )
      }));
  
      console.log(`✅ [POI-FILTER] Response ready: ${rentalsWithPOI.length} rentals, ${highlightPOIs.length} POIs`);
  
      res.json({
        success: true,
       rentals: rentalsWithPOI.map(rental => ({
            ...rental,
            nearestPOIs: rental.nearestPOIs || [] // Đảm bảo luôn có array
          })),
        pois: highlightPOIs,
        total: rentalsWithPOI.length,
        poisTotal: highlightPOIs.length,
        selectedCategories,
        radius: radiusKm,
        message: `🔥 Tìm thấy ${rentalsWithPOI.length} bài trong bán kính ${radiusKm}km từ ${highlightPOIs.length} tiện ích`,
      });
  
    } catch (error) {
      console.error('❌ [POI-FILTER] Error:', error.message);
      res.status(500).json({
        success: false,
        message: 'Lỗi khi lọc bất động sản',
        error: error.message,
      });
    }
  });
/**
 * GET /api/poi/nearby - Lấy POI gần vị trí
 * Query params: latitude, longitude, category, radius
 */
router.get('/nearby', async (req, res) => {
    try {
      const { latitude, longitude, category, radius = 20 } = req.query;
  
      if (!latitude || !longitude) {
        return res.status(400).json({
          success: false,
          message: 'Thiếu tham số latitude và longitude',
        });
      }
  
      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);
      const rad = parseFloat(radius);
  
      if (isNaN(lat) || isNaN(lon) || isNaN(rad)) {
        return res.status(400).json({
          success: false,
          message: 'Tham số không hợp lệ',
        });
      }
  
      if (Math.abs(lat) > 90 || Math.abs(lon) > 180) {
        return res.status(400).json({
          success: false,
          message: 'Tọa độ nằm ngoài phạm vi hợp lệ',
        });
      }
  
      console.log(`🔍 [POI-NEARBY] Request:`, {
        latitude: lat,
        longitude: lon,
        category: category || 'ALL',
        radius: rad
      });
  
      let pois = [];
  
      if (category && category !== 'ALL') {
        pois = await poiService.getPOIsByCategory(lat, lon, category, rad);
      } else {
        const allPOIs = await poiService.getAllPOIsNearby(lat, lon, rad);
        pois = Object.values(allPOIs).flat();
      }
  
      console.log(`✅ [POI-NEARBY] Found ${pois.length} POIs`);
  
      res.json({
        success: true,
        pois,
        total: pois.length,
        latitude: lat,
        longitude: lon,
        radius: rad,
        category: category || 'ALL',
      });
    } catch (error) {
      console.error('❌ [POI-NEARBY] Error:', error.message);
      res.status(500).json({
        success: false,
        message: 'Lỗi khi tìm POI gần đây',
        error: error.message,
      });
    }
  });
/**
 * POST /api/poi/rentals-near-poi - Lấy rentals gần POI
 */
router.post('/rentals-near-poi', authMiddleware, async (req, res) => {
  try {
    const { poi, radius = 20, limit = 20, minPrice, maxPrice } = req.body;

    if (!poi || !poi.latitude || !poi.longitude) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu thông tin POI',
      });
    }

    console.log(`🏠 [RENTALS-NEAR-POI] Request:`, {
      poi: poi.name,
      category: poi.categoryName,
      radius,
      limit,
      minPrice,
      maxPrice
    });

    // Build query filter
    const query = {
      status: 'available',
    };

    // Price filter
    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }

    const radiusInMeters = radius * 1000;

    // Geospatial query
    const rentals = await Rental.aggregate([
      {
        $geoNear: {
          near: { 
            type: 'Point', 
            coordinates: [poi.longitude, poi.latitude] 
          },
          distanceField: 'distance',
          maxDistance: radiusInMeters,
          spherical: true,
          query: query,
        },
      },
      { $limit: parseInt(limit) },
      {
        $project: {
          title: 1,
          price: 1,
          location: 1,
          images: 1,
          videos: 1,
          propertyType: 1,
          createdAt: 1,
          distance: 1,
          area: 1,
          furniture: 1,
          amenities: 1,
          surroundings: 1,
          rentalTerms: 1,
          contactInfo: 1,
          status: 1,
          userId: 1,
        },
      },
    ]);

    // Add POI info to each rental
    const rentalsWithPOI = rentals.map(rental => ({
      ...rental,
      distanceFromPOI: (rental.distance / 1000).toFixed(2),
      distanceFromPOIKm: `${(rental.distance / 1000).toFixed(2)} km`,
      nearbyPOI: {
        name: poi.name,
        category: poi.categoryName,
        icon: poi.categoryIcon,
        distance: `${(rental.distance / 1000).toFixed(2)} km`,
      },
    }));

    console.log(`✅ [RENTALS-NEAR-POI] Found ${rentalsWithPOI.length} rentals`);

    res.json({
      success: true,
      rentals: rentalsWithPOI,
      total: rentalsWithPOI.length,
      poi: {
        name: poi.name,
        category: poi.categoryName,
        icon: poi.categoryIcon,
      },
    });
  } catch (error) {
    console.error('❌ [RENTALS-NEAR-POI] Error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi khi tìm rentals gần POI',
      error: error.message,
    });
  }
});

/**
 * POST /api/poi/ai-recommendations - AI + POI combined
 */
router.post('/ai-recommendations', authMiddleware, async (req, res) => {
  try {
    const {
      latitude,
      longitude,
      selectedCategories = [],
      radius = 20,
      limit = 20,
      minPrice,
      maxPrice,
    } = req.body;

    // Validate
    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu tham số latitude và longitude',
      });
    }

    if (!selectedCategories || selectedCategories.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn ít nhất một category',
      });
    }

    console.log(`🤖🏢 [AI-POI] Request:`, {
      latitude,
      longitude,
      selectedCategories,
      radius,
      limit
    });

    // Step 1: Fetch POIs for selected categories
    const allPOIs = [];
    
    for (const category of selectedCategories) {
      const pois = await poiService.getPOIsByCategory(
        latitude, 
        longitude, 
        category, 
        radius
      );
      allPOIs.push(...pois);
    }

    console.log(`✅ Found ${allPOIs.length} POIs for ${selectedCategories.length} categories`);

    if (allPOIs.length === 0) {
      return res.json({
        success: true,
        rentals: [],
        total: 0,
        isAIRecommendation: false,
        message: 'Không tìm thấy tiện ích nào trong khu vực này',
        selectedCategories,
      });
    }

    // Step 2: Find rentals near these POIs
    const radiusInMeters = radius * 1000;
    
    // Build query
    const query = {
      status: 'available',
    };

    // Price filter
    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }

    // Get all rentals near user location first
    const nearbyRentals = await Rental.aggregate([
      {
        $geoNear: {
          near: { 
            type: 'Point', 
            coordinates: [longitude, latitude] 
          },
          distanceField: 'distance',
          maxDistance: radiusInMeters,
          spherical: true,
          query: query,
        },
      },
      { $limit: parseInt(limit) * 3 }, // Get more for filtering
    ]);

    console.log(`📍 Found ${nearbyRentals.length} rentals near user`);

    // Step 3: Score rentals based on proximity to POIs
    const rentalsWithScores = nearbyRentals.map(rental => {
      const rentalLat = rental.location?.coordinates?.coordinates?.[1] || 0;
      const rentalLon = rental.location?.coordinates?.coordinates?.[0] || 0;

      if (rentalLat === 0 || rentalLon === 0) {
        return null;
      }

      // Calculate distances to all POIs
      const poiDistances = allPOIs.map(poi => {
        const distance = poiService.calculateDistance(
          rentalLat,
          rentalLon,
          poi.latitude,
          poi.longitude
        );
        return { poi, distance };
      });

      // Sort by distance
      poiDistances.sort((a, b) => a.distance - b.distance);

      // Get 3 nearest POIs
      const nearestPOIs = poiDistances.slice(0, 3);

      // Calculate score (lower distance = higher score)
      const avgDistance = nearestPOIs.reduce((sum, p) => sum + p.distance, 0) / nearestPOIs.length;
      const score = Math.max(0, 100 - (avgDistance * 10)); // Score from 0-100

      return {
        ...rental,
        aiScore: score,
        nearestPOIs: nearestPOIs.map(p => ({
          name: p.poi.name,
          category: p.poi.categoryName,
          icon: p.poi.categoryIcon,
          distance: p.distance.toFixed(2),
        })),
        avgPOIDistance: avgDistance.toFixed(2),
        isAIRecommended: true,
      };
    }).filter(Boolean);

    // Sort by score
    rentalsWithScores.sort((a, b) => b.aiScore - a.aiScore);

    // Take top results
    const topRentals = rentalsWithScores.slice(0, parseInt(limit));

    console.log(`✅ [AI-POI] Returning ${topRentals.length} rentals with AI scores`);

    res.json({
      success: true,
      rentals: topRentals,
      total: topRentals.length,
      isAIRecommendation: true,
      message: `🤖 Tìm thấy ${topRentals.length} bài gần ${allPOIs.length} tiện ích`,
      selectedCategories,
      poisFound: allPOIs.length,
    });

  } catch (error) {
    console.error('❌ [AI-POI] Error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy AI+POI recommendations',
      error: error.message,
    });
  }
});

module.exports = router;