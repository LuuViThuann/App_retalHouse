const express = require('express');
const router = express.Router();
const axios = require('axios');
const admin = require('firebase-admin');
const Rental = require('../models/Rental');
const ChatConversation = require('../models/ChatConversation');

const ML_SERVICE_URL = process.env.PYTHON_ML_URL || 'http://python-ml:8001';

const log = {
    info: (msg) => console.log(`✅ ${msg}`),
    warn: (msg) => console.warn(`⚠️  ${msg}`),
    error: (msg) => console.error(`❌ ${msg}`),
};

// Auth middleware
const authMiddleware = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'No authentication token'
            });
        }
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.userId = decodedToken.uid;
        req.user = decodedToken;
        next();
    } catch (err) {
        return res.status(401).json({
            success: false,
            message: 'Invalid token',
            error: err.message
        });
    }
};

/**
 * Rate limiting middleware (basic)
 */
const rateLimitMiddleware = (req, res, next) => {
    const key = `ratelimit:${req.userId}`;
    const limit = CHAT_CACHE.get(key) || 0;

    if (limit > 30) {
        return res.status(429).json({
            success: false,
            message: 'Too many requests. Please try again later.'
        });
    }

    CHAT_CACHE.set(key, limit + 1, 60); // Reset every 60 seconds
    next();
};

// ==================== HELPER FUNCTIONS ====================

/**
 * Get current time of day
 */
function getTimeOfDay() {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
}

/**
 * Get weekday name
 */
function getWeekday() {
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    return days[new Date().getDay()];
}

/**
 * Format currency
 */
function formatPrice(price) {
    if (price >= 1000000) {
        return `${(price / 1000000).toFixed(1)}M`;
    }
    return `${(price / 1000).toFixed(0)}K`;
}

/**
 * Generate explanation for chat
 */
function generateExplanationForChat(mlRec, rental, userPrefs) {
    const reasons = [];

    if (!mlRec) {
        return '✓ Bài này phù hợp với nhu cầu của bạn';
    }

    // 1. Confidence score
    const confidence = mlRec.confidence || 0.5;
    if (confidence >= 0.8) {
        reasons.push(`🎯 Độ phù hợp: ${Math.round(confidence * 100)}% - Rất hợp!`);
    } else if (confidence >= 0.6) {
        reasons.push(`✓ Độ phù hợp: ${Math.round(confidence * 100)}% - Khá hợp`);
    } else {
        reasons.push(`📌 Độ phù hợp: ${Math.round(confidence * 100)}%`);
    }

    // 2. Location distance
    if (mlRec.distance_km !== undefined && mlRec.distance_km !== null) {
        const dist = parseFloat(mlRec.distance_km);

        if (dist < 1) {
            reasons.push(`📍 Vị trí: Siêu gần (${(dist * 1000).toFixed(0)}m)`);
        } else if (dist < 5) {
            reasons.push(`📍 Vị trí: Gần (${dist.toFixed(1)}km từ khu vực yêu thích)`);
        } else if (dist < 20) {
            reasons.push(`📍 Vị trí: ${dist.toFixed(1)}km - Trong phạm vi tìm kiếm`);
        } else {
            reasons.push(`📍 Vị trí: ${dist.toFixed(1)}km`);
        }
    }

    // 3. Price matching
    if (userPrefs?.price_range && rental?.price) {
        const rentalPrice = parseFloat(rental.price);
        const avgPrice = userPrefs.price_range.avg || 0;

        if (avgPrice > 0) {
            const priceDiff = ((rentalPrice - avgPrice) / avgPrice * 100).toFixed(0);
            const displayPrice = formatPrice(rentalPrice);

            if (Math.abs(priceDiff) < 10) {
                reasons.push(`💰 Giá: ${displayPrice} - Chính xác mức bạn tìm`);
            } else if (priceDiff < -15) {
                reasons.push(`💰 Giá: ${displayPrice} - Rẻ hơn ${Math.abs(priceDiff)}%! 💥`);
            } else if (priceDiff > 0 && priceDiff < 20) {
                reasons.push(`💰 Giá: ${displayPrice} - Cao hơn nhưng chất lượng tốt`);
            } else {
                reasons.push(`💰 Giá: ${displayPrice}`);
            }
        } else {
            reasons.push(`💰 Giá: ${formatPrice(rentalPrice)}`);
        }
    }

    // 4. Property type matching
    if (userPrefs?.property_type_distribution && rental?.propertyType) {
        const typeDistribution = userPrefs.property_type_distribution;
        const rentalType = rental.propertyType;
        const viewCount = typeDistribution[rentalType];

        if (viewCount) {
            const total = Object.values(typeDistribution).reduce((a, b) => a + b, 0);
            const percentage = ((viewCount / total) * 100).toFixed(0);

            if (percentage >= 50) {
                reasons.push(`🏠 Loại: ${rentalType} - Loại yêu thích của bạn!`);
            } else {
                reasons.push(`🏠 Loại: ${rentalType}`);
            }
        }
    }

    // 5. Amenities
    if (rental?.amenities && Array.isArray(rental.amenities)) {
        const amenityCount = rental.amenities.length;

        if (amenityCount >= 8) {
            reasons.push(`✨ Tiện ích: ${amenityCount} tiện nghi - Đầy đủ!`);
        } else if (amenityCount >= 5) {
            reasons.push(`✨ Tiện ích: ${amenityCount} tiện nghi`);
        }
    }

    // 6. Area/Size
    if (rental?.area?.total) {
        const area = parseFloat(rental.area.total);
        if (userPrefs?.area_range?.avg) {
            const avgArea = userPrefs.area_range.avg;
            const areaDiff = ((area - avgArea) / avgArea * 100).toFixed(0);

            if (Math.abs(areaDiff) < 15) {
                reasons.push(`📐 Diện tích: ${area}m² - Phù hợp với nhu cầu`);
            } else if (areaDiff > 20) {
                reasons.push(`📐 Diện tích: ${area}m² - Rộng hơn, thoải mái hơn`);
            }
        } else {
            reasons.push(`📐 Diện tích: ${area}m²`);
        }
    }

    // 7. ML Method
    if (mlRec.method === 'collaborative_personalized') {
        reasons.push(`🤖 Phương pháp: Collaborative Filtering (dựa trên người dùng tương tự)`);
    } else if (mlRec.method === 'content_based_similar') {
        reasons.push(`🤖 Phương pháp: Content-Based (tương tự bài bạn đã xem)`);
    } else if (mlRec.method === 'popularity') {
        reasons.push(`⭐ Phương pháp: Phổ biến (nhiều người quan tâm)`);
    }

    return reasons.length > 0
        ? reasons.join('\n')
        : '✓ Bài này phù hợp với nhu cầu của bạn';
}

