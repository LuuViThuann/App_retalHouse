// models/ChatConversation.js
const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
    role: {
        type: String,
        enum: ['user', 'assistant', 'system'],
        required: true
    },
    content: {
        type: String,
        required: true
    },
    timestamp: {
        type: Date,
        default: Date.now
    },
    metadata: {
        type: mongoose.Schema.Types.Mixed,  // For storing extra data
        default: {}
    }
}, { _id: false });

const chatConversationSchema = new mongoose.Schema({
    userId: {
        type: String,
        required: true,
        index: true
    },

    messages: [chatMessageSchema],

    // Preferences extracted từ conversation
    extractedPreferences: {
        priceRange: {
            min: Number,
            max: Number
        },
        location: String,
        propertyType: String,
        areaRange: {
            min: Number,
            max: Number
        },
        bedrooms: Number,
        amenities: [String],
        furniture: String,
        moveInDate: Date,
        priority: String  // price/location/area
    },

    // User context khi bắt đầu conversation
    userContext: {
        type: mongoose.Schema.Types.Mixed,
        default: {}
    },

    // Rentals đã được recommend trong conversation này
    recommendedRentals: [{
        rentalId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Rental'
        },
        score: Number,
        timestamp: {
            type: Date,
            default: Date.now
        }
    }],

    // Status
    status: {
        type: String,
        enum: ['active', 'completed', 'abandoned'],
        default: 'active'
    },

    // Timestamps
    startedAt: {
        type: Date,
        default: Date.now
    },
    lastMessageAt: {
        type: Date,
        default: Date.now
    },
    completedAt: Date,

    // Stats
    totalMessages: {
        type: Number,
        default: 0
    },
    totalRecommendations: {
        type: Number,
        default: 0
    }

}, {
    timestamps: true
});

// Indexes
chatConversationSchema.index({ userId: 1, lastMessageAt: -1 });
chatConversationSchema.index({ status: 1, lastMessageAt: -1 });

// Pre-save middleware
chatConversationSchema.pre('save', function (next) {
    this.totalMessages = this.messages.length;
    this.totalRecommendations = this.recommendedRentals.length;
    next();
});

// Methods
chatConversationSchema.methods.addMessage = function (role, content, metadata = {}) {
    this.messages.push({
        role,
        content,
        timestamp: new Date(),
        metadata
    });
    this.lastMessageAt = new Date();
    return this.save();
};

chatConversationSchema.methods.addRecommendation = function (rentalId, score) {
    this.recommendedRentals.push({
        rentalId,
        score,
        timestamp: new Date()
    });
    return this.save();
};

chatConversationSchema.methods.markCompleted = function () {
    this.status = 'completed';
    this.completedAt = new Date();
    return this.save();
};

// Static methods
chatConversationSchema.statics.findActiveByUser = function (userId) {
    return this.find({
        userId,
        status: 'active'
    }).sort({ lastMessageAt: -1 });
};

chatConversationSchema.statics.getConversationStats = async function (userId) {
    const stats = await this.aggregate([
        { $match: { userId } },
        {
            $group: {
                _id: '$status',
                count: { $sum: 1 },
                totalMessages: { $sum: '$totalMessages' },
                totalRecommendations: { $sum: '$totalRecommendations' }
            }
        }
    ]);

    return stats;
};

const ChatConversation = mongoose.model('ChatConversation', chatConversationSchema);

module.exports = ChatConversation;