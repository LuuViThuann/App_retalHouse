require('dotenv').config();
const express = require('express');
const router = express.Router();
const Rental = require('../models/Rental');

// ==================== MIDDLEWARE ====================
const verifyAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'Không có token' });

    const admin = require('firebase-admin');
    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;

    const User = require('../models/usermodel');
    const mongoUser = await User.findOne({ _id: uid });
    if (!mongoUser || mongoUser.role !== 'admin') {
      return res.status(403).json({ message: 'Chỉ admin mới có quyền truy cập' });
    }

    req.userId = uid;
    req.isAdmin = true;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// ==================== HELPER FUNCTIONS ====================

/**
 * Caching decorator cho các route analytics
 * Cache kết quả trong 5 phút để tối ưu performance
 */
const analyticsCache = {};
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

const getOrSetCache = async (key, fetchFn) => {
  const now = Date.now();
  const cached = analyticsCache[key];

  if (cached && now - cached.timestamp < CACHE_DURATION) {
    console.log(`✅ Cache hit: ${key}`);
    return cached.data;
  }

  console.log(`🔄 Fetching fresh data: ${key}`);
  const data = await fetchFn();
  analyticsCache[key] = { data, timestamp: now };
  return data;
};

// ==================== ANALYTICS ROUTES ====================

/**
 * 1. 📊 Tổng quan thống kê
 * GET /api/analytics/overview
 */
