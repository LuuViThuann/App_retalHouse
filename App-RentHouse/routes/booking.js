require('dotenv').config();

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Booking = require('../models/booking');
const Rental = require('../models/Rental');
const Notification = require('../models/notification');
const admin = require('firebase-admin');

// Authentication middleware
const authMiddleware = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

// Helper function to adjust timestamps for +7 timezone
const adjustTimestamps = (obj) => {
  const adjusted = { ...obj.toObject() };
  adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
  adjusted.updatedAt = new Date(adjusted.updatedAt.getTime() + 7 * 60 * 60 * 1000);
  adjusted.bookingDate = new Date(adjusted.bookingDate.getTime() + 7 * 60 * 60 * 1000);
  return adjusted;
};

// Create booking
router.post('/bookings', authMiddleware, async (req, res) => {
  try {
    const { rentalId, customerInfo, preferredViewingTime } = req.body;

    // Validate rentalId
    if (!mongoose.Types.ObjectId.isValid(rentalId)) {
      return res.status(400).json({ message: 'Invalid rental ID' });
    }

    // Check if rental exists
    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    // Check if rental is available
    if (rental.status !== 'available') {
      return res.status(400).json({ message: 'Rental is not available for booking' });
    }

    // Check if user has already booked this rental
    const existingBooking = await Booking.findOne({
      userId: req.userId,
      rentalId: rentalId,
      status: { $in: ['pending', 'confirmed'] }
    });

    if (existingBooking) {
      return res.status(400).json({ message: 'You have already booked this rental' });
    }

    // Validate required fields
    if (!customerInfo.name || !customerInfo.phone || !customerInfo.email) {
      return res.status(400).json({ message: 'Name, phone and email are required' });
    }

    if (!preferredViewingTime) {
      return res.status(400).json({ message: 'Preferred viewing time is required' });
    }

    // Create booking
    const booking = new Booking({
      userId: req.userId,
      rentalId: rentalId,
      customerInfo: {
        name: customerInfo.name,
        phone: customerInfo.phone,
        email: customerInfo.email,
        message: customerInfo.message || ''
      },
      bookingDate: new Date(),
      preferredViewingTime: preferredViewingTime,
      status: 'pending'
    });

    const newBooking = await booking.save();

    // Create notification for rental owner
    const notification = new Notification({
      userId: rental.userId,
      type: 'Booking',
      message: 'Có người đặt chỗ xem nhà mới',
      content: `${customerInfo.name} đã đặt chỗ xem nhà "${rental.title}" vào lúc ${preferredViewingTime}`,
      rentalId: rentalId,
      bookingId: newBooking._id
    });

    await notification.save();

    // Return booking with adjusted timestamps
    const adjustedBooking = adjustTimestamps(newBooking);

    res.status(201).json({
      message: 'Booking created successfully',
      booking: adjustedBooking
    });

  } catch (err) {
    console.error('Error creating booking:', err);
    res.status(500).json({ message: 'Failed to create booking', error: err.message });
  }
});

// Get user's bookings
router.get('/bookings/my-bookings', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    let query = { userId: req.userId };
    if (status) {
      query.status = status;
    }

    const bookings = await Booking.find(query)
      .populate('rentalId', 'title price location images status contactInfo propertyType area amenities furniture surroundings rentalTerms')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    const total = await Booking.countDocuments(query);

    // Adjust timestamps and add rental information
    const adjustedBookings = bookings.map(booking => {
      const adjusted = { ...booking };
      adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
      adjusted.updatedAt = new Date(adjusted.updatedAt.getTime() + 7 * 60 * 60 * 1000);
      adjusted.bookingDate = new Date(adjusted.bookingDate.getTime() + 7 * 60 * 60 * 1000);
      
      // Add rental information to the response
      if (booking.rentalId) {
        adjusted.rentalTitle = booking.rentalId.title;
        adjusted.rentalAddress = booking.rentalId.location?.fullAddress;
        adjusted.rentalPrice = booking.rentalId.price;
        adjusted.rentalImage = booking.rentalId.images?.[0];
        adjusted.ownerName = booking.rentalId.contactInfo?.name;
        adjusted.ownerPhone = booking.rentalId.contactInfo?.phone;
        adjusted.ownerEmail = booking.rentalId.contactInfo?.email;
        adjusted.propertyType = booking.rentalId.propertyType;
        adjusted.area = booking.rentalId.area;
        adjusted.amenities = booking.rentalId.amenities;
        adjusted.furniture = booking.rentalId.furniture;
        adjusted.surroundings = booking.rentalId.surroundings;
        adjusted.rentalTerms = booking.rentalId.rentalTerms;
      }
      
      return adjusted;
    });

    res.json({
      bookings: adjustedBookings,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit))
    });

  } catch (err) {
    console.error('Error fetching user bookings:', err);
    res.status(500).json({ message: 'Failed to fetch bookings', error: err.message });
  }
});

