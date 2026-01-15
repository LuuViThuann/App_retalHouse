
const mongoose = require('mongoose');

const userInteractionSchema = new mongoose.Schema({
  // ==================== CORE FIELDS ====================
  userId: {
    type: String,
    required: true,
    index: true
  },
  rentalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Rental',
    required: true,
    index: true
  },
  interactionType: {
    type: String,
    enum: ['view', 'click', 'favorite', 'contact', 'share', 'call', 'unfavorite'],
    required: true
  },
  interactionScore: {
    type: Number,
    default: function() {
      const scores = {
        view: 1,
        click: 2,
        favorite: 5,
        unfavorite: -3,
        share: 3,
        contact: 8,
        call: 10
      };
      return scores[this.interactionType] || 1;
    }
  },

  // ==================== SESSION & DEVICE ====================
  sessionId: String,
  deviceType: {
    type: String,
    enum: ['mobile', 'desktop', 'tablet', 'unknown'],
    default: 'unknown'
  },
  duration: {
    type: Number,
    default: 0
  },
  scrollDepth: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  },

  // ==================== GEOSPATIAL DATA ====================
  coordinates: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      default: [0, 0]
    }
  },

  // ==================== CONTEXT DATA ====================
  contextData: {
    // Map/Search Context
    mapCenter: {
      longitude: Number,
      latitude: Number
    },
    zoomLevel: Number,
    searchRadius: Number,  // km
    
    // Time Context
    timeOfDay: {
      type: String,
      enum: ['morning', 'afternoon', 'evening', 'night'],
      default: 'morning'
    },
    weekday: String,  // Monday, Tuesday, etc.
    hourOfDay: Number,  // 0-23
    
    // Device Context
    deviceType: {
      type: String,
      enum: ['mobile', 'desktop', 'tablet'],
      default: 'mobile'
    },
    screenResolution: String,  // "1920x1080"
    
    // User Behavior Context
    scrollDepth: {
      type: Number,
      min: 0,
      max: 1,
      default: 0.5
    },
    markerClicked: Boolean,
    markerSize: Number,
    markerPriority: Number,
    impressionCount: Number,
    impressionPosition: Number,
    
    // Recommendation Context
    fromRecommendation: {
      type: Boolean,
      default: false
    },
    recommendationType: String,  // 'personalized', 'similar', 'popular', 'nearby'
    recommendationScore: Number,
    recommendationConfidence: Number,  // 0-1
    isTopRecommendation: Boolean,
    
    // Search Context
    searchQuery: String,
    filterApplied: {
      priceRange: {
        min: Number,
        max: Number
      },
      propertyType: String,
      location: String,
      radiusKm: Number
    }
  },

  // ==================== MARKER ANALYTICS ====================
  markerAnalytics: {
    markerSize: Number,  // 1-5
    markerOpacity: Number,  // 0-1
    markerColor: String,  // hex color
    markerLabel: String,  // "5M (85% match)"
    wasHighlighted: Boolean,
    hoverDuration: Number,  // ms
    clickedFromMap: Boolean
  },

  // ==================== RENTAL SNAPSHOT ====================
  rentalSnapshot: {
    price: Number,
    propertyType: String,
    location: String,
    area: Number,
    amenitiesCount: Number,
    furnitureCount: Number
  },

  // ==================== METADATA ====================
  userAgent: String,
  ipAddress: String,
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
}, { 
  timestamps: true,
  collection: 'userinteractions'
});

// ==================== INDEXES ====================
userInteractionSchema.index({ userId: 1, timestamp: -1 });
userInteractionSchema.index({ rentalId: 1, interactionType: 1, timestamp: -1 });
userInteractionSchema.index({ userId: 1, interactionType: 1, timestamp: -1 });
userInteractionSchema.index({ userId: 1, rentalId: 1 });
userInteractionSchema.index({ coordinates: '2dsphere' }); // Geospatial index

// TTL index - auto delete interactions older than 180 days
userInteractionSchema.index({ timestamp: 1 }, { expireAfterSeconds: 15552000 });

// ==================== STATIC METHODS ====================

/**
 * Get user interaction summary
 */
userInteractionSchema.statics.getUserSummary = async function(userId) {
  return await this.aggregate([
    { $match: { userId } },
    {
      $group: {
        _id: '$interactionType',
        count: { $sum: 1 },
        totalScore: { $sum: '$interactionScore' }
      }
    }
  ]);
};

/**
 * Get rental popularity metrics
 */