router.get('/overview', async (req, res) => {
  try {
    const data = await getOrSetCache('overview', async () => {
      const rentalCount = await Rental.countDocuments({ status: 'available' });

      // Giá stats
      const priceStats = await Rental.aggregate([
        { $match: { status: 'available', price: { $gt: 0 } } },
        {
          $group: {
            _id: null,
            avgPrice: { $avg: '$price' },
            maxPrice: { $max: '$price' },
            minPrice: { $min: '$price' },
            totalCount: { $sum: 1 },
          },
        },
      ]);

      // Area stats
      const areaStats = await Rental.aggregate([
        { $match: { status: 'available', 'area.total': { $exists: true, $gt: 0 } } },
        {
          $group: {
            _id: null,
            avgArea: { $avg: '$area.total' },
            maxArea: { $max: '$area.total' },
            minArea: { $min: '$area.total' },
          },
        },
      ]);

      return {
        totalRentals: rentalCount,
        priceStats: priceStats.length > 0
          ? priceStats[0]
          : { avgPrice: 0, maxPrice: 0, minPrice: 0, totalCount: 0 },
        areaStats: areaStats.length > 0
          ? areaStats[0]
          : { avgArea: 0, maxArea: 0, minArea: 0 },
      };
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error in analytics overview:', err);
    res.status(500).json({ 
      message: 'Failed to fetch analytics overview', 
      error: err.message 
    });
  }
});

/**
 * 2. 💰 Phân bố giá
 * GET /api/analytics/price-distribution
 */
router.get('/price-distribution', async (req, res) => {
  try {
    const data = await getOrSetCache('price-distribution', async () => {
      const priceRanges = [
        { min: 0, max: 1000000, label: '< 1 triệu', color: '#4CAF50' },
        { min: 1000000, max: 3000000, label: '1-3 triệu', color: '#8BC34A' },
        { min: 3000000, max: 5000000, label: '3-5 triệu', color: '#FFC107' },
        { min: 5000000, max: 10000000, label: '5-10 triệu', color: '#FF9800' },
        { min: 10000000, max: 20000000, label: '10-20 triệu', color: '#FF5722' },
        { min: 20000000, max: Infinity, label: '> 20 triệu', color: '#F44336' },
      ];

      const distribution = await Promise.all(
        priceRanges.map(async (range) => {
          const count = await Rental.countDocuments({
            status: 'available',
            price: {
              $gte: range.min,
              ...(range.max === Infinity ? {} : { $lt: range.max }),
            },
          });
          return { ...range, count };
        })
      );

      const total = distribution.reduce((sum, item) => sum + item.count, 0);
      return distribution.map((item) => ({
        ...item,
        percentage: total > 0 ? Number(((item.count / total) * 100).toFixed(1)) : 0,
      }));
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error fetching price distribution:', err);
    res.status(500).json({ 
      message: 'Failed to fetch price distribution', 
      error: err.message 
    });
  }
});

/**
 * 3. 📈 Số bài đăng theo thời gian
 * GET /api/analytics/posts-timeline?period=day|week|month
 */
router.get('/posts-timeline', async (req, res) => {
  try {
    const { period = 'day' } = req.query;
    
    const data = await getOrSetCache(`posts-timeline:${period}`, async () => {
      let dateFormat = '%Y-%m-%d';
      let daysBack = 30;

      if (period === 'week') {
        dateFormat = '%G-W%V'; // ISO week
        daysBack = 84;
      } else if (period === 'month') {
        dateFormat = '%Y-%m';
        daysBack = 365;
      }

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - daysBack);

      const timeline = await Rental.aggregate([
        { $match: { createdAt: { $gte: startDate } } },
        {
          $group: {
            _id: { $dateToString: { format: dateFormat, date: '$createdAt' } },
            count: { $sum: 1 },
            avgPrice: { $avg: '$price' },
          },
        },
        { $sort: { _id: 1 } },
      ]);

      return timeline;
    });

    res.json({ period, data });
  } catch (err) {
    console.error('❌ Error fetching posts timeline:', err);
    res.status(500).json({ 
      message: 'Failed to fetch timeline', 
      error: err.message 
    });
  }
});

/**
 * 4. 📍 Thống kê theo khu vực
 * GET /api/analytics/location-stats
 */
router.get('/location-stats', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    
    // Create cache key based on filters
    const cacheKey = `location-stats:${province || 'all'}:${district || 'all'}:${ward || 'all'}`;
    
    const data = await getOrSetCache(cacheKey, async () => {
      const matchFilter = { status: 'available' };
      
      let result = {
        locations: [],
        totalPosts: 0,
        filterLevel: 'none',
      };

      if (ward && district && province) {
        // 📍 Ward level filter → Show only this ward
        result.filterLevel = 'ward';
        
        const wardCount = await Rental.countDocuments({
          ...matchFilter,
          'location.province': province,
          'location.district': district,
          'location.ward': ward,
        });

        result.locations = [
          {
            type: 'ward',
            name: ward,
            count: wardCount,
          },
        ];
        result.totalPosts = wardCount;

      } else if (district && province) {
        // 📍 District level filter → Show top wards in this district
        result.filterLevel = 'district';
        
        const topWards = await Rental.aggregate([
          {
            $match: {
              ...matchFilter,
              'location.province': province,
              'location.district': district,
            },
          },
          {
            $group: {
              _id: '$location.ward',
              count: { $sum: 1 },
            },
          },
          { $match: { _id: { $ne: null, $ne: '' } } },
          { $sort: { count: -1 } },
          { $limit: 10 },
          {
            $project: {
              type: { $literal: 'ward' },
              name: '$_id',
              count: 1,
              _id: 0,
            },
          },
        ]);

        result.locations = topWards;
        result.totalPosts = topWards.reduce((sum, w) => sum + w.count, 0);

      } else if (province) {
        // 📍 Province level filter → Show top districts in this province
        result.filterLevel = 'province';
        
        const topDistricts = await Rental.aggregate([
          {
            $match: {
              ...matchFilter,
              'location.province': province,
            },
          },
          {
            $group: {
              _id: '$location.district',
              count: { $sum: 1 },
            },
          },
          { $match: { _id: { $ne: null, $ne: '' } } },
          { $sort: { count: -1 } },
          { $limit: 10 },
          {
            $project: {
              type: { $literal: 'district' },
              name: '$_id',
              count: 1,
              _id: 0,
            },
          },
        ]);

        result.locations = topDistricts;
        result.totalPosts = topDistricts.reduce((sum, d) => sum + d.count, 0);

      } else {
        // 📍 No filter → Show top 10 provinces
        result.filterLevel = 'none';
        
        const topProvinces = await Rental.aggregate([
          { $match: matchFilter },
          {
            $group: {
              _id: '$location.province',
              count: { $sum: 1 },
            },
          },
          { $match: { _id: { $ne: null, $ne: '', $ne: 'Việt Nam' } } },
          { $sort: { count: -1 } },
          { $limit: 10 },
          {
            $project: {
              type: { $literal: 'province' },
              name: '$_id',
              count: 1,
              _id: 0,
            },
          },
        ]);

        result.locations = topProvinces;
        result.totalPosts = topProvinces.reduce((sum, p) => sum + p.count, 0);
      }

      console.log('📊 Location stats result:', {
        filterLevel: result.filterLevel,
        locationsCount: result.locations.length,
        totalPosts: result.totalPosts,
        filters: { province, district, ward },
        sampleData: result.locations.slice(0, 2),
      });

      return result;
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error fetching location stats:', err);
    res.status(500).json({ 
      message: 'Failed to fetch location stats', 
      error: err.message 
    });
  }
});
/**
 * 5. 🔥 Khu vực có nhiều bài đăng nhất
 * GET /api/analytics/hottest-areas?days=7
 */
router.get('/hottest-areas', async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days) || 7, 90); // Max 90 days
    
    const data = await getOrSetCache(`hottest-areas:${days}`, async () => {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const hotAreas = await Rental.aggregate([
        { $match: { status: 'available', createdAt: { $gte: startDate } } },
        {
          $group: {
            _id: '$location.short',
            count: { $sum: 1 },
            avgPrice: { $avg: '$price' },
            cities: { $addToSet: '$location.fullAddress' },
          },
        },
        { $sort: { count: -1 } },
        { $limit: 10 },
        {
          $addFields: {
            trend: {
              $cond: [{ $gte: ['$count', 20] }, '🔥 HOT', '📍 NORMAL'],
            },
          },
        },
      ]);

      return hotAreas;
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error fetching hottest areas:', err);
    res.status(500).json({ 
      message: 'Failed to fetch hottest areas', 
      error: err.message 
    });
  }
});

/**
 * 6. 🌟 Khu vực đang trending
 * GET /api/analytics/trending-areas?days=7
 */
router.get('/trending-areas', async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days) || 7, 90);
    
    const data = await getOrSetCache(`trending-areas:${days}`, async () => {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const trendingAreas = await Rental.aggregate([
        { $match: { status: 'available', createdAt: { $gte: startDate } } },
        {
          $group: {
            _id: '$location.short',
            postCount: { $sum: 1 },
            totalViews: { $sum: { $ifNull: ['$views', 0] } },
            avgPrice: { $avg: '$price' },
          },
        },
        {
          $addFields: {
            engagementScore: {
              $multiply: [
                '$postCount',
                { $divide: ['$totalViews', { $max: [1, '$postCount'] }] },
              ],
            },
            trend: {
              $cond: [{ $gte: ['$totalViews', 500] }, 'hot', 'normal'],
            },
          },
        },
        { $sort: { engagementScore: -1 } },
        { $limit: 10 },
      ]);

      return trendingAreas;
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error fetching trending areas:', err);
    res.status(500).json({ 
      message: 'Failed to fetch trending areas', 
      error: err.message 
    });
  }
});

