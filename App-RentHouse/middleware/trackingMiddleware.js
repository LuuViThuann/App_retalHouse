const UserInteraction = require('../models/UserInteraction');
const Rental = require('../models/Rental');

/**
 * Detect device type from user agent
 */
const detectDeviceType = (userAgent) => {
  if (!userAgent) return 'unknown';
  
  const ua = userAgent.toLowerCase();
  if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
    return 'tablet';
  }
  if (/Mobile|iP(hone|od)|Android|BlackBerry|IEMobile|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
    return 'mobile';
  }
  return 'desktop';
};
/**
 * Helper: Xác định time of day
 */
function _getTimeOfDay() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}
/**
 * Track rental view automatically - 🔥 CẬP NHẬT lưu coordinates
 */
const trackRentalView = async (req, res, next) => {
  const originalJson = res.json;
  
  res.json = function(data) {
    originalJson.call(this, data);
    
    setImmediate(async () => {
      try {
        const userId = req.userId || req.headers['x-user-id'] || 'anonymous';
        const rentalId = req.params.id;
        
        if (!rentalId) return;
        
        const rental = await Rental.findById(rentalId).lean();
        if (!rental) return;
        
        const coordinates = rental.location?.coordinates?.coordinates || [0, 0];

        // 🔥 EXTRACT CONTEXT DATA
        const contextData = {
          mapCenter: req.body?.mapCenter ? {
            longitude: req.body.mapCenter.longitude,
            latitude: req.body.mapCenter.latitude
          } : null,
          zoomLevel: req.body?.zoomLevel,
          searchRadius: req.body?.searchRadius ? parseInt(req.body.searchRadius) : 10,
          timeOfDay: _getTimeOfDay(),
          weekday: new Date().toLocaleDateString('en-US', { weekday: 'long' }),
          hourOfDay: new Date().getHours(),
          deviceType: detectDeviceType(req.headers['user-agent']),
          scrollDepth: parseInt(req.body?.scrollDepth) || 0,
          markerClicked: req.body?.markerClicked === 'true',
          markerSize: req.body?.markerSize ? parseInt(req.body.markerSize) : null,
          markerPriority: req.body?.markerPriority ? parseInt(req.body.markerPriority) : null,
          impressionCount: req.body?.impressionCount ? parseInt(req.body.impressionCount) : null,
          impressionPosition: req.body?.impressionPosition ? parseInt(req.body.impressionPosition) : null,
          fromRecommendation: req.query.recommended === 'true',
          recommendationType: req.query.recType,
          recommendationScore: req.body?.recommendationScore ? parseFloat(req.body.recommendationScore) : null,
          recommendationConfidence: req.body?.recommendationConfidence ? parseFloat(req.body.recommendationConfidence) : null,
          isTopRecommendation: req.body?.isTopRecommendation === 'true',
          searchQuery: req.query.search || req.query.q,
          filterApplied: req.body?.filterApplied || null
        };

        // 🔥 EXTRACT MARKER ANALYTICS
        const markerAnalytics = {
          markerSize: req.body?.markerSize ? parseInt(req.body.markerSize) : null,
          markerOpacity: req.body?.markerOpacity ? parseFloat(req.body.markerOpacity) : null,
          markerColor: req.body?.markerColor,
          markerLabel: req.body?.markerLabel,
          wasHighlighted: req.body?.wasHighlighted === 'true',
          hoverDuration: req.body?.hoverDuration ? parseInt(req.body.hoverDuration) : null,
          clickedFromMap: req.body?.clickedFromMap === 'true'
        };

        await UserInteraction.create({
          userId,
          rentalId,
          interactionType: 'view',
          sessionId: req.sessionID || req.headers['x-session-id'],
          deviceType: detectDeviceType(req.headers['user-agent']),
          duration: parseInt(req.body?.duration) || 0,
          scrollDepth: parseInt(req.body?.scrollDepth) || 0,
          coordinates: {
            type: 'Point',
            coordinates: coordinates
          },
          contextData,  // 🔥 STORE CONTEXT
          markerAnalytics,  // 🔥 STORE MARKER ANALYTICS
          rentalSnapshot: {
            price: rental.price,
            propertyType: rental.propertyType,
            location: rental.location?.short,
            area: rental.area?.total,
            amenitiesCount: rental.amenities?.length || 0,
            furnitureCount: rental.furniture?.length || 0
          },
          userAgent: req.headers['user-agent'],
          ipAddress: req.ip
        });
        
        console.log(`✅ Tracked VIEW with context: ${userId}`);
        if (req.body?.markerClicked) {
          console.log(`   📍 Marker size: ${req.body.markerSize}, Opacity: ${req.body.markerOpacity}`);
        }
      } catch (err) {
        console.error('Error tracking:', err.message);
      }
    });
  };
  
  next();
};

/**
 * Track explicit actions (favorite, contact, etc.) - 🔥 CẬP NHẬT lưu coordinates
 */