// Get bookings for rental owner
router.get('/bookings/rental/:rentalId', authMiddleware, async (req, res) => {
  try {
    const { rentalId } = req.params;
    const { page = 1, limit = 10, status } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    // Check if rental exists and user owns it
    const rental = await Rental.findById(rentalId);
    if (!rental) {
      return res.status(404).json({ message: 'Rental not found' });
    }

    if (rental.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    let query = { rentalId: rentalId };
    if (status) {
      query.status = status;
    }

    const bookings = await Booking.find(query)
      .populate('userId', 'username email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    const total = await Booking.countDocuments(query);

    // Adjust timestamps
    const adjustedBookings = bookings.map(booking => {
      const adjusted = { ...booking };
      adjusted.createdAt = new Date(adjusted.createdAt.getTime() + 7 * 60 * 60 * 1000);
      adjusted.updatedAt = new Date(adjusted.updatedAt.getTime() + 7 * 60 * 60 * 1000);
      adjusted.bookingDate = new Date(adjusted.bookingDate.getTime() + 7 * 60 * 60 * 1000);
      return adjusted;
    });

    res.json({
      bookings: adjustedBookings,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit))
    });

  } catch (err) {
    console.error('Error fetching rental bookings:', err);
    res.status(500).json({ message: 'Failed to fetch bookings', error: err.message });
  }
});

// Update booking status (for rental owner)
router.patch('/bookings/:bookingId/status', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { status, ownerNotes } = req.body;

    if (!mongoose.Types.ObjectId.isValid(bookingId)) {
      return res.status(400).json({ message: 'Invalid booking ID' }); 
    }

    // Check if booking exists
    const booking = await Booking.findById(bookingId).populate('rentalId');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if user owns the rental
    if (booking.rentalId.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this rental' });
    }

    // Validate status
    const validStatuses = ['pending', 'confirmed', 'rejected', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    // Update booking
    const updateData = { status };
    if (ownerNotes !== undefined) {
      updateData.ownerNotes = ownerNotes;
    }

    const updatedBooking = await Booking.findByIdAndUpdate(
      bookingId,
      updateData,
      { new: true }
    ).populate('rentalId');

    // Create notification for customer
    const statusMessages = {
      'confirmed': 'Đặt chỗ xem nhà đã được xác nhận',
      'rejected': 'Đặt chỗ xem nhà đã bị từ chối',
      'cancelled': 'Đặt chỗ xem nhà đã bị hủy'
    };

    if (status !== 'pending') {
      const notification = new Notification({
        userId: booking.userId,
        type: 'Booking',
        message: statusMessages[status],
        content: `Đặt chỗ xem nhà "${booking.rentalId.title}" đã được ${status === 'confirmed' ? 'xác nhận' : status === 'rejected' ? 'từ chối' : 'hủy'}${ownerNotes ? ` với ghi chú: ${ownerNotes}` : ''}`,
        rentalId: booking.rentalId._id,
        bookingId: booking._id
      });

      await notification.save();
    }

    const adjustedBooking = adjustTimestamps(updatedBooking);

    res.json({
      message: 'Booking status updated successfully',
      booking: adjustedBooking
    });

  } catch (err) {
    console.error('Error updating booking status:', err);
    res.status(500).json({ message: 'Failed to update booking status', error: err.message });
  }
});

