require('dotenv').config();
const express = require('express');
const router  = express.Router();
const Rental  = require('../models/Rental');

// ==================== MIDDLEWARE ====================
const verifyAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ message: 'Không có token' });
    const admin      = require('firebase-admin');
    const decoded    = await admin.auth().verifyIdToken(token);
    const User       = require('../models/usermodel');
    const mongoUser  = await User.findOne({ _id: decoded.uid });
    if (!mongoUser || mongoUser.role !== 'admin')
      return res.status(403).json({ message: 'Chỉ admin mới có quyền truy cập' });
    req.userId = decoded.uid;
    req.isAdmin = true;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token không hợp lệ' });
  }
};

// ==================== IN-MEMORY CACHE ====================
const _cache   = {};
const CACHE_TTL = 5 * 60 * 1000;

const cached = async (key, fn) => {
  const now = Date.now();
  if (_cache[key] && now - _cache[key].ts < CACHE_TTL) return _cache[key].data;
  const data = await fn();
  _cache[key] = { data, ts: now };
  return data;
};

// ==================== HELPERS ====================

/**
 * FIX: Normalize tên tỉnh/huyện/xã để match linh hoạt hơn
 * Loại bỏ prefix "Tỉnh ", "Thành phố ", "Quận ", "Huyện ", "Phường ", "Xã "
 * để regex match được cả hai dạng
 */
const normalizeLocationName = (name) => {
  if (!name) return '';
  return name
    .replace(/^tỉnh\s+/i, '')
    .replace(/^thành phố\s+/i, '')
    .replace(/^tp\.\s*/i, '')
    .replace(/^quận\s+/i, '')
    .replace(/^huyện\s+/i, '')
    .replace(/^thị xã\s+/i, '')
    .replace(/^thị trấn\s+/i, '')
    .replace(/^phường\s+/i, '')
    .replace(/^xã\s+/i, '')
    .trim();
};

/**
 * FIX: Build $match với normalize - hỗ trợ cả tên đầy đủ và tên rút gọn
 */
