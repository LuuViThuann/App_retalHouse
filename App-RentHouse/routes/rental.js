require('dotenv').config();

const express = require('express'); 
const router = express.Router();
const mongoose = require('mongoose');
const Rental = require('../models/Rental'); 
const Favorite = require('../models/favorite');
const { Comment, Reply, LikeComment } = require('../models/comments');
const admin = require('firebase-admin');// liên kết với firebase
const multer = require('multer'); // lưu ảnh vào thư mục uploads
const path = require('path'); // lưu ảnh vào thư mục uploads
const redis = require('redis'); // Giúp lưu trữ dữ liệu trong bộ nhớ
const sharp = require('sharp'); // Giúp xử lý ảnh nhỏ hơn
const { Client } = require('@elastic/elasticsearch'); // lưu ảnh vào thư mục uploads
const fs = require('fs').promises; // Giúp xử lý file 

// ----------------------------------------------------------------------------------
// kết nối đến redis ---------------
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379', // kết nối đến redis
});
redisClient.on('error', (err) => console.log('Redis Client Error', err)); // báo lỗi khi lỗi kết nối
redisClient.connect();

// Elasticsearch client
// kết nối đến elasticsearch ---------------
const elasticClient = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  maxRetries: 3, // số lần thử lại khi lỗi
  requestTimeout: 30000, // thời gian chờ kết nối
  sniffOnStart: false, // không sniff khi khởi động
  sniffOnConnectionFault: false, // không sniff khi lỗi kết nối
});
// ----------------------------------------------------------------------------------
// Multer storage configuration
// lưu ảnh vào thư mục uploads ---------------
const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ 
  storage,
  limits: { fileSize: 100 * 1024 * 1024 } //  lưu ảnh tối đa 100MB > báo lỗi 
});
router.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// ----------------------------------------------------------------------------------

