/**
 * 🔥 CẢI THIỆN: UserInteraction Model để lưu coordinates trực tiếp
 * File: models/UserInteraction.js - CẬP NHẬT
 */

const mongoose = require('mongoose');

const userInteractionSchema = new mongoose.Schema({
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

  // 🔥 NEW: LƯU TRỮ COORDINATES TRỰC TIẾP
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

  // Context when interaction happened
  contextData: {
    searchQuery: String,
    priceRange: {
      min: Number,
      max: Number
    },
    propertyType: String,
    location: String,
    fromRecommendation: {
      type: Boolean,
      default: false
    },
    recommendationType: String // 'similar', 'popular', 'personalized'
  },

  // Snapshot of rental at interaction time
  rentalSnapshot: {
    price: Number,
    propertyType: String,
    location: String,
    area: Number,
    amenitiesCount: Number,
    furnitureCount: Number
  },

  // Metadata
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
userInteractionSchema.index({ coordinates: '2dsphere' }); // 🔥 GEOSPATIAL INDEX

// TTL index - auto delete interactions older than 180 days
userInteractionSchema.index({ timestamp: 1 }, { expireAfterSeconds: 15552000 });

// ==================== STATICS ====================
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
  
  if (result.length === 0) return { totalInteractions: 0, totalScore: 0, uniqueUsers: 0 };
  
  return {
    totalInteractions: result[0].totalInteractions,
    totalScore: result[0].totalScore,
    uniqueUsers: result[0].uniqueUsers.length
  };
};

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

// 🔥 NEW: Export training data with coordinates
userInteractionSchema.statics.getTrainingData = async function(limit = 10000, skip = 0) {
  const interactions = await this.find()
    .sort({ timestamp: -1 })
    .skip(skip)
    .limit(limit)
    .lean();

  // Map to extract rental info
  const rentalIds = [...new Set(interactions.map(i => i.rentalId))];
  const Rental = mongoose.model('Rental');
  
  const rentals = await Rental.find({ _id: { $in: rentalIds } })
    .select('_id location propertyType price area')
    .lean();

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
    };
  });
};

// 🔥 NEW: Nearby interactions by coordinates
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