/**
 * Safely call ML service
 */
async function callMLService(endpoint, data, timeout = 10000) {
    try {
        log.debug(`Calling ML service: ${endpoint}`);

        const response = await axios.post(
            `${ML_SERVICE_URL}${endpoint}`,
            data,
            {
                timeout,
                headers: { 'Content-Type': 'application/json' }
            }
        );

        return {
            success: true,
            data: response.data,
            status: response.status
        };
    } catch (error) {
        log.warn(`ML Service error: ${error.message}`);

        return {
            success: false,
            error: error.message,
            status: error.response?.status || 500
        };
    }
}

/**
 * Get user preferences from ML model
 */
async function getUserPreferences(userId) {
    try {
        const result = await callMLService('/user-preferences/' + userId, {});

        if (result.success && result.data?.preferences) {
            return result.data.preferences;
        }

        return null;
    } catch (error) {
        log.error(`Error getting user preferences: ${error.message}`);
        return null;
    }
}

/**
 * Fetch rental details with selected fields
 */
async function getRentalDetails(rentalIds) {
    try {
        if (!Array.isArray(rentalIds) || rentalIds.length === 0) {
            return [];
        }

        const rentals = await Rental.find({
            _id: { $in: rentalIds },
            status: 'available'
        })
            .select(
                'title price propertyType area amenities furniture images ' +
                'location description bedrooms bathrooms views _id createdAt'
            )
            .lean()
            .exec();

        return rentals;
    } catch (error) {
        log.error(`Error fetching rental details: ${error.message}`);
        return [];
    }
}

/**
 * Enrich recommendations with rental data and explanations
 */
function enrichRecommendations(mlRecommendations, rentals) {
    return rentals
        .map(rental => {
            const mlRec = mlRecommendations.find(r => r.rentalId === rental._id.toString());
            if (!mlRec) return null;

            const coords = rental.location?.coordinates?.coordinates || [0, 0];

            return {
                _id: rental._id,
                title: rental.title,
                price: parseFloat(rental.price) || 0,
                propertyType: rental.propertyType || 'Unknown',
                area: rental.area,
                images: Array.isArray(rental.images) ? rental.images.slice(0, 3) : [],
                amenities: Array.isArray(rental.amenities) ? rental.amenities.slice(0, 6) : [],
                furniture: rental.furniture || [],
                location: {
                    short: rental.location?.short || 'Unknown',
                    full: rental.location?.fullAddress || rental.location?.short || 'Unknown',
                    coordinates: {
                        longitude: coords[0],
                        latitude: coords[1]
                    }
                },
                aiScore: mlRec.score || 0,
                confidence: mlRec.confidence || 0.5,
                finalScore: mlRec.finalScore || mlRec.score || 0,
                locationBonus: mlRec.locationBonus || 1.0,
                preferenceBonus: mlRec.preferenceBonus || 1.0,
                explanation: mlRec.explanation || '✓ Bài đăng phù hợp với bạn',
                distance_km: mlRec.distance_km || null,
                method: mlRec.method || 'ml_personalized',
                isAIRecommended: true,
                createdAt: rental.createdAt
            };
        })
        .filter(rec => rec !== null)
        .sort((a, b) => (b.finalScore || 0) - (a.finalScore || 0));
}
// ==================== ROUTES ====================

