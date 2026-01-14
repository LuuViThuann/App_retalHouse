// models/Rental.js - FIXED (No Duplicate Indexes)
const mongoose = require('mongoose');

const rentalSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
  },
  price: {
    type: Number,
    required: true,
    min: 0,
  },
  area: {
    total: { type: Number, required: true, min: 0 },
    livingRoom: { type: Number, min: 0 },
    bedrooms: { type: Number, min: 0 },
    bathrooms: { type: Number, min: 0 },
  },
  location: {
    short: { type: String, required: true },
    fullAddress: { type: String, required: true },
    formattedAddress: { type: String }, 
    coordinates: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
        required: true,
      },
      coordinates: {
        type: [Number],
        required: [true, 'Coordinates are required'],
        validate: {
          validator: function (coords) {
            const [longitude, latitude] = coords;
            return (
              typeof longitude === 'number' &&
              typeof latitude === 'number' &&
              longitude >= -180 &&
              longitude <= 180 &&
              latitude >= -90 &&
              latitude <= 90
            );
          },
          message: 'Invalid coordinates: must be [longitude, latitude], within [-180, 180] and [-90, 90]',
        },
      },
    },
  },
  propertyType: {
    type: String,
  },
  furniture: {
    type: [String],
    default: [],
  },
  amenities: {
    type: [String],
    default: [],
  },
  surroundings: {
    type: [String],
    default: [],
  },
  rentalTerms: {
    minimumLease: { type: String },
    deposit: { type: String },
    paymentMethod: { type: String },
    renewalTerms: { type: String },
  },
  contactInfo: {
    name: { type: String }, 
    phone: { type: String },
    availableHours: { type: String },
  },
  userId: {
    type: String,
    ref: 'User',
    required: true,
    index: true,
  },
  images: {
    type: [String],
    default: [],
    validate: {
      validator: function(v) {
        return v.every(url => 
          typeof url === 'string' && 
          (url.includes('cloudinary.com') || url.startsWith('http'))
        );
      },
      message: 'Invalid image URL format'
    }
  },
  videos: {
    type: [String],
    default: [],
    validate: {
      validator: function(v) {
        return v.every(url => 
          typeof url === 'string' && 
          (url.includes('cloudinary.com') || url.startsWith('http'))
        );
      },
      message: 'Invalid video URL format'
    }
  },
  status: {
    type: String,
    enum: ['available', 'rented'],
    default: 'available',
    index: true,
  },
  geocodingStatus: {
    type: String,
    enum: ['success', 'failed', 'pending', 'manual'],
    default: 'pending',
  },
  
  // Payment Information
  paymentInfo: {
    transactionCode: {
      type: String,
      sparse: true,
     
    },
    paymentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
      sparse: true,
    },
    amount: {
      type: Number,
      default: 10000,
    },
    status: {
      type: String,
      enum: ['pending', 'completed', 'failed'],
      default: 'pending',
     
    },
    paidAt: {
      type: Date,
      sparse: true,
    },
  },
  
  //  Publication Status
  publishedAt: {
    type: Date,
    sparse: true,
  },
  
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
  
  updatedAt: {
    type: Date,
    default: Date.now,
  },
}, { timestamps: true });

// ==================== INDEXES ====================
// Geospatial index
rentalSchema.index({ 'location.coordinates': '2dsphere' });

// Text search
rentalSchema.index({ title: 'text', 'location.short': 'text' });

// Status and time
rentalSchema.index({ status: 1, createdAt: -1 });

// User rentals
rentalSchema.index({ userId: 1, createdAt: -1 });

rentalSchema.index({ 'paymentInfo.status': 1, createdAt: -1 });
rentalSchema.index({ 'paymentInfo.transactionCode': 1, 'paymentInfo.status': 1 }, { sparse: true });

// ==================== VIRTUALS ====================
rentalSchema.virtual('isPaid').get(function() {
  return this.paymentInfo?.status === 'completed';
});

rentalSchema.virtual('isPublished').get(function() {
  return this.publishedAt !== null && this.publishedAt !== undefined;
});

// ==================== MIDDLEWARE ====================
rentalSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  if (this.paymentInfo?.status === 'completed' && !this.publishedAt) {
    this.publishedAt = new Date();
  }
  
  next();
});

// ==================== METHODS ====================
/**
 * Mark rental as paid
 */
rentalSchema.methods.markAsPaid = function(paymentId, transactionCode) {
  this.paymentInfo = {
    transactionCode,
    paymentId,
    status: 'completed',
    amount: 10000,
    paidAt: new Date(),
  };
  this.publishedAt = new Date();
  return this.save();
};

/**
 * Mark rental as unpaid
 */
rentalSchema.methods.markAsUnpaid = function(reason = 'Payment failed') {
  this.paymentInfo = {
    ...this.paymentInfo,
    status: 'failed',
    paidAt: null,
  };
  this.publishedAt = null;
  return this.save();
};

/**
 * Check if rental needs payment
 */
rentalSchema.methods.requiresPayment = function() {
  return this.paymentInfo?.status !== 'completed';
};

/**
 * Get payment status
 */
rentalSchema.methods.getPaymentStatus = function() {
  return {
    isPaid: this.isPaid,
    isPublished: this.isPublished,
    transactionCode: this.paymentInfo?.transactionCode,
    amount: this.paymentInfo?.amount || 10000,
    status: this.paymentInfo?.status || 'pending',
    paidAt: this.paymentInfo?.paidAt,
  };
};

module.exports = mongoose.model('Rental', rentalSchema);