const trackAction = (actionType) => {
  return async (req, res, next) => {
    next();
    
    setImmediate(async () => {
      try {
        const userId = req.userId;
        const rentalId = req.params.id || req.params.rentalId || req.body.rentalId;
        
        if (!userId || !rentalId) {
          console.warn(`⚠️ Missing userId or rentalId for ${actionType} tracking`);
          return;
        }
        
        // Get rental data - 🔥 INCLUDE COORDINATES
        const rental = await Rental.findById(rentalId).lean();
        if (!rental) {
          console.warn(`⚠️ Rental ${rentalId} not found for tracking`);
          return;
        }

        // 🔥 EXTRACT COORDINATES
        const coordinates = rental.location?.coordinates?.coordinates || [0, 0];

        // Create interaction record - 🔥 ADD coordinates FIELD
        await UserInteraction.create({
          userId,
          rentalId,
          interactionType: actionType,
          sessionId: req.sessionID || req.headers['x-session-id'],
          deviceType: detectDeviceType(req.headers['user-agent']),
          
          // 🔥 NEW: Lưu coordinates trực tiếp
          coordinates: {
            type: 'Point',
            coordinates: coordinates
          },
          
          rentalSnapshot: {
            price: rental.price,
            propertyType: rental.propertyType,
            location: rental.location?.short || rental.location?.fullAddress,
            area: rental.area?.total || 0,
            amenitiesCount: rental.amenities?.length || 0,
            furnitureCount: rental.furniture?.length || 0
          },
          userAgent: req.headers['user-agent'],
          ipAddress: req.ip || req.headers['x-forwarded-for']
        });
        
        console.log(`✅ Tracked ${actionType.toUpperCase()} for rental ${rentalId} by user ${userId}`);
        console.log(`   Coordinates: [${coordinates[0]}, ${coordinates[1]}]`);
      } catch (err) {
        console.error(`❌ Error tracking ${actionType}:`, err.message);
      }
    });
  };
};

/**
 * Track interaction with duration and scroll depth - 🔥 CẬP NHẬT lưu coordinates
 */
const trackDetailedInteraction = async (req, res) => {
  try {
    const { rentalId, duration, scrollDepth, interactionType = 'view' } = req.body;
    const userId = req.userId || 'anonymous';
    
    if (!rentalId) {
      return res.status(400).json({ 
        success: false, 
        message: 'rentalId is required' 
      });
    }
    
    // Get rental data - 🔥 INCLUDE COORDINATES
    const rental = await Rental.findById(rentalId).lean();
    if (!rental) {
      return res.status(404).json({ 
        success: false, 
        message: 'Rental not found' 
      });
    }

    // 🔥 EXTRACT COORDINATES
    const coordinates = rental.location?.coordinates?.coordinates || [0, 0];

    // Create or update interaction - 🔥 ADD coordinates FIELD
    await UserInteraction.create({
      userId,
      rentalId,
      interactionType,
      sessionId: req.sessionID || req.headers['x-session-id'],
      deviceType: detectDeviceType(req.headers['user-agent']),
      duration: parseInt(duration) || 0,
      scrollDepth: Math.min(100, Math.max(0, parseInt(scrollDepth) || 0)),
      
      // 🔥 NEW: Lưu coordinates trực tiếp
      coordinates: {
        type: 'Point',
        coordinates: coordinates
      },
      
      rentalSnapshot: {
        price: rental.price,
        propertyType: rental.propertyType,
        location: rental.location?.short || rental.location?.fullAddress,
        area: rental.area?.total || 0,
        amenitiesCount: rental.amenities?.length || 0,
        furnitureCount: rental.furniture?.length || 0
      },
      userAgent: req.headers['user-agent'],
      ipAddress: req.ip || req.headers['x-forwarded-for']
    });
    
    res.json({ 
      success: true, 
      message: 'Interaction tracked successfully' 
    });
  } catch (err) {
    console.error('Error tracking detailed interaction:', err);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to track interaction', 
      error: err.message 
    });
  }
};

/**
 * Get user interaction analytics - 🔥 CẬP NHẬT include coordinates
 */
const getUserAnalytics = async (req, res) => {
  try {
    const userId = req.userId;
    
    if (!userId) {
      return res.status(401).json({ 
        success: false, 
        message: 'Unauthorized' 
      });
    }
    
    const summary = await UserInteraction.getUserSummary(userId);
    
    // Get recent interactions - 🔥 INCLUDE COORDINATES
    const recentInteractions = await UserInteraction.find({ userId })
      .sort({ timestamp: -1 })
      .limit(50)
      .populate('rentalId', 'title price location images')
      .lean();
    
    // Calculate stats    
    const totalInteractions = recentInteractions.length;
    const avgDuration = recentInteractions.reduce((sum, i) => sum + (i.duration || 0), 0) / totalInteractions || 0;
    const avgScrollDepth = recentInteractions.reduce((sum, i) => sum + (i.scrollDepth || 0), 0) / totalInteractions || 0;
    
    // 🔥 NEW: Calculate location stats
    const validCoordinates = recentInteractions.filter(i => 
      i.coordinates?.coordinates && 
      i.coordinates.coordinates[0] !== 0 && 
      i.coordinates.coordinates[1] !== 0
    );
    
    let centerLongitude = 0, centerLatitude = 0;
    if (validCoordinates.length > 0) {
      centerLongitude = validCoordinates.reduce((sum, i) => sum + i.coordinates.coordinates[0], 0) / validCoordinates.length;
      centerLatitude = validCoordinates.reduce((sum, i) => sum + i.coordinates.coordinates[1], 0) / validCoordinates.length;
    }
    
    res.json({
      success: true,
      data: {
        summary,
        totalInteractions,
        avgDuration: Math.round(avgDuration),
        avgScrollDepth: Math.round(avgScrollDepth),
        
        // 🔥 NEW: Location analytics
        locationStats: {
          interactionsWithCoordinates: validCoordinates.length,
          centerCoordinates: [centerLongitude, centerLatitude],
        },
        
        recentInteractions: recentInteractions.slice(0, 10).map(i => ({
          ...i,
          coordinates: i.coordinates?.coordinates || [0, 0]
        }))
      }
    });
  } catch (err) {
    console.error('Error getting user analytics:', err);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to get analytics', 
      error: err.message 
    });
  }
};

module.exports = {
  trackRentalView,
  trackAction,
  trackDetailedInteraction,
  getUserAnalytics,
  detectDeviceType
};