// Cancel booking (for customer)
router.patch('/bookings/:bookingId/cancel', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(bookingId)) {
      return res.status(400).json({ message: 'Invalid booking ID' });
    }

    // Check if booking exists
    const booking = await Booking.findById(bookingId).populate('rentalId');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if user owns the booking
    if (booking.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this booking' });
    }

    // Check if booking can be cancelled
    if (booking.status !== 'pending') {
      return res.status(400).json({ message: 'Only pending bookings can be cancelled' });
    }

    // Update booking status
    const updatedBooking = await Booking.findByIdAndUpdate(
      bookingId,
      { status: 'cancelled' },
      { new: true }
    ).populate('rentalId');

    // Create notification for rental owner
    const notification = new Notification({
      userId: booking.rentalId.userId,
      type: 'Booking',
      message: 'Đặt chỗ xem nhà đã bị hủy',
      content: `${booking.customerInfo.name} đã hủy đặt chỗ xem nhà "${booking.rentalId.title}"`,
      rentalId: booking.rentalId._id,
      bookingId: booking._id
    });

    await notification.save();

    const adjustedBooking = adjustTimestamps(updatedBooking);

    res.json({
      message: 'Booking cancelled successfully',
      booking: adjustedBooking
    });

  } catch (err) {
    console.error('Error cancelling booking:', err);
    res.status(500).json({ message: 'Failed to cancel booking', error: err.message });
  }
});

// Get booking by ID
router.get('/bookings/:bookingId', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(bookingId)) {
      return res.status(400).json({ message: 'Invalid booking ID' });
    }

    const booking = await Booking.findById(bookingId)
      .populate('rentalId', 'title price location images status contactInfo userId propertyType area amenities furniture surroundings rentalTerms')
      .populate('userId', 'username email')
      .lean();

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if user has access to this booking
    if (booking.userId !== req.userId && booking.rentalId.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized access to booking' });
    }

    // Add rental information to the response
    const responseData = {
      ...booking,
      rentalTitle: booking.rentalId?.title,
      rentalAddress: booking.rentalId?.location?.fullAddress,
      rentalPrice: booking.rentalId?.price,
      rentalImage: booking.rentalId?.images?.[0],
      ownerName: booking.rentalId?.contactInfo?.name,
      ownerPhone: booking.rentalId?.contactInfo?.phone,
      ownerEmail: booking.rentalId?.contactInfo?.email,
      propertyType: booking.rentalId?.propertyType,
      area: booking.rentalId?.area,
      amenities: booking.rentalId?.amenities,
      furniture: booking.rentalId?.furniture,
      surroundings: booking.rentalId?.surroundings,
      rentalTerms: booking.rentalId?.rentalTerms,
      createdAt: new Date(booking.createdAt.getTime() + 7 * 60 * 60 * 1000),
      updatedAt: new Date(booking.updatedAt.getTime() + 7 * 60 * 60 * 1000),
      bookingDate: new Date(booking.bookingDate.getTime() + 7 * 60 * 60 * 1000)
    };

    res.json(responseData);

  } catch (err) {
    console.error('Error fetching booking:', err);
    res.status(500).json({ message: 'Failed to fetch booking', error: err.message });
  }
});

// Delete booking (only for cancelled bookings)
router.delete('/bookings/:bookingId', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(bookingId)) {
      return res.status(400).json({ message: 'Invalid booking ID' });
    }

    // Check if booking exists
    const booking = await Booking.findById(bookingId).populate('rentalId');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if user owns the booking
    if (booking.userId !== req.userId) {
      return res.status(403).json({ message: 'Unauthorized: You do not own this booking' });
    }

    // Check if booking is cancelled (only cancelled bookings can be deleted)
    if (booking.status !== 'cancelled') {
      return res.status(400).json({ message: 'Only cancelled bookings can be deleted' });
    }

    // Delete the booking
    await Booking.findByIdAndDelete(bookingId);

    // Create notification for rental owner about deletion
    const notification = new Notification({
      userId: booking.rentalId.userId,
      type: 'Booking',
      message: 'Đặt chỗ xem nhà đã bị xóa',
      content: `${booking.customerInfo.name} đã xóa đặt chỗ xem nhà "${booking.rentalId.title}"`,
      rentalId: booking.rentalId._id,
      bookingId: booking._id
    });

    await notification.save();

    res.json({
      message: 'Booking deleted successfully'
    });

  } catch (err) {
    console.error('Error deleting booking:', err);
    res.status(500).json({ message: 'Failed to delete booking', error: err.message });
  }
});

module.exports = router; 