router.post('/chat', authMiddleware, async (req, res) => {
    const startTime = Date.now();
    const userId = req.userId;

    try {
        const {
            message,
            conversationHistory = [],
            userContext = null,
            includeRecommendations = true,
            conversationId = null
        } = req.body;

        if (!message || !message.trim()) {
            return res.status(400).json({
                success: false,
                message: 'Message is required'
            });
        }

        log.info(`[CHAT] User: ${userId}, Message: "${message.substring(0, 50)}..."`);

        // ===== STEP 1: CALL ML SERVICE =====
        const mlResult = await axios.post(
            `${ML_SERVICE_URL}/chat`,
            {
                userId,
                message: message.trim(),
                conversationHistory: conversationHistory || [],
                userContext: userContext || {},
                includeRecommendations
            },
            {
                timeout: 30000,
                headers: { 'Content-Type': 'application/json' }
            }
        ).catch(err => ({
            data: {
                success: false,
                message: 'Xin lỗi, tôi gặp chút vấn đề. Bạn có thể thử lại không?',
                intent: 'error',
                extracted_preferences: {},
                should_recommend: false,
                error: err.message
            }
        }));

        const chatData = mlResult.data;

        log.info(`[CHAT] AI Response: "${chatData.message?.substring(0, 50)}..."`);
        log.info(`[CHAT] Intent: ${chatData.intent}, Recommend: ${chatData.shouldRecommend}`);
        log.info(`[CHAT] Extracted Prefs: ${JSON.stringify(chatData.extractedPreferences || {})}`);

        // ===== STEP 2: GET RECOMMENDATIONS IF NEEDED =====
        let enrichedRecommendations = [];
        let explanationMessage = chatData.explanation;

        if (includeRecommendations && chatData.shouldRecommend) {

            // 🔥 Case 1: ML service returned recommendations
            if (chatData.recommendations && chatData.recommendations.length > 0) {
                log.info(`[CHAT] ML returned ${chatData.recommendations.length} recommendations`);

                const rentalIds = chatData.recommendations.map(r => r.rentalId);
                const rentals = await Rental.find({
                    _id: { $in: rentalIds },
                    status: 'available'
                })
                    .select('title price propertyType area amenities furniture images location createdAt')
                    .lean();

                enrichedRecommendations = enrichRecommendations(
                    chatData.recommendations,
                    rentals
                );

                log.info(`[CHAT] ✅ Enriched ${enrichedRecommendations.length} recommendations from ML`);
            }

            // 🔥 Case 2: No ML recommendations BUT has extracted preferences
            else if (chatData.extractedPreferences && Object.keys(chatData.extractedPreferences).length > 0) {
                log.info(`[CHAT] No ML recs, using MongoDB fallback with prefs...`);

                enrichedRecommendations = await getSmartFallbackRecommendations(
                    userId,
                    chatData.extractedPreferences
                );

                log.info(`[CHAT] ✅ Fallback returned ${enrichedRecommendations.length} rentals`);

                // Update explanation if fallback found results
                if (enrichedRecommendations.length > 0) {
                    explanationMessage = `Tôi tìm được ${enrichedRecommendations.length} bài đăng phù hợp! Xem chi tiết bên dưới nhé.`;
                }
            }

            // 🔥 Case 3: Still empty → DON'T override AI message (it should explain why no results)
            if (enrichedRecommendations.length === 0) {
                log.warn(`[CHAT] No recommendations found`);
                // AI message already says why (hallucination prevention handled in Python)
            }
        }

        // ===== STEP 3: SAVE CONVERSATION =====
        if (conversationId) {
            try {
                await ChatConversation.findByIdAndUpdate(
                    conversationId,
                    {
                        $push: {
                            messages: [
                                { role: 'user', content: message, timestamp: new Date() },
                                { role: 'assistant', content: chatData.message, timestamp: new Date() }
                            ]
                        },
                        $set: {
                            lastMessageAt: new Date(),
                            'conversationFlow.lastIntent': chatData.intent,
                            extractedPreferences: chatData.extractedPreferences || {}
                        }
                    },
                    { upsert: true }
                );
            } catch (dbError) {
                log.warn(`DB save error: ${dbError.message}`);
            }
        }

        // ===== STEP 4: RESPONSE =====
        const duration = Date.now() - startTime;

        return res.json({
            success: true,
            message: chatData.message,
            intent: chatData.intent,
            extractedPreferences: chatData.extractedPreferences || {},
            shouldRecommend: chatData.shouldRecommend || false,
            recommendations: enrichedRecommendations,
            recommendationCount: enrichedRecommendations.length,
            explanation: explanationMessage,
            usage: chatData.usage,
            conversationId,
            metadata: {
                responseTime: `${duration}ms`,
                isFromML: enrichedRecommendations.length > 0 && chatData.recommendations?.length > 0,
                hasFallback: enrichedRecommendations.length > 0 && !chatData.recommendations?.length,
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        log.error(`Exception in chat: ${error.message}`);
        return res.status(500).json({
            success: false,
            message: 'Failed to process chat',
            error: error.message
        });
    }
});
async function getSmartFallbackRecommendations(userId, extractedPreferences) {
    try {
        const query = { status: 'available' };
        let hasFilters = false;

        log.info(`[FALLBACK] Prefs: ${JSON.stringify(extractedPreferences)}`);

        // ===== PRICE FILTER - FLEXIBLE =====
        if (extractedPreferences.price_range) {
            const { min, max } = extractedPreferences.price_range;
            if (min || max) {
                query.price = {};
                if (min) {
                    query.price.$gte = min * 0.5; // -50%
                    hasFilters = true;
                }
                if (max) {
                    query.price.$lte = max * 1.5; // +50%
                    hasFilters = true;
                }
                log.info(`[FALLBACK] Price: ${query.price.$gte || 0} - ${query.price.$lte || 'unlimited'}`);
            }
        }

        // ===== PROPERTY TYPE FILTER - EXACT MAPPING =====
        if (extractedPreferences.property_type) {
            const type = extractedPreferences.property_type.toLowerCase();

            const typeMap = {
                'đất nền': /đất.*nền|land|dat.*nen/i,
                'phòng trọ': /phòng.*trọ|nhà.*trọ|boarding|room/i,
                'nhà trọ': /phòng.*trọ|nhà.*trọ|boarding|room/i,
                'căn hộ': /căn.*hộ|chung.*cư|apartment|condo/i,
                'chung cư': /căn.*hộ|chung.*cư|apartment|condo/i,
                'nhà riêng': /nhà.*riêng|nhà.*nguyên.*căn|house|villa/i,
                'biệt thự': /biệt.*thự|villa/i,
                'mặt bằng': /mặt.*bằng|văn.*phòng|office/i,
            };

            const regex = typeMap[type];
            if (regex) {
                query.propertyType = regex;
                hasFilters = true;
                log.info(`[FALLBACK] Type filter: ${type} → ${regex}`);
            }
        }

        // ===== LOCATION FILTER - FLEXIBLE =====
        if (extractedPreferences.location) {
            const location = extractedPreferences.location;
            const keywords = location.toLowerCase().split(/[\s,;.]+/).filter(k => k.length > 2);

            if (keywords.length > 0) {
                const locationQueries = [];
                keywords.forEach(keyword => {
                    const regex = new RegExp(keyword, 'i');
                    locationQueries.push(
                        { 'location.short': regex },
                        { 'location.fullAddress': regex },
                        { 'location.district': regex },
                        { 'location.city': regex },
                        { 'location.ward': regex }
                    );
                });

                if (locationQueries.length > 0) {
                    query.$or = locationQueries;
                    hasFilters = true;
                }
            }
        }

        // ===== EXECUTE QUERY =====
        log.info(`[FALLBACK] Query: ${JSON.stringify(query)}`);

        let rentals = await Rental.find(query)
            .sort({ createdAt: -1, views: -1 })
            .limit(10)
            .select('title price propertyType area amenities furniture images location createdAt')
            .lean();

        log.info(`[FALLBACK] Found ${rentals.length} rentals`);

        // ===== FALLBACK TO POPULAR IF EMPTY =====
        if (rentals.length === 0 && hasFilters) {
            log.warn(`[FALLBACK] No results, trying popular...`);
            rentals = await Rental.find({ status: 'available' })
                .sort({ views: -1 })
                .limit(5)
                .select('title price propertyType area amenities furniture images location createdAt')
                .lean();
        }

        // ===== TRANSFORM =====
        return rentals.map(rental => transformRentalToRecommendation(rental, hasFilters));

    } catch (error) {
        log.error(`Fallback error: ${error.message}`);
        return [];
    }
}
function transformRentalToRecommendation(rental, isFiltered) {
    return {
        _id: rental._id,
        title: rental.title,
        price: parseFloat(rental.price) || 0,
        propertyType: rental.propertyType || 'Unknown',
        area: {
            total: rental.area?.total || 0,
            bedrooms: rental.area?.bedrooms || 0,
            bathrooms: rental.area?.bathrooms || 0
        },
        images: Array.isArray(rental.images) ? rental.images.slice(0, 3) : [],
        amenities: Array.isArray(rental.amenities) ? rental.amenities.slice(0, 6) : [],
        furniture: rental.furniture || [],
        location: {
            short: rental.location?.short || 'Unknown',
            full: rental.location?.fullAddress || rental.location?.short || 'Unknown',
            coordinates: {
                longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
                latitude: rental.location?.coordinates?.coordinates?.[1] || 0
            }
        },
        aiScore: 0,
        confidence: isFiltered ? 0.5 : 0.3,
        finalScore: 0,
        explanation: isFiltered
            ? '📊 Bài đăng phù hợp với yêu cầu của bạn'
            : '⭐ Bài đăng phổ biến - nhiều người quan tâm',
        method: isFiltered ? 'mongodb_fallback' : 'popularity',
        distance_km: null,
        isAIRecommended: false,
        createdAt: rental.createdAt
    };
}
// ========== HELPER: FALLBACK RECOMMENDATIONS ==========
async function getFallbackRecommendations(userId, extractedPreferences) {
    try {
        const query = { status: 'available' };
        let hasFilters = false;

        log.info(`[FALLBACK] Input preferences:`, extractedPreferences);

        // ===== 1. PRICE FILTER - RELAXED =====
        if (extractedPreferences.price_range) {
            const { min, max } = extractedPreferences.price_range;
            if (min || max) {
                query.price = {};

                // Mở rộng 30% range để có nhiều kết quả hơn
                if (min) {
                    query.price.$gte = min * 0.7;
                    hasFilters = true;
                }
                if (max) {
                    query.price.$lte = max * 1.3;
                    hasFilters = true;
                }

                log.info(`[FALLBACK] Price filter: ${query.price.$gte || 0} - ${query.price.$lte || 'unlimited'}`);
            }
        }

        // ===== 2. PROPERTY TYPE FILTER - FLEXIBLE MAPPING =====
        if (extractedPreferences.property_type) {
            const type = extractedPreferences.property_type.toLowerCase();

            // Map với CSV data CHÍNH XÁC
            const typeMap = {
                'phòng trọ': ['Nhà trọ/Phòng trọ', 'phòng trọ', 'nhà trọ'],
                'nhà trọ': ['Nhà trọ/Phòng trọ', 'phòng trọ', 'nhà trọ'],
                'trọ': ['Nhà trọ/Phòng trọ', 'phòng trọ', 'nhà trọ'],

                'căn hộ': ['Căn hộ chung cư', 'căn hộ', 'chung cư'],
                'chung cư': ['Căn hộ chung cư', 'căn hộ', 'chung cư'],
                'apartment': ['Căn hộ chung cư'],

                'nhà': ['Nhà riêng', 'nhà nguyên căn', 'nhà phố'],
                'nhà riêng': ['Nhà riêng', 'nhà nguyên căn', 'nhà phố'],
                'nhà nguyên căn': ['Nhà riêng', 'nhà nguyên căn'],

                'biệt thự': ['Biệt thự', 'nhà riêng'],
                'villa': ['Biệt thự'],

                'đất': ['Đất nền'],
                'đất nền': ['Đất nền'],

                'văn phòng': ['Văn phòng'],
                'office': ['Văn phòng']
            };

            // Tìm match types
            let matchTypes = [];
            for (const [key, values] of Object.entries(typeMap)) {
                if (type.includes(key) || key.includes(type)) {
                    matchTypes = values;
                    log.info(`[FALLBACK] Property type matched: ${key} → ${values.join(', ')}`);
                    break;
                }
            }

            // Fallback: nếu không match → search với regex
            if (matchTypes.length === 0) {
                log.warn(`[FALLBACK] No exact match for "${type}", using flexible search`);
                query.propertyType = { $regex: type, $options: 'i' };
            } else {
                query.propertyType = { $in: matchTypes };
            }

            hasFilters = true;
        }

        // ===== 3. LOCATION FILTER - VERY FLEXIBLE =====
        if (extractedPreferences.location) {
            const location = extractedPreferences.location;

            // Tách keywords (split by space, comma, etc)
            const keywords = location
                .toLowerCase()
                .split(/[\s,;.]+/)
                .filter(k => k.length > 2); // Bỏ qua từ quá ngắn

            log.info(`[FALLBACK] Location keywords:`, keywords);

            // Build OR query cho mỗi keyword
            const locationQueries = [];

            keywords.forEach(keyword => {
                locationQueries.push(
                    // Search trong tất cả các trường location
                    { 'location.short': { $regex: keyword, $options: 'i' } },
                    { 'location.fullAddress': { $regex: keyword, $options: 'i' } },
                    { 'location.district': { $regex: keyword, $options: 'i' } },
                    { 'location.city': { $regex: keyword, $options: 'i' } },
                    { 'location.ward': { $regex: keyword, $options: 'i' } },
                    { 'location.street': { $regex: keyword, $options: 'i' } }
                );
            });

            if (locationQueries.length > 0) {
                query.$or = locationQueries;
                hasFilters = true;
            }
        }

        // ===== 4. AREA FILTER (if exists) =====
        if (extractedPreferences.area_range) {
            const { min, max } = extractedPreferences.area_range;
            if (min || max) {
                query['area.total'] = {};
                if (min) query['area.total'].$gte = min * 0.8;
                if (max) query['area.total'].$lte = max * 1.2;
                hasFilters = true;
            }
        }

        log.info(`[FALLBACK] Final MongoDB query:`, JSON.stringify(query, null, 2));

        // ===== 5. EXECUTE QUERY =====
        let rentals = await Rental.find(query)
            .sort({ createdAt: -1, views: -1 })
            .limit(10)
            .select('title price propertyType area amenities furniture images location createdAt')
            .lean();

        log.info(`[FALLBACK] Found ${rentals.length} rentals with filters`);

        // ===== 6. FALLBACK TO NO FILTERS =====
        if (rentals.length === 0 && hasFilters) {
            log.warn(`[FALLBACK] No results with filters, trying without filters...`);

            rentals = await Rental.find({ status: 'available' })
                .sort({ views: -1, createdAt: -1 })
                .limit(5)
                .select('title price propertyType area amenities furniture images location createdAt')
                .lean();

            log.info(`[FALLBACK] Found ${rentals.length} popular rentals`);
        }

        // ===== 7. TRANSFORM TO RESPONSE FORMAT =====
        return rentals.map(rental => ({
            _id: rental._id,
            title: rental.title,
            price: parseFloat(rental.price) || 0,
            propertyType: rental.propertyType || 'Unknown',

            area: {
                total: rental.area?.total || 0,
                bedrooms: rental.area?.bedrooms || 0,
                bathrooms: rental.area?.bathrooms || 0
            },

            images: Array.isArray(rental.images) ? rental.images.slice(0, 3) : [],
            amenities: Array.isArray(rental.amenities) ? rental.amenities.slice(0, 6) : [],
            furniture: rental.furniture || [],

            location: {
                short: rental.location?.short || 'Unknown',
                full: rental.location?.fullAddress || rental.location?.short || 'Unknown',
                coordinates: {
                    longitude: rental.location?.coordinates?.coordinates?.[0] || 0,
                    latitude: rental.location?.coordinates?.coordinates?.[1] || 0
                }
            },

            // Scores
            aiScore: 0,
            confidence: hasFilters ? 0.5 : 0.3,
            finalScore: 0,

            // Explanation
            explanation: hasFilters
                ? '📊 Bài đăng phù hợp với yêu cầu của bạn (tìm kiếm linh hoạt)'
                : '⭐ Bài đăng phổ biến - nhiều người quan tâm',

            method: hasFilters ? 'mongodb_fallback' : 'popularity',
            distance_km: null,
            isAIRecommended: false,
            createdAt: rental.createdAt
        }));

    } catch (error) {
        log.error(`Error in fallback recommendations: ${error.message}`);
        log.error(error.stack);
        return [];
    }
}

/**
 * POST /api/ai/chat/recommendations-with-details
 * Get recommendations with full details from ML model + MongoDB
 */
router.post('/chat/recommendations-with-details', authMiddleware, rateLimitMiddleware, async (req, res) => {
    const startTime = Date.now();
    const userId = req.userId;

    try {
        const {
            n_recommendations = 5,
            userPreferences: userPrefsParam = null,
            radius_km = 20,
            useLocation = true,
            context = null
        } = req.body;

        log.info(`[RECOMMENDATIONS] User: ${userId}, Count: ${n_recommendations}`);

        // Call ML service
        const mlResult = await callMLService('/recommend/personalized', {
            userId,
            user_id: userId,
            n_recommendations: Math.min(n_recommendations * 2, 50), // Get extra for fallback
            use_location: useLocation,
            radius_km: parseInt(radius_km) || 20,
            context: context || {
                device_type: 'mobile',
                time_of_day: getTimeOfDay(),
                weekday: getWeekday(),
                scroll_depth: 0.5
            }
        });

        if (!mlResult.success) {
            log.warn(`ML service failed for recommendations: ${mlResult.error}`);

            // Fallback to popularity
            const popularRentals = await Rental.find({ status: 'available' })
                .sort({ views: -1, createdAt: -1 })
                .limit(n_recommendations)
                .select('title price propertyType area amenities images location')
                .lean();

            const fallbackRecs = popularRentals.map((r, idx) => ({
                _id: r._id,
                title: r.title,
                price: r.price,
                propertyType: r.propertyType,
                area: r.area,
                images: r.images?.slice(0, 3) || [],
                amenities: r.amenities?.slice(0, 6) || [],
                location: {
                    short: r.location?.short || 'Unknown',
                    full: r.location?.fullAddress || r.location?.short || 'Unknown',
                    coordinates: {
                        longitude: r.location?.coordinates?.coordinates?.[0] || 0,
                        latitude: r.location?.coordinates?.coordinates?.[1] || 0
                    }
                },
                aiScore: 0,
                confidence: 0.3,
                finalScore: 0,
                explanation: '⭐ Bài đăng phổ biến (nhiều người quan tâm)',
                method: 'popularity',
                distance_km: null,
                isFromML: false
            }));

            return res.json({
                success: true,
                recommendations: fallbackRecs,
                total: fallbackRecs.length,
                isFromML: false,
                message: '📊 Hiển thị bài đăng phổ biến (ML service tạm thời không khả dụng)'
            });
        }

        const mlRecommendations = mlResult.data.recommendations || [];

        if (mlRecommendations.length === 0) {
            return res.json({
                success: true,
                recommendations: [],
                total: 0,
                isFromML: true,
                message: 'Chưa tìm thấy bài đăng phù hợp'
            });
        }

        log.info(`[RECOMMENDATIONS] Got ${mlRecommendations.length} from ML service`);

        // Fetch rental details
        const rentalIds = mlRecommendations.map(r => r.rentalId);
        const rentals = await getRentalDetails(rentalIds);

        log.info(`[RECOMMENDATIONS] Fetched ${rentals.length} rental details`);

        // Get user preferences
        const userPrefs = userPrefsParam || (await getUserPreferences(userId));

        // Enrich recommendations
        const enrichedRecs = enrichRecommendations(
            mlRecommendations,
            rentals,
            userPrefs
        );

        const finalRecs = enrichedRecs.slice(0, n_recommendations);

        const duration = Date.now() - startTime;

        return res.json({
            success: true,
            recommendations: finalRecs,
            total: finalRecs.length,
            isFromML: true,
            userPreferences: userPrefs ? {
                priceRange: userPrefs.price_range,
                propertyTypeDistribution: userPrefs.property_type_distribution,
                topLocations: userPrefs.top_locations,
                totalInteractions: userPrefs.total_interactions
            } : null,
            metadata: {
                responseTime: `${duration}ms`,
                timestamp: new Date().toISOString(),
                mlStatus: 'success'
            }
        });

    } catch (error) {
        log.error(`Exception in recommendations: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get recommendations',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/explain-rental
 * Get detailed explanation for a specific rental
 */
router.post('/chat/explain-rental', authMiddleware, rateLimitMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { rentalId, conversationContext = '' } = req.body;

        if (!rentalId) {
            return res.status(400).json({
                success: false,
                message: 'rentalId is required'
            });
        }

        log.info(`[EXPLAIN] Rental: ${rentalId}, User: ${userId}`);

        // Call ML service
        const mlResult = await callMLService('/recommend/explain', null, 10000, {
            params: { userId, rentalId }
        });

        // Note: This is a workaround since axios POST with params doesn't work well
        // Better to use axios.get or adjust the ML service
        const mlExplain = await axios.post(
            `${ML_SERVICE_URL}/recommend/explain`,
            {},
            {
                params: { userId, rentalId },
                timeout: 10000
            }
        ).catch(err => ({
            data: { success: false, error: err.message }
        }));

        if (!mlExplain.data.success) {
            log.warn(`ML explain failed: ${mlExplain.data.error}`);

            // Fallback explanation
            const rental = await Rental.findById(rentalId).lean();

            if (!rental) {
                return res.status(404).json({
                    success: false,
                    message: 'Rental not found'
                });
            }

            return res.json({
                success: true,
                rental: {
                    id: rental._id,
                    title: rental.title,
                    price: rental.price,
                    propertyType: rental.propertyType
                },
                explanation: `${rental.propertyType} này có giá ${formatPrice(rental.price)}/tháng, ` +
                    `diện tích ${rental.area?.total || 'N/A'}m². ` +
                    `Đây là một lựa chọn phù hợp trong khu vực bạn đang tìm kiếm! 🏠`,
                fallback: true
            });
        }

        // Get rental data
        const rental = await Rental.findById(rentalId).lean();

        if (!rental) {
            return res.status(404).json({
                success: false,
                message: 'Rental not found'
            });
        }

        log.info(`[EXPLAIN] Explanation generated for ${rentalId}`);

        return res.json({
            success: true,
            rental: {
                id: rental._id,
                title: rental.title,
                price: rental.price,
                propertyType: rental.propertyType,
                location: rental.location?.short,
                images: rental.images?.slice(0, 3)
            },
            explanation: mlExplain.data.explanation,
            scores: mlExplain.data.explanation?.scores,
            reasons: mlExplain.data.explanation?.reasons,
            insights: mlExplain.data.explanation?.insights,
            userPreferences: mlExplain.data.explanation?.user_context
        });

    } catch (error) {
        log.error(`Exception in explain: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get explanation',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/suggestions/:userId
 * Get suggested questions for the user
 */
router.get('/chat/suggestions/:userId', authMiddleware, async (req, res) => {
    try {
        const { userId } = req.params;

        // Authorization check
        if (req.userId !== userId && !req.user?.admin) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized'
            });
        }

        log.info(`[SUGGESTIONS] User: ${userId}`);

        // Call ML service
        const mlResult = await callMLService(`/chat/conversation/${userId}`, {}, 5000);

        if (mlResult.success && mlResult.data?.suggestions) {
            return res.json({
                success: true,
                userId,
                suggestions: mlResult.data.suggestions,
                userPreferences: mlResult.data.userPreferences
            });
        }

        // Fallback suggestions
        const fallbackSuggestions = [
            '🏠 Bạn muốn thuê nhà ở khu vực nào?',
            '💰 Tầm giá bao nhiêu là phù hợp?',
            '🛏️ Bạn cần bao nhiêu phòng ngủ?',
            '✨ Có tiện ích nào quan trọng với bạn không?',
            '📐 Diện tích cần bao nhiêu m²?'
        ];

        return res.json({
            success: true,
            userId,
            suggestions: fallbackSuggestions,
            fallback: true
        });

    } catch (error) {
        log.error(`Exception in suggestions: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get suggestions',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/conversation/start
 * Start a new conversation
 */
router.post('/chat/conversation/start', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { initialContext = null } = req.body;

        log.info(`[START CONV] User: ${userId}`);

        // Create conversation
        const conversation = await ChatConversation.create({
            userId,
            messages: [],
            extractedPreferences: {},
            userContext: initialContext,
            status: 'active',
            startedAt: new Date(),
            lastMessageAt: new Date()
        });

        log.info(`[START CONV] Created: ${conversation._id}`);

        // Get initial greeting
        try {
            const mlResult = await callMLService('/chat', {
                userId,
                message: 'Xin chào',
                conversationHistory: [],
                includeRecommendations: false
            }, 10000);

            const greeting = mlResult.success
                ? mlResult.data.message
                : 'Xin chào! Tôi là trợ lý AI về bất động sản. Tôi có thể giúp bạn tìm nhà phù hợp! 🏠';

            // Save greeting
            if (mlResult.success) {
                await ChatConversation.findByIdAndUpdate(conversation._id, {
                    $push: {
                        messages: {
                            role: 'assistant',
                            content: greeting,
                            timestamp: new Date()
                        }
                    }
                });
            }

            return res.json({
                success: true,
                conversationId: conversation._id,
                greeting,
                userContext: initialContext,
                timestamp: new Date().toISOString()
            });

        } catch (mlError) {
            log.warn(`ML greeting failed: ${mlError.message}`);

            const fallbackGreeting = '👋 Xin chào! Tôi là trợ lý AI của RentHouse. ' +
                'Tôi có thể giúp bạn tìm nhà trọ/căn hộ phù hợp. ' +
                'Bạn đang tìm kiếm gì nhé?';

            return res.json({
                success: true,
                conversationId: conversation._id,
                greeting: fallbackGreeting,
                fallback: true
            });
        }

    } catch (error) {
        log.error(`Exception in start conversation: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to start conversation',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/conversation/:conversationId
 * Get conversation history
 */
router.get('/chat/conversation/:conversationId', authMiddleware, async (req, res) => {
    try {
        const { conversationId } = req.params;
        const userId = req.userId;

        log.info(`[GET CONV] ID: ${conversationId}, User: ${userId}`);

        const conversation = await ChatConversation.findOne({
            _id: conversationId,
            userId
        }).lean();

        if (!conversation) {
            return res.status(404).json({
                success: false,
                message: 'Conversation not found'
            });
        }

        return res.json({
            success: true,
            conversation: {
                _id: conversation._id,
                userId: conversation.userId,
                messages: conversation.messages || [],
                extractedPreferences: conversation.extractedPreferences,
                status: conversation.status,
                startedAt: conversation.startedAt,
                lastMessageAt: conversation.lastMessageAt,
                totalMessages: conversation.totalMessages || 0,
                totalRecommendations: conversation.totalRecommendations || 0,
                mlRecommendations: conversation.mlRecommendations?.slice(-5) || []
            }
        });

    } catch (error) {
        log.error(`Exception in get conversation: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get conversation',
            error: error.message
        });
    }
});

/**
 * DELETE /api/ai/chat/conversation/:conversationId
 * End/delete conversation
 */
router.delete('/chat/conversation/:conversationId', authMiddleware, async (req, res) => {
    try {
        const { conversationId } = req.params;
        const userId = req.userId;

        log.info(`[DELETE CONV] ID: ${conversationId}, User: ${userId}`);

        const result = await ChatConversation.findOneAndUpdate(
            { _id: conversationId, userId },
            {
                status: 'completed',
                completedAt: new Date()
            },
            { new: true }
        );

        if (!result) {
            return res.status(404).json({
                success: false,
                message: 'Conversation not found'
            });
        }

        return res.json({
            success: true,
            message: 'Conversation ended',
            conversation: result
        });

    } catch (error) {
        log.error(`Exception in delete conversation: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to end conversation',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/user-preferences/:userId
 * Get user preferences from ML model
 */
router.get('/user-preferences/:userId', authMiddleware, async (req, res) => {
    try {
        const { userId } = req.params;

        if (req.userId !== userId && !req.user?.admin) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized'
            });
        }

        log.info(`[USER PREFS] User: ${userId}`);

        const prefs = await getUserPreferences(userId);

        if (!prefs) {
            return res.json({
                success: false,
                message: 'No preferences found for this user',
                userId
            });
        }

        return res.json({
            success: true,
            userId,
            preferences: {
                propertyTypeDistribution: prefs.property_type_distribution,
                priceRange: prefs.price_range,
                areaRange: prefs.area_range,
                topLocations: prefs.top_locations,
                interactionTypes: prefs.interaction_types,
                totalInteractions: prefs.total_interactions,
                avgSearchRadius: prefs.avg_search_radius || 0
            },
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        log.error(`Exception in user preferences: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get user preferences',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/stats
 * Get chat service stats for user
 */
router.get('/chat/stats', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;

        // Get user's conversation stats
        const conversations = await ChatConversation.find({ userId }).lean();

        const stats = {
            totalConversations: conversations.length,
            activeConversations: conversations.filter(c => c.status === 'active').length,
            completedConversations: conversations.filter(c => c.status === 'completed').length,
            totalMessages: conversations.reduce((sum, c) => sum + (c.totalMessages || 0), 0),
            totalRecommendations: conversations.reduce((sum, c) => sum + (c.totalRecommendations || 0), 0),
            avgMessagesPerConversation: conversations.length > 0
                ? (conversations.reduce((sum, c) => sum + (c.totalMessages || 0), 0) / conversations.length).toFixed(2)
                : 0
        };

        return res.json({
            success: true,
            userId,
            stats,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        log.error(`Exception in chat stats: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get stats',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/feedback
 * Log user feedback on recommendations
 */
router.post('/chat/feedback', authMiddleware, rateLimitMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { rentalId, conversationId, action, rating, feedback } = req.body;

        if (!rentalId || !action) {
            return res.status(400).json({
                success: false,
                message: 'rentalId and action are required'
            });
        }

        log.info(`[FEEDBACK] User: ${userId}, Rental: ${rentalId}, Action: ${action}`);

        // Update conversation if conversationId provided
        if (conversationId) {
            await ChatConversation.findByIdAndUpdate(
                conversationId,
                {
                    $set: {
                        'mlRecommendations.$[elem].userAction': action,
                        'mlRecommendations.$[elem].actionAt': new Date()
                    }
                },
                {
                    arrayFilters: [{ 'elem.rentalId': rentalId }]
                }
            );
        }

        return res.json({
            success: true,
            message: 'Feedback recorded',
            metadata: {
                action,
                rating,
                feedback,
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        log.error(`Exception in feedback: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to record feedback',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/search-with-ai
 * Advanced search with AI interpretation
 */
router.post('/chat/search-with-ai', authMiddleware, rateLimitMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const {
            query,
            filters = {},
            context = null
        } = req.body;

        if (!query || query.trim().length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Search query is required'
            });
        }

        log.info(`[AI SEARCH] User: ${userId}, Query: "${query}"`);

        // Use chat endpoint to understand the query
        const mlResult = await callMLService('/chat', {
            userId,
            message: query,
            conversationHistory: [],
            includeRecommendations: true
        });

        if (!mlResult.success) {
            return res.status(503).json({
                success: false,
                message: 'AI search service unavailable'
            });
        }

        const chatResponse = mlResult.data;
        const preferences = chatResponse.extractedPreferences || {};

        // Build MongoDB query
        let dbQuery = { status: 'available' };

        // Price filter
        if (preferences.price_range?.min && preferences.price_range?.max) {
            dbQuery.price = {
                $gte: preferences.price_range.min,
                $lte: preferences.price_range.max
            };
        } else if (filters.minPrice || filters.maxPrice) {
            dbQuery.price = {};
            if (filters.minPrice) dbQuery.price.$gte = filters.minPrice;
            if (filters.maxPrice) dbQuery.price.$lte = filters.maxPrice;
        }

        // Property type filter
        if (preferences.property_type) {
            dbQuery.propertyType = preferences.property_type;
        } else if (filters.propertyType) {
            dbQuery.propertyType = filters.propertyType;
        }

        // Location filter
        if (preferences.location) {
            dbQuery['location.short'] = { $regex: preferences.location, $options: 'i' };
        } else if (filters.location) {
            dbQuery['location.short'] = { $regex: filters.location, $options: 'i' };
        }

        // Area filter
        if (filters.minArea || filters.maxArea) {
            dbQuery['area.total'] = {};
            if (filters.minArea) dbQuery['area.total'].$gte = filters.minArea;
            if (filters.maxArea) dbQuery['area.total'].$lte = filters.maxArea;
        }

        log.debug(`[AI SEARCH] Built query: ${JSON.stringify(dbQuery)}`);

        // Execute search
        const rentals = await Rental.find(dbQuery)
            .limit(20)
            .lean();

        log.info(`[AI SEARCH] Found ${rentals.length} rentals`);

        return res.json({
            success: true,
            query,
            extractedPreferences: preferences,
            rentals: rentals.map(r => ({
                _id: r._id,
                title: r.title,
                price: r.price,
                propertyType: r.propertyType,
                location: r.location?.short,
                area: r.area?.total,
                images: r.images?.slice(0, 1),
                amenities: r.amenities?.slice(0, 3)
            })),
            total: rentals.length,
            aiInterpretation: chatResponse.message,
            metadata: {
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        log.error(`Exception in AI search: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'AI search failed',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/compare-rentals
 * Compare multiple rentals using AI
 */
router.post('/chat/compare-rentals', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { rentalIds } = req.body;

        if (!Array.isArray(rentalIds) || rentalIds.length < 2) {
            return res.status(400).json({
                success: false,
                message: 'At least 2 rental IDs are required'
            });
        }

        log.info(`[COMPARE] User: ${userId}, Rentals: ${rentalIds.length}`);

        // Fetch rentals
        const rentals = await Rental.find({
            _id: { $in: rentalIds },
            status: 'available'
        })
            .select('title price propertyType area amenities location images')
            .lean();

        if (rentals.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Rentals not found'
            });
        }

        // Get user preferences
        const userPrefs = await getUserPreferences(userId);

        // Create comparison data
        const comparison = rentals.map(r => ({
            id: r._id,
            title: r.title,
            price: r.price,
            priceDisplay: formatPrice(r.price),
            propertyType: r.propertyType,
            area: r.area?.total,
            amenities: r.amenities?.length || 0,
            location: r.location?.short,
            pricePerSqm: r.area?.total ? (r.price / r.area.total).toFixed(0) : 0,
            amenitiesList: r.amenities?.slice(0, 5) || []
        }));

        // Call AI to generate comparison
        const comparisonPrompt = `
So sánh các bài đăng cho tôi:
${comparison.map((c, idx) => `
${idx + 1}. ${c.title}
   - Giá: ${c.priceDisplay}
   - Loại: ${c.propertyType}
   - Diện tích: ${c.area}m²
   - Tiện ích: ${c.amenities}
   - Giá/m²: ${c.pricePerSqm}K
`).join('\n')}

${userPrefs ? `Preferences của tôi:
- Giá trung bình: ${formatPrice(userPrefs.price_range?.avg || 0)}
- Loại yêu thích: ${Object.entries(userPrefs.property_type_distribution || {})
                    .sort((a, b) => b[1] - a[1])[0]?.[0] || 'Không xác định'}
- Diện tích trung bình: ${userPrefs.area_range?.avg || 0}m²` : '- Chưa có'}

Hãy đưa ra lời khuyên chi tiết.
    `.trim();

        // Call AI
        const aiResult = await callMLService('/chat', {
            userId,
            message: comparisonPrompt,
            conversationHistory: [],
            includeRecommendations: false
        });

        const recommendation = aiResult.success
            ? aiResult.data.message
            : 'Không thể tạo so sánh tự động. Vui lòng xem chi tiết từng bài đăng.';

        log.info(`[COMPARE] Comparison generated`);

        return res.json({
            success: true,
            rentals: comparison,
            recommendation,
            userPreferences: userPrefs ? {
                priceRange: userPrefs.price_range,
                propertyType: Object.entries(userPrefs.property_type_distribution || {})
                    .sort((a, b) => b[1] - a[1])[0]?.[0]
            } : null,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        log.error(`Exception in compare rentals: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to compare rentals',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/conversation-list/:userId
 * Get list of conversations for user
 */
router.get('/conversation-list/:userId', authMiddleware, async (req, res) => {
    try {
        const { userId } = req.params;
        const { limit = 10, skip = 0, status = null } = req.query;

        if (req.userId !== userId && !req.user?.admin) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized'
            });
        }

        log.info(`[CONV LIST] User: ${userId}, Status: ${status}`);

        // Build query
        let query = { userId };
        if (status) {
            query.status = status;
        }

        // Get conversations
        const conversations = await ChatConversation.find(query)
            .sort({ lastMessageAt: -1 })
            .limit(parseInt(limit))
            .skip(parseInt(skip))
            .select('_id messages extractedPreferences status startedAt lastMessageAt totalMessages totalRecommendations')
            .lean();

        // Get total count
        const total = await ChatConversation.countDocuments(query);

        // Format response
        const formattedConversations = conversations.map(c => ({
            _id: c._id,
            lastMessage: c.messages?.[c.messages.length - 1],
            status: c.status,
            messageCount: c.totalMessages || 0,
            recommendationCount: c.totalRecommendations || 0,
            extractedPreferences: c.extractedPreferences,
            startedAt: c.startedAt,
            lastMessageAt: c.lastMessageAt,
            preview: c.messages?.[c.messages.length - 1]?.content?.substring(0, 100) + '...' || 'Trống'
        }));

        return res.json({
            success: true,
            conversations: formattedConversations,
            total,
            limit: parseInt(limit),
            skip: parseInt(skip),
            hasMore: parseInt(skip) + parseInt(limit) < total
        });

    } catch (error) {
        log.error(`Exception in conversation list: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to get conversations',
            error: error.message
        });
    }
});

/**
 * POST /api/ai/chat/rating
 * Rate a recommendation or conversation
 */
router.post('/chat/rating', authMiddleware, rateLimitMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const {
            conversationId,
            rentalId,
            rating,
            comment = ''
        } = req.body;

        if (!rating || rating < 1 || rating > 5) {
            return res.status(400).json({
                success: false,
                message: 'Rating must be between 1 and 5'
            });
        }

        log.info(`[RATING] User: ${userId}, Rating: ${rating} stars`);

        // Update recommendation rating
        if (conversationId && rentalId) {
            await ChatConversation.findByIdAndUpdate(
                conversationId,
                {
                    $set: {
                        'mlRecommendations.$[elem].userRating': rating,
                        'mlRecommendations.$[elem].userComment': comment,
                        'mlRecommendations.$[elem].ratedAt': new Date()
                    }
                },
                {
                    arrayFilters: [{ 'elem.rentalId': rentalId }]
                }
            );
        }

        return res.json({
            success: true,
            message: 'Rating saved',
            metadata: {
                rating,
                comment: comment.substring(0, 200),
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        log.error(`Exception in rating: ${error.message}`);

        return res.status(500).json({
            success: false,
            message: 'Failed to save rating',
            error: error.message
        });
    }
});

/**
 * GET /api/ai/chat/health
 * Health check endpoint
 */
router.get('/health', async (req, res) => {
    try {
        const mlHealth = await axios.get(`${ML_SERVICE_URL}/health`, { timeout: 5000 })
            .then(() => true).catch(() => false);

        return res.json({
            success: true,
            status: 'healthy',
            services: {
                api: 'up',
                ml_service: mlHealth ? 'up' : 'down'
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        return res.status(503).json({
            success: false,
            status: 'unhealthy',
            error: error.message
        });
    }
});
// ==================== ERROR HANDLING ====================

/**
 * 404 handler
 */
router.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Route not found',
        path: req.path,
        method: req.method
    });
});

/**
 * Global error handler middleware
 */
router.use((error, req, res, next) => {
    log.error(`Unhandled error: ${error.message}`);

    res.status(error.statusCode || 500).json({
        success: false,
        message: error.message || 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.stack : undefined,
        timestamp: new Date().toISOString()
    });
});

// ==================== EXPORTS ====================

module.exports = router;