userInteractionSchema.statics.getRentalPopularity = async function(rentalId) {
  const result = await this.aggregate([
    { $match: { rentalId: new mongoose.Types.ObjectId(rentalId) } },
    {
      $group: {
        _id: null,
        totalInteractions: { $sum: 1 },
        totalScore: { $sum: '$interactionScore' },
        uniqueUsers: { $addToSet: '$userId' }
      }
    }
  ]);
  
  if (result.length === 0) {
    return { totalInteractions: 0, totalScore: 0, uniqueUsers: 0 };
  }
  
  return {
    totalInteractions: result[0].totalInteractions,
    totalScore: result[0].totalScore,
    uniqueUsers: result[0].uniqueUsers.length
  };
};

/**
 * Get trending rentals (last 7 days)
 */
userInteractionSchema.statics.getTrendingRentals = async function(limit = 10) {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  return await this.aggregate([
    { $match: { timestamp: { $gte: sevenDaysAgo } } },
    {
      $group: {
        _id: '$rentalId',
        totalScore: { $sum: '$interactionScore' },
        viewCount: { 
          $sum: { $cond: [{ $eq: ['$interactionType', 'view'] }, 1, 0] } 
        },
        favoriteCount: { 
          $sum: { $cond: [{ $eq: ['$interactionType', 'favorite'] }, 1, 0] } 
        },
        contactCount: { 
          $sum: { $cond: [{ $eq: ['$interactionType', 'contact'] }, 1, 0] } 
        }
      }
    },
    { $sort: { totalScore: -1 } },
    { $limit: limit }
  ]);
};

/**
 * Get user behavior pattern from context
 */
userInteractionSchema.statics.getUserBehaviorPattern = async function(userId, days = 30) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  return await this.aggregate([
    { $match: { userId, timestamp: { $gte: startDate } } },
    {
      $group: {
        _id: {
          timeOfDay: '$contextData.timeOfDay',
          deviceType: '$contextData.deviceType'
        },
        count: { $sum: 1 },
        avgScrollDepth: { $avg: '$contextData.scrollDepth' },
        avgDuration: { $avg: '$duration' },
        markerClickRate: {
          $avg: { $cond: ['$markerAnalytics.clickedFromMap', 1, 0] }
        }
      }
    },
    { $sort: { count: -1 } }
  ]);
};

/**
 * Get recommendation performance metrics
 */
userInteractionSchema.statics.getRecommendationPerformance = async function(userId, days = 30) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  return await this.aggregate([
    {
      $match: {
        userId,
        timestamp: { $gte: startDate },
        'contextData.fromRecommendation': true
      }
    },
    {
      $group: {
        _id: '$contextData.recommendationType',
        totalImpressions: { $sum: 1 },
        avgConfidence: { $avg: '$contextData.recommendationConfidence' },
        avgScore: { $avg: '$contextData.recommendationScore' },
        clickThroughCount: {
          $sum: { $cond: [{ $eq: ['$interactionType', 'click'] }, 1, 0] }
        },
        favoriteCount: {
          $sum: { $cond: [{ $eq: ['$interactionType', 'favorite'] }, 1, 0] }
        },
        contactCount: {
          $sum: { $cond: [{ $eq: ['$interactionType', 'contact'] }, 1, 0] }
        }
      }
    },
    {
      $addFields: {
        clickThroughRate: {
          $divide: [
            '$clickThroughCount',
            { $max: ['$totalImpressions', 1] }
          ]
        },
        conversionRate: {
          $divide: [
            { $add: ['$contactCount', '$favoriteCount'] },
            { $max: ['$totalImpressions', 1] }
          ]
        }
      }
    }
  ]);
};

/**
 * Get map interaction analytics
 */
userInteractionSchema.statics.getMapInteractionAnalytics = async function(userId, days = 7) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  return await this.aggregate([
    {
      $match: {
        userId,
        timestamp: { $gte: startDate },
        'markerAnalytics.clickedFromMap': true
      }
    },
    {
      $group: {
        _id: null,
        totalMapClicks: { $sum: 1 },
        avgHoverDuration: { $avg: '$markerAnalytics.hoverDuration' },
        avgMarkerSize: { $avg: '$markerAnalytics.markerSize' },
        highlightedCount: {
          $sum: { $cond: ['$markerAnalytics.wasHighlighted', 1, 0] }
        },
        totalImpressions: {
          $sum: { $max: ['$contextData.impressionCount', 1] }
        }
      }
    },
    {
      $addFields: {
        mapClickThroughRate: {
          $divide: ['$totalMapClicks', { $max: ['$totalImpressions', 1] }]
        }
      }
    }
  ]);
};

/**
 * Get user optimal context (time, device, radius, locations)
 */