// Authentication middleware
// kiểm tra token ---------------
const authMiddleware = async (req, res, next) => { // 
  const token = req.header('Authorization')?.replace('Bearer ', ''); // lấy token từ header
  if (!token) return res.status(401).json({ message: 'No token provided' }); // nếu không có token thì báo lỗi
  try {
    const decodedToken = await admin.auth().verifyIdToken(token); // giải mã token
    req.userId = decodedToken.uid; // lấy id từ token
    next(); // tiếp tục
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' }); // nếu lỗi thì báo lỗi
  }
};
// ----------------------------------------------------------------------------------
// Helper function to adjust timestamps for +7 timezone
// hàm điều chỉnh thời gian theo múi giờ +7
const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() }; // tạo một đối tượng mới từ đối tượng cũ
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000); // điều chỉnh thời gian theo múi giờ +7
  return adjusted; // trả về đối tượng đã điều chỉnh
};
// ----------------------------------------------------------------------------------
// Sync rental to Elasticsearch (non-blocking)
// hàm đồng bộ dữ liệu từ MongoDB sang Elasticsearch
const syncRentalToElasticsearch = async (rental) => {
  try {
    const headers = {
      Accept: 'application/json', // chấp nhận dữ liệu dạng json
      'Content-Type': 'application/json', // định dạng dữ liệu là json
    };
    console.log('Elasticsearch sync headers:', headers); // log headers
    const response = await elasticClient.index({
      index: 'rentals', // tên index
      id: rental._id.toString(), // id của rental
      body: {
        title: rental.title, // tên của rental
        price: parseFloat(rental.price) || 0, // giá của rental
        location: rental.location.short, // vị trí của rental
        propertyType: rental.propertyType, // loại bất động sản
        status: rental.status, // trạng thái của rental
        area: parseFloat(rental.area.total) || 0, // diện tích của rental
        createdAt: rental.createdAt, // thời gian tạo của rental
        images: rental.images || [], // ảnh của rental
      },
      headers, // headers
    });
    console.log(`Synced rental ${rental._id} to Elasticsearch`, response); // log response
  } catch (err) {
    console.error('Error syncing to Elasticsearch:', err); // log lỗi
  }
};
// ----------------------------------------------------------------------------------
// Build MongoDB query
// hàm tạo query cho MongoDB
const buildMongoQuery = ({ search, minPrice, maxPrice, propertyTypes, status }) => {
  const query = {}; // tạo một đối tượng mới
  if (search) {
    query.$or = [
      { title: { $regex: search, $options: 'i' } }, // tìm kiếm theo tên
      { 'location.short': { $regex: search, $options: 'i' } }, // tìm kiếm theo vị trí
    ];
  }
  if (minPrice || maxPrice) {
    query.price = {}; // tạo một đối tượng mới  
    if (minPrice) query.price.$gte = Number(minPrice); // giá tối thiểu
    if (maxPrice) query.price.$lte = Number(maxPrice); // giá tối đa
  }
  if (propertyTypes && propertyTypes.length > 0) {
    query.propertyType = { $in: propertyTypes }; // tìm kiếm theo loại bất động sản
  }
  if (status) query.status = status; // tìm kiếm theo trạng thái
  return query; // trả về query
};
// ----------------------------------------------------------------------------------
// Sanitize headers middleware
// hàm xử lý headers
const sanitizeHeadersMiddleware = (req, res, next) => {
  if (req.headers.accept && req.headers.accept.includes('application/vnd.elasticsearch+json')) { // nếu header accept là application/vnd.elasticsearch+json thì thay thế bằng application/json
    req.headers.accept = 'application/json'; // thay thế header accept bằng application/json
  }
  next(); // tiếp tục
};
// ----------------------------------------------------------------------------------
// Search rentals
// hàm tìm kiếm bất động sản
router.get('/rentals/search', [sanitizeHeadersMiddleware], async (req, res) => {
  try {
    const { search, minPrice, maxPrice, propertyType, status, page = 1, limit = 10 } = req.query; // lấy các tham số từ query
    const propertyTypes = propertyType ? (Array.isArray(propertyType) ? propertyType : [propertyType]) : []; // lấy các tham số từ query
    const skip = (Number(page) - 1) * Number(limit); // tính toán số lượng bất động sản cần bỏ qua

    const cacheKey = `search:${search || ''}:${minPrice || ''}:${maxPrice || ''}:${propertyTypes.join(',')}:${status || ''}:${page}:${limit}`;
    const cachedResult = await redisClient.get(cacheKey); // lấy kết quả từ cache
    if (cachedResult) {
      console.log('Serving from cache:', cacheKey); // log kết quả từ cache
      return res.json(JSON.parse(cachedResult)); // trả về kết quả từ cache
    }

    console.log('Search query:', { search, minPrice, maxPrice, propertyTypes, status, page, limit }); // log query

    if (search && req.header('Authorization')) {
      const token = req.header('Authorization').replace('Bearer ', ''); // lấy token từ header
      try {
        const decodedToken = await admin.auth().verifyIdToken(token); // giải mã token
        const userId = decodedToken.uid; // lấy id từ token
        const searchKey = `search:${userId}`; // tạo key từ id
        await redisClient.lPush(searchKey, search); // lưu search vào cache
        await redisClient.lTrim(searchKey, 0, 9); // giới hạn số lượng search trong cache
        console.log(`Saved search "${search}" for user ${userId}`); // log kết quả
      } catch (err) {
        console.error('Error saving search history:', err); // log lỗi
      }
    }

    let rentals = []; // tạo một mảng mới
    let total = 0; // tạo một biến mới

    try {
      const query = { // tạo một đối tượng mới
        bool: { // tạo một đối tượng mới
          must: [], // tạo một mảng mới
          filter: [], // tạo một mảng mới
        },
      }; // tạo một đối tượng mới

      if (search) { // nếu có search
        query.bool.must.push({ // thêm search vào query
          multi_match: { // tạo một đối tượng mới
            query: search, // tên của search
            fields: ['title^2', 'location'], // tên của search
            fuzziness: 'AUTO', // tên của search
          },
        }); // thêm search vào query
      }

      if (minPrice || maxPrice) { // nếu có minPrice hoặc maxPrice
        const priceFilter = {}; // tạo một đối tượng mới
        if (minPrice) priceFilter.gte = Number(minPrice); // giá tối thiểu
        if (maxPrice) priceFilter.lte = Number(maxPrice); // giá tối đa
        query.bool.filter.push({ range: { price: priceFilter } }); // thêm giá vào query
      }

      if (propertyTypes.length > 0) { // nếu có propertyTypes
        query.bool.filter.push({ // thêm propertyTypes vào query
          terms: { propertyType: propertyTypes }, // thêm propertyTypes vào query
        });
      }

      if (status) { // nếu có status
        query.bool.filter.push({ term: { status } }); // thêm status vào query
      }

      console.log('Elasticsearch query:', JSON.stringify(query, null, 2)); // log query
      const response = await elasticClient.search({
        index: 'rentals', // tên index
        from: skip, // số lượng bất động sản cần bỏ qua
        size: Number(limit), // số lượng bất động sản cần lấy
        body: { query }, // body của query
        headers: {
          Accept: 'application/json', // chấp nhận dữ liệu dạng json
          'Content-Type': 'application/json', // định dạng dữ liệu là json
        },
      });

      const rentalIds = response.hits.hits.map(hit => hit._id); // lấy id của bất động sản
      total = response.hits.total.value; // lấy số lượng bất động sản
      rentals = await Rental.find({ _id: { $in: rentalIds } }).lean(); // lấy bất động sản từ MongoDB
    } catch (esErr) {
      console.error('Elasticsearch search failed:', esErr); // log lỗi
      const mongoQuery = buildMongoQuery({ search, minPrice, maxPrice, propertyTypes, status }); // tạo query cho MongoDB
      rentals = await Rental.find(mongoQuery).skip(skip).limit(Number(limit)).lean(); // lấy bất động sản từ MongoDB
      total = await Rental.countDocuments(mongoQuery); // lấy số lượng bất động sản
    }

    const result = { // tạo một đối tượng mới
      rentals, // bất động sản
      total, // số lượng bất động sản
      page: Number(page), // trang hiện tại
      pages: Math.ceil(total / Number(limit)), // số trang
    };

    await redisClient.setEx(cacheKey, 300, JSON.stringify(result)); // lưu kết quả vào cache
    res.json(result); // trả về kết quả
  } catch (err) {
    console.error('Error fetching rentals:', err); // log lỗi
    res.status(500).json({ message: 'Failed to fetch rentals', error: err.message }); // trả về lỗi
  }
});
// ----------------------------------------------------------------------------------
// Get all rentals
// hàm lấy tất cả bất động sản
router.get('/rentals', async (req, res) => {
  try {
    const { search, minPrice, maxPrice, propertyType, status } = req.query; // lấy các tham số từ query
    let query = {}; // tạo một đối tượng mới
    if (search) query.$or = [{ title: { $regex: search, $options: 'i' } }, { 'location.short': { $regex: search, $options: 'i' } }]; // tìm kiếm theo tên hoặc vị trí
    if (minPrice || maxPrice) { // nếu có minPrice hoặc maxPrice
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice); // giá tối thiểu
      if (maxPrice) query.price.$lte = Number(maxPrice); // giá tối đa
    }
    if (propertyType) query.propertyType = propertyType; // tìm kiếm theo loại bất động sản
    if (status) query.status = status; // tìm kiếm theo trạng thái
    const rentals = await Rental.find(query); // lấy bất động sản từ MongoDB
    res.json(rentals); // trả về kết quả
  } catch (err) {
    res.status(500).json({ message: err.message }); // trả về lỗi
  }
});
// ----------------------------------------------------------------------------------
// Get search history
router.get('/search-history', [sanitizeHeadersMiddleware, authMiddleware], async (req, res) => {
  try {
    const searchKey = `search:${req.userId}`;
    const history = await redisClient.lRange(searchKey, 0, -1);
    res.json(history);
  } catch (err) {
    console.error('Error fetching search history:', err);
    res.status(500).json({ message: 'Failed to fetch search history', error: err.message });
  }
});
// ----------------------------------------------------------------------------------
// Get rental by ID
// hàm lấy bất động sản theo id
// populate là phương thức để lấy dữ liệu từ một bảng khác
router.get('/rentals/:id', async (req, res) => {
  try {
    const rental = await Rental.findById(req.params.id); // lấy bất động sản theo id
    if (!rental) return res.status(404).json({ message: 'Rental not found' }); // nếu không tìm thấy bất động sản thì báo lỗi

    const comments = await Comment.find({ rentalId: req.params.id }) // lấy bình luận theo id
      .populate('userId', 'avatarBase64 username'); // lấy thông tin người dùng gồm avatar và username

    const commentIds = comments.map(c => c._id); // lấy id của bình luận
    const replies = await Reply.find({ commentId: { $in: commentIds } }) // lấy phản hồi theo id
      .populate('userId', 'username') // lấy thông tin người dùng gồm username
      .lean(); // lấy dữ liệu dạng lean là dữ liệu không có thông tin của bảng khác

    const likes = await LikeComment.find({ // lấy thích theo id
      $or: [
        { targetId: { $in: commentIds }, targetType: 'Comment' }, // lấy thích theo id
        { targetId: { $in: replies.map(r => r._id) }, targetType: 'Reply' }, // lấy thích theo id
      ]
    }).populate('userId', 'username').lean(); // lấy thông tin người dùng gồm username

    const replyMap = new Map(); // tạo một đối tượng mới
    replies.forEach(reply => { // lặp qua tất cả các phản hồi
      reply.createdAt = new Date(reply.createdAt.getTime() + 7 * 60 * 60 * 1000); // điều chỉnh thời gian theo múi giờ +7
      reply.likes = likes.filter(like => like.targetId.toString() === reply._id.toString() && like.targetType === 'Reply') // lấy thích theo id
        .map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      const commentIdStr = reply.commentId.toString(); // lấy id của bình luận
      if (!replyMap.has(commentIdStr)) { // nếu không có id của bình luận trong replyMap thì thêm id của bình luận vào replyMap
        replyMap.set(commentIdStr, []); // thêm id của bình luận vào replyMap
      }
      replyMap.get(commentIdStr).push(reply); // thêm phản hồi vào replyMap
    });

    const buildReplyTree = (replyList, parentId = null) => { // hàm tạo cây phản hồi
      return replyList // lấy tất cả các phản hồi
        .filter(reply => (parentId ? reply.parentReplyId?.toString() === parentId : !reply.parentReplyId)) // lấy phản hồi theo id
        .map(reply => ({ // lấy phản hồi theo id
          ...reply,
          replies: buildReplyTree(replyList, reply._id.toString()) // lấy phản hồi theo id
        }));
    };

    const adjustedComments = comments.map(comment => { // lấy tất cả các bình luận
      const commentObj = adjustTimestamps(comment); // điều chỉnh thời gian theo múi giờ +7
      commentObj.replies = buildReplyTree(replyMap.get(comment._id.toString()) || []); // lấy phản hồi theo id
      commentObj.likes = likes.filter(like => like.targetId.toString() === comment._id.toString() && like.targetType === 'Comment') // lấy thích theo id
        .map(like => ({ ...like, createdAt: new Date(like.createdAt.getTime() + 7 * 60 * 60 * 1000) }));
      return commentObj;
    });

    const totalRatings = adjustedComments.reduce((sum, comment) => sum + (comment.rating || 0), 0); // lấy tổng đánh giá
    const averageRating = adjustedComments.length > 0 ? totalRatings / adjustedComments.length : 0; // lấy đánh giá trung bình

    res.json({
      ...rental.toObject(),
      comments: adjustedComments, // bình luận
      averageRating, // đánh giá trung bình
      reviewCount: adjustedComments.length // số lượng đánh giá
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});
// ----------------------------------------------------------------------------------
// Create rental
// Code tạo bất động sản
router.post('/rentals', authMiddleware, upload.array('images'), async (req, res) => {
  try {
    const imageUrls = req.files.map(file => `/uploads/${file.filename}`); // lấy url của ảnh
    const contactInfoName = req.body.contactInfoName || req.user.displayName || 'Chủ nhà'; // lấy tên của chủ nhà
    const contactInfoPhone = req.body.contactInfoPhone || req.user.phoneNumber || 'Không có số điện thoại'; // lấy số điện thoại của chủ nhà
    const rental = new Rental({ // tạo một đối tượng mới
      title: req.body.title, // tên của bất động sản
      price: req.body.price, // giá của bất động sản
      area: { total: req.body.areaTotal, livingRoom: req.body.areaLivingRoom, bedrooms: req.body.areaBedrooms, bathrooms: req.body.areaBathrooms }, // diện tích của bất động sản
      location: { short: req.body.locationShort, fullAddress: req.body.locationFullAddress }, // vị trí của bất động sản
      propertyType: req.body.propertyType, // loại bất động sản
      furniture: req.body.furniture ? req.body.furniture.split(',').map(item => item.trim()) : [], // nội thất của bất động sản
      amenities: req.body.amenities ? req.body.amenities.split(',').map(item => item.trim()) : [], // tiện ích của bất động sản
      surroundings: req.body.surroundings ? req.body.surroundings.split(',').map(item => item.trim()) : [], // môi trường xung quanh của bất động sản
      rentalTerms: { minimumLease: req.body.rentalTermsMinimumLease, deposit: req.body.rentalTermsDeposit, paymentMethod: req.body.rentalTermsPaymentMethod, renewalTerms: req.body.rentalTermsRenewalTerms }, // điều kiện thuê của bất động sản
      contactInfo: { name: contactInfoName, phone: contactInfoPhone, availableHours: req.body.contactInfoAvailableHours }, // thông tin liên hệ của chủ nhà
      userId: req.userId, // id của người dùng
      images: imageUrls,
      status: req.body.status || 'available', // trạng thái của bất động sản
    });
    const newRental = await rental.save(); // lưu bất động sản vào MongoDB
    syncRentalToElasticsearch(newRental); // đồng bộ dữ liệu từ MongoDB sang Elasticsearch
    res.status(201).json(newRental); // trả về kết quả
  } catch (err) {
    console.error('Error creating rental:', err); // log lỗi
    if (err instanceof multer.MulterError) { // nếu lỗi là multer
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(400).json({ message: 'Failed to create rental', error: err.message });
  }
});
// ----------------------------------------------------------------------------------

// Update rental
router.patch('/rentals/:id', authMiddleware, upload.array('images'), async (req, res) => { // hàm cập nhật bất động sản
  try {
    // Kiểm tra ID hợp lệ
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) { // nếu id không hợp lệ
      return res.status(400).json({ message: 'Invalid rental ID' }); // trả về lỗi
    }

    // Tìm rental
    const rental = await Rental.findById(req.params.id); // lấy bất động sản theo id
    if (!rental) { // nếu không tìm thấy bất động sản
      return res.status(404).json({ message: 'Rental not found' }); // trả về lỗi
    }
    if (rental.userId !== req.userId) { // nếu id của người dùng không trùng với id của bất động sản
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' }); // trả về lỗi
    }

    // Chuẩn bị dữ liệu cập nhật
    const updatedData = {}; // tạo một đối tượng mới
    if (req.body.title) updatedData.title = req.body.title; // tên của bất động sản
    if (req.body.price) updatedData.price = parseFloat(req.body.price) || rental.price; // giá của bất động sản
    if (req.body.areaTotal || req.body.areaLivingRoom || req.body.areaBedrooms || req.body.areaBathrooms) {
      updatedData.area = { // diện tích của bất động sản
        total: parseFloat(req.body.areaTotal) || rental.area.total, // diện tích của bất động sản
        livingRoom: parseFloat(req.body.areaLivingRoom) || rental.area.livingRoom, // diện tích của bất động sản
        bedrooms: parseFloat(req.body.areaBedrooms) || rental.area.bedrooms, // diện tích của bất động sản
        bathrooms: parseFloat(req.body.areaBathrooms) || rental.area.bathrooms // diện tích của bất động sản
      };
    }
    if (req.body.locationShort || req.body.locationFullAddress) {
      updatedData.location = { // vị trí của bất động sản
        short: req.body.locationShort || rental.location.short, // vị trí của bất động sản
        fullAddress: req.body.locationFullAddress || rental.location.fullAddress // vị trí của bất động sản
      };
    }
    if (req.body.propertyType) updatedData.propertyType = req.body.propertyType;  // loại bất động sản
    if (req.body.furniture) updatedData.furniture = req.body.furniture.split(',').map(item => item.trim()); // nội thất của bất động sản
    if (req.body.amenities) updatedData.amenities = req.body.amenities.split(',').map(item => item.trim()); // tiện ích của bất động sản
    if (req.body.surroundings) updatedData.surroundings = req.body.surroundings.split(',').map(item => item.trim()); // môi trường xung quanh của bất động sản
    if (req.body.rentalTermsMinimumLease || req.body.rentalTermsDeposit || req.body.rentalTermsPaymentMethod || req.body.rentalTermsRenewalTerms) {
      updatedData.rentalTerms = { // điều kiện thuê của bất động sản
        minimumLease: req.body.rentalTermsMinimumLease || rental.rentalTerms.minimumLease, // điều kiện thuê của bất động sản
        deposit: req.body.rentalTermsDeposit || rental.rentalTerms.deposit, // điều kiện thuê của bất động sản
        paymentMethod: req.body.rentalTermsPaymentMethod || rental.rentalTerms.paymentMethod, // điều kiện thuê của bất động sản
        renewalTerms: req.body.rentalTermsRenewalTerms || rental.rentalTerms.renewalTerms // điều kiện thuê của bất động sản
      };
    }
    if (req.body.contactInfoName || req.body.contactInfoPhone || req.body.contactInfoAvailableHours) {
      updatedData.contactInfo = { // thông tin liên hệ của chủ nhà
        name: req.body.contactInfoName || rental.contactInfo.name, // tên của chủ nhà
        phone: req.body.contactInfoPhone || rental.contactInfo.phone, // số điện thoại của chủ nhà
        availableHours: req.body.contactInfoAvailableHours || rental.contactInfo.availableHours
      };
    }
    if (req.body.status) updatedData.status = req.body.status; // code cập nhật trạng thái

    // Xử lý ảnh
    let updatedImages = [...rental.images]; // lấy ảnh của bất động sản
    let removedImages = []; // tạo một mảng mới
    if (req.body.removedImages) { // nếu có removedImages
      try {
        // Nếu là string, thử parse JSON, nếu lỗi thì tách theo dấu phẩy
        if (typeof req.body.removedImages === 'string') {
          try {
            removedImages = JSON.parse(req.body.removedImages); // lấy ảnh của bất động sản
          } catch (e) {
            removedImages = req.body.removedImages.split(',').map(s => s.trim()).filter(Boolean); // lấy ảnh của bất động sản
          }
        } else if (Array.isArray(req.body.removedImages)) {
          removedImages = req.body.removedImages; // lấy ảnh của bất động sản
        }
      } catch (e) {
        removedImages = [req.body.removedImages].filter(Boolean); // lấy ảnh của bất động sản
      }
      if (!Array.isArray(removedImages)) removedImages = [removedImages]; // lấy ảnh của bất động sản

      for (const image of removedImages) { // lấy ảnh của bất động sản
        if (typeof image !== 'string' || !image.startsWith('/uploads/')) continue; // lấy ảnh của bất động sản
        if (updatedImages.includes(image)) {
          updatedImages = updatedImages.filter(img => img !== image);
          const filePath = path.join(__dirname, '..', 'uploads', image.replace(/^\/uploads\//, ''));
          try {
            await fs.unlink(filePath);
          } catch (err) {
            // Nếu file không tồn tại thì bỏ qua, lỗi khác thì báo lỗi
            if (err.code !== 'ENOENT') {
              return res.status(500).json({ message: `Failed to delete image: ${image}`, error: err.message });
            }
          }
        }
      }
    }

    // Thêm ảnh mới
    if (req.files && req.files.length > 0) { // nếu có req.files và req.files.length > 0
      const newImages = req.files.map(file => `/uploads/${file.filename}`); // lấy ảnh của bất động sản
      updatedImages = [...new Set([...updatedImages, ...newImages])]; // lấy ảnh của bất động sản của bài 
    }

    // Luôn cập nhật lại trường images
    updatedData.images = updatedImages; // cập nhật ảnh của bất động sản

    // Cập nhật rental
    const updatedRental = await Rental.findByIdAndUpdate( // cập nhật bất động sản
      req.params.id, // id của bất động sản theo từng bài viết 
      { $set: updatedData }, // dữ liệu cập nhật
      { new: true, runValidators: true } // cập nhật bất động sản
    );

    if (!updatedRental) {
      return res.status(404).json({ message: 'Rental not found after update' });
    }

    // Đồng bộ Elasticsearch
    syncRentalToElasticsearch(updatedRental);

    res.json(updatedRental);
  } catch (err) {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ message: `File upload error: ${err.message}` });
    }
    res.status(500).json({ message: 'Failed to update rental', error: err.message });
  }
});
// ----------------------------------------------------------------------------------
// Delete rental
router.delete('/rentals/:id', authMiddleware, async (req, res) => { // hàm xóa bất động sản
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) { // nếu id không hợp lệ
      return res.status(400).json({ message: 'Invalid rental ID' }); // trả về lỗi
    }

    const rental = await Rental.findById(req.params.id); // lấy bất động sản theo id
    if (!rental) { // nếu không tìm thấy bất động sản
      return res.status(404).json({ message: 'Rental not found' }); // trả về lỗi
    }
    if (rental.userId !== req.userId) { // nếu id của người dùng không trùng với id của bất động sản
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' }); // trả về lỗi
    }

    for (const image of rental.images) { // lấy ảnh của bất động sản
      if (!image.startsWith('/uploads/')) { // nếu ảnh không bắt đầu bằng /uploads/
        console.warn(`Invalid image path format during deletion: ${image}`); // log lỗi
        continue; // bỏ qua
      }
      const filePath = path.join(__dirname, '..', 'Uploads', image.replace(/^\/uploads\//, '')); // lấy đường dẫn của ảnh
      try {
        await fs.access(filePath); // kiểm tra xem file có tồn tại không
        await fs.unlink(filePath); // xóa file
        console.log(`Deleted image: ${filePath}`); // log lỗi
      } catch (err) {
        console.error(`Error deleting image ${filePath}: ${err.message}`); // log lỗi
        if (err.code !== 'ENOENT') { // nếu lỗi không phải là ENOENT
          console.warn(`Non-ENOENT error during deletion: ${err.message}`); // log lỗi
        }
      }
    }

    await Comment.deleteMany({ rentalId: req.params.id }); // xóa bình luận theo id
    await Reply.deleteMany({ commentId: { $in: await Comment.find({ rentalId: req.params.id }).distinct('_id') } }); // xóa phản hồi theo id
    await LikeComment.deleteMany({ targetId: req.params.id, targetType: 'Comment' }); // xóa thích theo id
    await Favorite.deleteMany({ rentalId: req.params.id }); // xóa yêu thích theo id

    await Rental.findByIdAndDelete(req.params.id); // xóa bất động sản theo id

    try {
      await elasticClient.delete({ // xóa bất động sản theo id
        index: 'rentals', // index của bất động sản
        id: req.params.id, // id của bất động sản
        headers: { // headers của bất động sản
          Accept: 'application/json', // accept của bất động sản
          'Content-Type': 'application/json', // content type của bất động sản
        },
      });
      console.log(`Deleted rental ${req.params.id} from Elasticsearch`); // log lỗi
    } catch (esErr) {
      console.error('Error deleting from Elasticsearch:', esErr); // log lỗi
    }

    res.json({ message: 'Rental deleted successfully' }); // trả về kết quả
  } catch (err) {
    console.error('Error deleting rental:', err); // log lỗi
    res.status(500).json({ message: 'Failed to delete rental', error: err.message }); // trả về lỗi
  }
});

// Handle unsupported methods
router.all('/rentals/:id', (req, res) => {
  console.warn(`Received unsupported method ${req.method} for /rentals/:id`, {
    headers: req.headers,
    body: req.body,
  });
  res.status(405).json({
    message: `Method ${req.method} not allowed. Use PATCH to update rentals.`,
  });
});

module.exports = router;