/**
 * 7. 🏠 Thống kê theo loại bất động sản
 * GET /api/analytics/property-types
 */
router.get('/property-types', async (req, res) => {
  try {
    const data = await getOrSetCache('property-types', async () => {
      const stats = await Rental.aggregate([
        { $match: { status: 'available' } },
        {
          $group: {
            _id: '$propertyType',
            count: { $sum: 1 },
            avgPrice: { $avg: '$price' },
            avgArea: { $avg: '$area.total' },
            minPrice: { $min: '$price' },
            maxPrice: { $max: '$price' },
          },
        },
        { $sort: { count: -1 } },
        {
          $addFields: {
            percentage: 0, // Will be calculated on frontend
          },
        },
      ]);

      const total = stats.reduce((sum, item) => sum + item.count, 0);
      return stats.map((item) => ({
        ...item,
        percentage: total > 0 ? Number(((item.count / total) * 100).toFixed(1)) : 0,
      }));
    });

    res.json(data);
  } catch (err) {
    console.error('❌ Error fetching property types:', err);
    res.status(500).json({ 
      message: 'Failed to fetch property types', 
      error: err.message 
    });
  }
});

/**
 * 🔄 BONUS: Clear cache endpoint (for admin)
 * POST /api/analytics/clear-cache (protected)
 */
router.post('/clear-cache', verifyAdmin, (req, res) => {
  try {
    for (const key in analyticsCache) {
      delete analyticsCache[key];
    }
    console.log('✅ Analytics cache cleared');
    res.json({ message: 'Cache cleared successfully', clearedAt: new Date() });
  } catch (err) {
    res.status(500).json({ message: 'Failed to clear cache', error: err.message });
  }
});

// ==================== EXPORT ====================
module.exports = router;