userInteractionSchema.statics.getUserOptimalContext = async function(userId, days = 30) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const [timePattern, devicePattern, radiusPattern, favoriteLocations] = await Promise.all([
    // Optimal time of day
    this.aggregate([
      { $match: { userId, timestamp: { $gte: startDate } } },
      {
        $group: {
          _id: '$contextData.timeOfDay',
          count: { $sum: 1 },
          avgInteractionScore: { $avg: '$interactionScore' },
          favoriteRate: {
            $avg: { $cond: [{ $eq: ['$interactionType', 'favorite'] }, 1, 0] }
          }
        }
      },
      { $sort: { avgInteractionScore: -1 } },
      { $limit: 1 }
    ]),
    
    // Optimal device
    this.aggregate([
      { $match: { userId, timestamp: { $gte: startDate } } },
      {
        $group: {
          _id: '$contextData.deviceType',
          count: { $sum: 1 },
          avgInteractionScore: { $avg: '$interactionScore' }
        }
      },
      { $sort: { avgInteractionScore: -1 } },
      { $limit: 1 }
    ]),
    
    // Optimal search radius
    this.aggregate([
      { $match: { userId, timestamp: { $gte: startDate } } },
      {
        $group: {
          _id: '$contextData.filterApplied.radiusKm',
          count: { $sum: 1 },
          avgInteractionScore: { $avg: '$interactionScore' }
        }
      },
      { $sort: { avgInteractionScore: -1 } },
      { $limit: 1 }
    ]),
    
    // Favorite locations
    this.aggregate([
      { $match: { userId, timestamp: { $gte: startDate } } },
      {
        $group: {
          _id: '$contextData.mapCenter',
          count: { $sum: 1 },
          avgInteractionScore: { $avg: '$interactionScore' }
        }
      },
      { $sort: { count: -1 } },
      { $limit: 5 }
    ])
  ]);

  return {
    optimalTimeOfDay: timePattern[0]?._id,
    optimalDevice: devicePattern[0]?._id,
    optimalRadius: radiusPattern[0]?._id || 10,
    favoriteLocations: favoriteLocations.map(loc => loc._id).filter(l => l)
  };
};

/**
 * Get training data for ML models (with coordinates)
 */
userInteractionSchema.statics.getTrainingData = async function(limit = 10000, skip = 0) {
  const interactions = await this.find()
    .sort({ timestamp: -1 })
    .skip(skip)
    .limit(limit)
    .lean();

  // Get unique rental IDs
  const rentalIds = [...new Set(interactions.map(i => i.rentalId))];
  const Rental = mongoose.model('Rental');
  
  const rentals = await Rental.find({ _id: { $in: rentalIds } })
    .select('_id location propertyType price area')
    .lean();

  // Create rental map for quick lookup
  const rentalMap = new Map();
  rentals.forEach(rental => {
    rentalMap.set(rental._id.toString(), {
      coordinates: rental.location?.coordinates?.coordinates || [0, 0],
      location: rental.location?.fullAddress || '',
      propertyType: rental.propertyType,
      price: rental.price,
      area: rental.area?.total || 0,
    });
  });

  // Map interactions to training data format
  return interactions.map(interaction => {
    const rentalData = rentalMap.get(interaction.rentalId.toString());
    return {
      userId: interaction.userId,
      rentalId: interaction.rentalId.toString(),
      interactionType: interaction.interactionType,
      interactionScore: interaction.interactionScore,
      price: rentalData?.price || 0,
      propertyType: rentalData?.propertyType || 'Unknown',
      location: rentalData?.location || '',
      area: rentalData?.area || 0,
      timestamp: interaction.timestamp,
      duration: interaction.duration || 0,
      scrollDepth: interaction.scrollDepth || 0,
      deviceType: interaction.deviceType,
      longitude: rentalData?.coordinates?.[0] || 0,
      latitude: rentalData?.coordinates?.[1] || 0,
      searchQuery: interaction.contextData?.searchQuery || '',
      fromRecommendation: interaction.contextData?.fromRecommendation || false,
      recommendationType: interaction.contextData?.recommendationType || '',
      timeOfDay: interaction.contextData?.timeOfDay || '',
      markerClicked: interaction.markerAnalytics?.clickedFromMap || false,
    };
  });
};

/**
 * Get interactions by location (geospatial query)
 */
userInteractionSchema.statics.getInteractionsByLocation = async function(longitude, latitude, radiusKm = 10) {
  const radiusMeters = radiusKm * 1000;
  const radiusRadians = radiusMeters / 6378100;

  return await this.find({
    coordinates: {
      $geoWithin: {
        $centerSphere: [[longitude, latitude], radiusRadians]
      }
    }
  }).lean();
};

module.exports = mongoose.model('UserInteraction', userInteractionSchema);