const buildMatch = ({ province, district, ward } = {}) => {
  const base = { status: 'available' };
  if (!province && !district && !ward) return base;

  const conditions = [];

  if (province) {
    // Normalize để lấy phần tên cốt lõi (VD: "Tỉnh Bạc Liêu" → "Bạc Liêu")
    const normalizedProvince = normalizeLocationName(province);
    // Escape special regex chars
    const escapedProvince = normalizedProvince.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    conditions.push({ $or: [
      { 'addressComponents.province': { $regex: escapedProvince, $options: 'i' } },
      { 'location.fullAddress':        { $regex: escapedProvince, $options: 'i' } },
      { 'location.short':              { $regex: escapedProvince, $options: 'i' } },
      // Also try full name
      { 'addressComponents.province': { $regex: province.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' } },
    ]});
  }
  if (district) {
    const normalizedDistrict = normalizeLocationName(district);
    const escapedDistrict = normalizedDistrict.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    conditions.push({ $or: [
      { 'addressComponents.district': { $regex: escapedDistrict, $options: 'i' } },
      { 'location.fullAddress':        { $regex: escapedDistrict, $options: 'i' } },
      { 'addressComponents.district': { $regex: district.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' } },
    ]});
  }
  if (ward) {
    const normalizedWard = normalizeLocationName(ward);
    const escapedWard = normalizedWard.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    conditions.push({ $or: [
      { 'addressComponents.ward': { $regex: escapedWard, $options: 'i' } },
      { 'location.fullAddress':    { $regex: escapedWard, $options: 'i' } },
      { 'addressComponents.ward': { $regex: ward.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' } },
    ]});
  }

  return conditions.length === 1
    ? { ...base, ...conditions[0] }
    : { ...base, $and: conditions };
};

/**
 * Aggregation $group fields
 */
const GRP = {
  province: { $trim: { input: {
    $cond: [
      { $and: [{ $ifNull: ['$addressComponents.province', false] }, { $gt: [{ $strLenCP: { $ifNull: ['$addressComponents.province',''] } }, 0] }] },
      '$addressComponents.province',
      { $cond: [
        { $gt: [{ $strLenCP: { $ifNull: ['$location.short',''] } }, 0] },
        '$location.short',
        { $arrayElemAt: [{ $split: ['$location.fullAddress', ','] }, -2] }
      ]},
    ],
  }}},

  district: { $trim: { input: {
    $cond: [
      { $and: [{ $ifNull: ['$addressComponents.district', false] }, { $gt: [{ $strLenCP: { $ifNull: ['$addressComponents.district',''] } }, 0] }] },
      '$addressComponents.district',
      { $arrayElemAt: [{ $split: ['$location.fullAddress', ','] }, 1] },
    ],
  }}},

  ward: { $trim: { input: {
    $cond: [
      { $and: [{ $ifNull: ['$addressComponents.ward', false] }, { $gt: [{ $strLenCP: { $ifNull: ['$addressComponents.ward',''] } }, 0] }] },
      '$addressComponents.ward',
      { $arrayElemAt: [{ $split: ['$location.fullAddress', ','] }, 0] },
    ],
  }}},
};

const JUNK = ['', 'việt nam', 'vietnam', 'viet nam', 'null', 'undefined'];
const cleanLocations = (arr) =>
  arr.filter(l => l.name && !JUNK.includes(l.name.toLowerCase().trim()));

const aggrPipeline = (match, groupField, type, limit = 10) => [
  { $match: match },
  { $group: { _id: groupField, count: { $sum: 1 }, avgPrice: { $avg: '$price' } } },
  { $match: { _id: { $nin: [null, '', ...JUNK] } } },
  { $sort: { count: -1 } },
  { $limit: limit },
  { $project: {
    _id: 0,
    type: { $literal: type },
    name: { $trim: { input: '$_id' } },
    count: 1,
    avgPrice: { $round: ['$avgPrice', 0] },
  }},
];

// ==================== ROUTES ====================

/** 1. Tổng quan */
router.get('/overview', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `ov:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      const [[ps], [as_], total] = await Promise.all([
        Rental.aggregate([{ $match: { ...m, price: { $gt: 0 } } },
          { $group: { _id: null, avgPrice: { $avg: '$price' }, maxPrice: { $max: '$price' }, minPrice: { $min: '$price' } } }]),
        Rental.aggregate([{ $match: { ...m, 'area.total': { $gt: 0 } } },
          { $group: { _id: null, avgArea: { $avg: '$area.total' }, maxArea: { $max: '$area.total' }, minArea: { $min: '$area.total' } } }]),
        Rental.countDocuments(m),
      ]);
      return {
        totalRentals: total,
        priceStats: ps  ? { avgPrice: ps.avgPrice,  maxPrice: ps.maxPrice,  minPrice: ps.minPrice  } : { avgPrice: 0, maxPrice: 0, minPrice: 0 },
        areaStats:  as_ ? { avgArea:  as_.avgArea,  maxArea:  as_.maxArea,  minArea:  as_.minArea  } : { avgArea: 0,  maxArea: 0,  minArea:  0 },
        filters: { province, district, ward },
      };
    });
    res.json(data);
  } catch (err) {
    console.error('overview:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 2. Phân bố giá */
router.get('/price-distribution', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `pd:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      const ranges = [
        { min: 0,          max: 1e6,  label: '< 1 triệu',   color: '#4CAF50' },
        { min: 1e6,        max: 3e6,  label: '1–3 triệu',   color: '#8BC34A' },
        { min: 3e6,        max: 5e6,  label: '3–5 triệu',   color: '#FFC107' },
        { min: 5e6,        max: 10e6, label: '5–10 triệu',  color: '#FF9800' },
        { min: 10e6,       max: 20e6, label: '10–20 triệu', color: '#FF5722' },
        { min: 20e6,       max: null, label: '> 20 triệu',  color: '#F44336' },
      ];
      const counts = await Promise.all(ranges.map(r =>
        Rental.countDocuments({ ...m, price: { $gte: r.min, ...(r.max ? { $lt: r.max } : {}) } })
      ));
      const total = counts.reduce((a, b) => a + b, 0);
      return ranges.map((r, i) => ({
        label: r.label, color: r.color, count: counts[i],
        percentage: total > 0 ? +((counts[i] / total) * 100).toFixed(1) : 0,
      })).filter(r => r.count > 0);
    });
    res.json(data);
  } catch (err) {
    console.error('price-dist:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 3. Timeline */
router.get('/posts-timeline', async (req, res) => {
  try {
    const { period = 'day', province, district, ward } = req.query;
    const key = `tl:${period}:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      let fmt = '%Y-%m-%d', days = 30;
      if (period === 'week')  { fmt = '%G-W%V'; days = 84; }
      if (period === 'month') { fmt = '%Y-%m';  days = 365; }
      const since = new Date(); since.setDate(since.getDate() - days);
      const tl = await Rental.aggregate([
        { $match: { ...m, createdAt: { $gte: since } } },
        { $group: { _id: { $dateToString: { format: fmt, date: '$createdAt' } }, count: { $sum: 1 }, avgPrice: { $avg: '$price' } } },
        { $sort: { _id: 1 } },
      ]);
      return { period, data: tl };
    });
    res.json(data);
  } catch (err) {
    console.error('timeline:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 4. Location stats */
router.get('/location-stats', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `ls:${province||'all'}:${district||'all'}:${ward||'all'}`;

    const data = await cached(key, async () => {
      let locations = [];
      let filterLevel = 'none';

      if (ward && district && province) {
        filterLevel = 'ward';
        const m = buildMatch({ province, district, ward });
        const [cnt, [avg]] = await Promise.all([
          Rental.countDocuments(m),
          Rental.aggregate([{ $match: m }, { $group: { _id: null, avgPrice: { $avg: '$price' } } }]),
        ]);
        locations = [{ type: 'ward', name: ward, count: cnt, avgPrice: Math.round(avg?.avgPrice ?? 0) }];

      } else if (district && province) {
        filterLevel = 'district';
        const m = buildMatch({ province, district });
        locations = await Rental.aggregate(aggrPipeline(m, GRP.ward, 'ward'));

      } else if (province) {
        filterLevel = 'province';
        const m = buildMatch({ province });
        locations = await Rental.aggregate(aggrPipeline(m, GRP.district, 'district'));

      } else {
        filterLevel = 'none';
        // FIX: Tăng limit lên 63 để lấy đủ tất cả tỉnh/tp Việt Nam
        locations = await Rental.aggregate(aggrPipeline({ status: 'available' }, GRP.province, 'province', 63));
      }

      locations = cleanLocations(locations);
      const totalPosts = locations.reduce((s, l) => s + l.count, 0);
      console.log(`location-stats [${filterLevel}] ${locations.length} items total=${totalPosts}`);
      return { locations, filterLevel, totalPosts, filters: { province, district, ward } };
    });

    res.json(data);
  } catch (err) {
    console.error('location-stats:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 5. Hottest areas */
router.get('/hottest-areas', async (req, res) => {
  try {
    const { province, district, ward, days = 7 } = req.query;
    const daysN = Math.min(+days || 7, 90);
    const key = `hot:${province||''}:${district||''}:${ward||''}:${daysN}`;

    const data = await cached(key, async () => {
      const since = new Date(); since.setDate(since.getDate() - daysN);
      const m = { ...buildMatch({ province, district, ward }), createdAt: { $gte: since } };
      const gf = district ? GRP.ward : province ? GRP.district : GRP.province;

      const rows = await Rental.aggregate([
        { $match: m },
        { $group: { _id: gf, count: { $sum: 1 }, avgPrice: { $avg: '$price' } } },
        { $match: { _id: { $nin: [null, '', ...JUNK] } } },
        { $sort: { count: -1 } },
        { $limit: 10 },
        { $project: { _id: { $trim: { input: '$_id' } }, count: 1, avgPrice: { $round: ['$avgPrice', 0] } } },
      ]);
      return rows.filter(r => r._id && r._id.trim().length > 0);
    });
    res.json(data);
  } catch (err) {
    console.error('hottest:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 6. Trending areas - FIX: trả về đúng totalViews từ UserInteraction */
router.get('/trending-areas', async (req, res) => {
  try {
    const { province, district, ward, days = 7 } = req.query;
    const daysN = Math.min(+days || 7, 90);
    const key = `tr:${province||''}:${district||''}:${ward||''}:${daysN}`;

    const data = await cached(key, async () => {
      const since = new Date(); since.setDate(since.getDate() - daysN);
      const m = { ...buildMatch({ province, district, ward }), createdAt: { $gte: since } };
      const gf = district ? GRP.ward : province ? GRP.district : GRP.province;

      // FIX: Thử lấy views từ UserInteraction model nếu tồn tại
      let useInteractionViews = false;
      try {
        const UserInteraction = require('../models/UserInteraction');
        useInteractionViews = true;

        // Lấy views từ UserInteraction trong khoảng thời gian
        const interactionSince = new Date(); interactionSince.setDate(interactionSince.getDate() - daysN);
        
        // Join Rental với UserInteraction để tính views thực
        const rows = await Rental.aggregate([
          { $match: m },
          {
            $lookup: {
              from: 'userinteractions',
              let: { rentalId: '$_id' },
              pipeline: [
                {
                  $match: {
                    $expr: { $eq: ['$rentalId', '$$rentalId'] },
                    interactionType: 'view',
                    timestamp: { $gte: interactionSince },
                  }
                },
                { $count: 'total' }
              ],
              as: 'interactionData'
            }
          },
          {
            $addFields: {
              realViews: {
                $cond: [
                  { $gt: [{ $size: '$interactionData' }, 0] },
                  { $arrayElemAt: ['$interactionData.total', 0] },
                  { $ifNull: ['$views', 0] }
                ]
              }
            }
          },
          { $group: {
            _id: gf,
            postCount:  { $sum: 1 },
            totalViews: { $sum: '$realViews' },
            avgPrice:   { $avg: '$price' },
          }},
          { $match: { _id: { $nin: [null, '', ...JUNK] } } },
          { $addFields: { score: { $add: ['$totalViews', { $multiply: ['$postCount', 10] }] } } },
          { $sort: { score: -1 } },
          { $limit: 10 },
          { $project: {
            _id:        { $trim: { input: '$_id' } },
            totalViews: 1,
            postCount:  1,
            avgPrice:   { $round: ['$avgPrice', 0] },
            score:      1,
          }},
        ]);
        return rows.filter(r => r._id && r._id.trim().length > 0);

      } catch (lookupErr) {
        console.warn('UserInteraction lookup failed, falling back to views field:', lookupErr.message);
      }

      // Fallback: dùng field views trực tiếp trên Rental
      const rows = await Rental.aggregate([
        { $match: m },
        { $group: {
          _id:        gf,
          postCount:  { $sum: 1 },
          totalViews: { $sum: { $ifNull: ['$views', 0] } },
          avgPrice:   { $avg: '$price' },
        }},
        { $match: { _id: { $nin: [null, '', ...JUNK] } } },
        { $addFields: { score: { $add: ['$totalViews', { $multiply: ['$postCount', 10] }] } } },
        { $sort: { score: -1 } },
        { $limit: 10 },
        { $project: {
          _id:        { $trim: { input: '$_id' } },
          totalViews: 1,
          postCount:  1,
          avgPrice:   { $round: ['$avgPrice', 0] },
        }},
      ]);
      return rows.filter(r => r._id && r._id.trim().length > 0);
    });
    res.json(data);
  } catch (err) {
    console.error('trending:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 7. Property types */
router.get('/property-types', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `pt:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      const total = await Rental.countDocuments(m);
      return Rental.aggregate([
        { $match: m },
        { $group: { _id: '$propertyType', count: { $sum: 1 }, avgPrice: { $avg: '$price' }, avgArea: { $avg: '$area.total' } } },
        { $match: { _id: { $ne: null } } },
        { $sort: { count: -1 } },
        { $project: {
          count: 1, avgPrice: { $round: ['$avgPrice', 0] }, avgArea: { $round: ['$avgArea', 1] },
          percentage: { $round: [{ $multiply: [{ $divide: ['$count', total || 1] }, 100] }, 1] },
        }},
      ]);
    });
    res.json(data);
  } catch (err) {
    console.error('property-types:', err);
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** Clear cache (admin) */
router.post('/clear-cache', verifyAdmin, (req, res) => {
  const n = Object.keys(_cache).length;
  for (const k in _cache) delete _cache[k];
  res.json({ message: 'Cache cleared', clearedKeys: n });
});


// ========================
/** 8. Phân bố diện tích */
router.get('/area-distribution', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `ad:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      const ranges = [
        { min: 0,   max: 20,  label: '< 20 m²',   color: '#60A5FA' },
        { min: 20,  max: 35,  label: '20–35 m²',  color: '#34D399' },
        { min: 35,  max: 50,  label: '35–50 m²',  color: '#FBBF24' },
        { min: 50,  max: 80,  label: '50–80 m²',  color: '#F97316' },
        { min: 80,  max: 120, label: '80–120 m²', color: '#A78BFA' },
        { min: 120, max: null,label: '> 120 m²',  color: '#F43F5E' },
      ];
      const counts = await Promise.all(ranges.map(r =>
        Rental.countDocuments({
          ...m,
          'area.total': { $gte: r.min, ...(r.max ? { $lt: r.max } : {}) },
        })
      ));
      const total = counts.reduce((a, b) => a + b, 0);
      return ranges.map((r, i) => ({
        label: r.label, color: r.color, count: counts[i],
        percentage: total > 0 ? +((counts[i] / total) * 100).toFixed(1) : 0,
      })).filter(r => r.count > 0);
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 9. Top tiện nghi & nội thất phổ biến + media stats */
router.get('/amenities-stats', async (req, res) => {
  try {
    const { province, district, ward } = req.query;
    const key = `am:${province||''}:${district||''}:${ward||''}`;

    const data = await cached(key, async () => {
      const m = buildMatch({ province, district, ward });
      const total = await Rental.countDocuments(m);

      const [amenitiesRaw, furnitureRaw, mediaRaw] = await Promise.all([
        Rental.aggregate([
          { $match: m },
          { $unwind: '$amenities' },
          { $group: { _id: '$amenities', count: { $sum: 1 } } },
          { $match: { _id: { $ne: null } } },
          { $sort: { count: -1 } }, { $limit: 10 },
          { $project: { _id: 0, name: '$_id', count: 1,
            percentage: { $round: [{ $multiply: [{ $divide: ['$count', total||1] }, 100] }, 1] } } },
        ]),
        Rental.aggregate([
          { $match: m },
          { $unwind: '$furniture' },
          { $group: { _id: '$furniture', count: { $sum: 1 } } },
          { $match: { _id: { $ne: null } } },
          { $sort: { count: -1 } }, { $limit: 10 },
          { $project: { _id: 0, name: '$_id', count: 1,
            percentage: { $round: [{ $multiply: [{ $divide: ['$count', total||1] }, 100] }, 1] } } },
        ]),
        Rental.aggregate([
          { $match: m },
          { $group: {
            _id: null,
            withImages: { $sum: { $cond: [{ $gt: [{ $size: { $ifNull: ['$images',[]] } }, 0] }, 1, 0] } },
            withVideos: { $sum: { $cond: [{ $gt: [{ $size: { $ifNull: ['$videos',[]] } }, 0] }, 1, 0] } },
            avgImages:  { $avg: { $size: { $ifNull: ['$images',[]] } } },
          }},
        ]),
      ]);

      const ms = mediaRaw[0] || {};
      return {
        amenities: amenitiesRaw,
        furniture: furnitureRaw,
        mediaStats: {
          withImages: ms.withImages || 0,
          withVideos: ms.withVideos || 0,
          avgImages:  +(ms.avgImages || 0).toFixed(1),
          totalRentals: total,
          imageCoverage: total > 0 ? +((ms.withImages / total) * 100).toFixed(1) : 0,
          videoCoverage: total > 0 ? +((ms.withVideos / total) * 100).toFixed(1) : 0,
        },
      };
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 10. Hành vi người dùng */
router.get('/user-behavior', async (req, res) => {
  try {
    const { days = 30 } = req.query;
    const daysN = Math.min(+days || 30, 180);
    const key = `ub:${daysN}`;

    const data = await cached(key, async () => {
      const since = new Date(); since.setDate(since.getDate() - daysN);
      let interactionStats = { totalViews: 0, totalFavorites: 0, totalContacts: 0, conversionRate: 0 };
      let topViewedRentals = [];
      let behaviorByHour   = [];

      try {
        const UserInteraction = require('../models/UserInteraction');
        const [summary, topViewed, hourly] = await Promise.all([
          UserInteraction.aggregate([
            { $match: { timestamp: { $gte: since } } },
            { $group: { _id: '$interactionType', count: { $sum: 1 } } },
          ]),
          UserInteraction.aggregate([
            { $match: { interactionType: 'view', timestamp: { $gte: since } } },
            { $group: { _id: '$rentalId', views: { $sum: 1 } } },
            { $sort: { views: -1 } }, { $limit: 5 },
            { $lookup: { from: 'rentals', localField: '_id', foreignField: '_id', as: 'rental' } },
            { $unwind: { path: '$rental', preserveNullAndEmptyArrays: true } },
            { $project: {
              rentalId: '$_id', views: 1,
              title:    '$rental.title',
              price:    '$rental.price',
              location: '$rental.location.short',
              image:    { $arrayElemAt: ['$rental.images', 0] },
            }},
          ]),
          UserInteraction.aggregate([
            { $match: { timestamp: { $gte: since } } },
            { $group: { _id: { $hour: '$timestamp' }, count: { $sum: 1 } } },
            { $sort: { _id: 1 } },
            { $project: { _id: 0, hour: '$_id', count: 1 } },
          ]),
        ]);
        const views     = summary.find(s => s._id === 'view')?.count     || 0;
        const favorites = summary.find(s => s._id === 'favorite')?.count || 0;
        const contacts  = summary.find(s => s._id === 'contact')?.count  || 0;
        interactionStats = {
          totalViews: views, totalFavorites: favorites, totalContacts: contacts,
          conversionRate: views > 0 ? +((contacts / views) * 100).toFixed(2) : 0,
        };
        topViewedRentals = topViewed;
        behaviorByHour   = hourly;
      } catch (e) { console.warn('UserInteraction unavailable:', e.message); }

      return { interactionStats, topViewedRentals, behaviorByHour, days: daysN };
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});

/** 11. Tăng trưởng tổng hợp */
router.get('/growth-stats', async (req, res) => {
  try {
    const { months = 6 } = req.query;
    const monthsN = Math.min(+months || 6, 24);
    const key = `gs:${monthsN}`;

    const data = await cached(key, async () => {
      const since = new Date();
      since.setMonth(since.getMonth() - monthsN);
      since.setDate(1); since.setHours(0,0,0,0);

      const Payment = require('../models/Payment');
      const User    = require('../models/usermodel');

      const [postGrowth, userGrowth, revenueGrowth, statusStats, ratingStats] = await Promise.all([
        Rental.aggregate([
          { $match: { createdAt: { $gte: since } } },
          { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } }, count: { $sum: 1 } } },
          { $sort: { _id: 1 } },
        ]),
        User.aggregate([
          { $match: { createdAt: { $gte: since } } },
          { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } }, count: { $sum: 1 } } },
          { $sort: { _id: 1 } },
        ]),
        Payment.aggregate([
          { $match: { status: 'completed', completedAt: { $gte: since } } },
          { $group: {
            _id:     { $dateToString: { format: '%Y-%m', date: '$completedAt' } },
            revenue: { $sum: '$amount' }, count: { $sum: 1 },
          }},
          { $sort: { _id: 1 } },
        ]),
        Rental.aggregate([
          { $group: { _id: '$status', count: { $sum: 1 } } },
          { $project: { _id: 0, status: '$_id', count: 1 } },
        ]),
        (async () => {
          try {
            const { Comment } = require('../models/comments');
            const r = await Comment.aggregate([
              { $match: { rating: { $gt: 0 } } },
              { $group: {
                _id: null, avgRating: { $avg: '$rating' }, total: { $sum: 1 }, dist: { $push: '$rating' },
              }},
              { $project: {
                avgRating: { $round: ['$avgRating', 1] }, total: 1,
                fiveStar:  { $size: { $filter: { input: '$dist', cond: { $eq: ['$$this', 5] } } } },
                fourStar:  { $size: { $filter: { input: '$dist', cond: { $eq: ['$$this', 4] } } } },
                threeStar: { $size: { $filter: { input: '$dist', cond: { $eq: ['$$this', 3] } } } },
                twoStar:   { $size: { $filter: { input: '$dist', cond: { $eq: ['$$this', 2] } } } },
                oneStar:   { $size: { $filter: { input: '$dist', cond: { $eq: ['$$this', 1] } } } },
              }},
            ]);
            return r[0] || { avgRating: 0, total: 0 };
          } catch (e) { return { avgRating: 0, total: 0 }; }
        })(),
      ]);

      return { postGrowth, userGrowth, revenueGrowth, statusStats, ratingStats, months: monthsN };
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({ message: 'Failed', error: err.message });
  }
});
module.exports = router;