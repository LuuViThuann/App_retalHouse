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
        type: [Number], // [longitude, latitude]
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
  },
  images: {
    type: [String],
    default: [],
    validate: {
      validator: function(v) {
        // Validate Cloudinary URL format
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
        // Validate Cloudinary URL format for videos
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
  },
  geocodingStatus: {
    type: String,
    enum: ['success', 'failed', 'pending', 'manual'],
    default: 'pending',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Create a 2dsphere index for geospatial queries
rentalSchema.index({ 'location.coordinates': '2dsphere' });

// Index for better search performance
rentalSchema.index({ title: 'text', 'location.short': 'text' });
rentalSchema.index({ status: 1, createdAt: -1 });
rentalSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Rental', rentalSchema);