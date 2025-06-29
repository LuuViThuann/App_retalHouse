import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/rental.dart';
import '../services/booking_service.dart';

class BookingViewModel extends ChangeNotifier {
  final BookingService _bookingService = BookingService();

  List<Booking> _myBookings = [];
  List<Booking> _rentalBookings = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  int _myBookingsPage = 1;
  int _rentalBookingsPage = 1;
  int _myBookingsTotalPages = 1;
  int _rentalBookingsTotalPages = 1;
  int _myBookingsTotal = 0;
  int _rentalBookingsTotal = 0;

  // Getters
  List<Booking> get myBookings => _myBookings;
  List<Booking> get rentalBookings => _rentalBookings;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;
  int get myBookingsPage => _myBookingsPage;
  int get rentalBookingsPage => _rentalBookingsPage;
  int get myBookingsTotalPages => _myBookingsTotalPages;
  int get rentalBookingsTotalPages => _rentalBookingsTotalPages;
  int get myBookingsTotal => _myBookingsTotal;
  int get rentalBookingsTotal => _rentalBookingsTotal;

  // Tạo booking mới
  Future<bool> createBooking({
    required String rentalId,
    required Map<String, dynamic> customerInfo,
    required String preferredViewingTime,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.createBooking(
        rentalId: rentalId,
        customerInfo: customerInfo,
        preferredViewingTime: preferredViewingTime,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      // Refresh danh sách booking của người dùng
      await fetchMyBookings(page: 1);

      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  // Lấy danh sách booking của người dùng
  Future<void> fetchMyBookings({
    int page = 1,
    String? status,
    bool refresh = false,
  }) async {
    if (refresh) {
      _myBookings.clear();
      page = 1;
    }

    if (page == 1) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _bookingService.getMyBookings(
        page: page,
        status: status,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      if (page == 1) {
        _myBookings = result['bookings'] as List<Booking>;
      } else {
        _myBookings.addAll(result['bookings'] as List<Booking>);
      }

      _myBookingsPage = result['page'] as int;
      _myBookingsTotalPages = result['pages'] as int;
      _myBookingsTotal = result['total'] as int;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Lấy danh sách booking cho chủ nhà
  Future<void> fetchRentalBookings({
    required String rentalId,
    int page = 1,
    String? status,
    bool refresh = false,
  }) async {
    if (refresh) {
      _rentalBookings.clear();
      page = 1;
    }

    if (page == 1) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _bookingService.getRentalBookings(
        rentalId: rentalId,
        page: page,
        status: status,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      if (page == 1) {
        _rentalBookings = result['bookings'] as List<Booking>;
      } else {
        _rentalBookings.addAll(result['bookings'] as List<Booking>);
      }

      _rentalBookingsPage = result['page'] as int;
      _rentalBookingsTotalPages = result['pages'] as int;
      _rentalBookingsTotal = result['total'] as int;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật trạng thái booking (cho chủ nhà)
  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
    String? ownerNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.updateBookingStatus(
        bookingId: bookingId,
        status: status,
        ownerNotes: ownerNotes,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      // Cập nhật booking trong danh sách
      final index =
          _rentalBookings.indexWhere((booking) => booking.id == bookingId);
      if (index != -1) {
        _rentalBookings[index] = _rentalBookings[index].copyWith(
          status: status,
          ownerNotes: ownerNotes ?? _rentalBookings[index].ownerNotes,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Hủy booking (cho khách hàng)
  Future<bool> cancelBooking({
    required String bookingId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.cancelBooking(
        bookingId: bookingId,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      // Cập nhật booking trong danh sách
      final index =
          _myBookings.indexWhere((booking) => booking.id == bookingId);
      if (index != -1) {
        _myBookings[index] = _myBookings[index].copyWith(status: 'cancelled');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Xóa booking (chỉ cho booking đã hủy)
  Future<bool> deleteBooking({
    required String bookingId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.deleteBooking(
        bookingId: bookingId,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      // Xóa booking khỏi danh sách
      _myBookings.removeWhere((booking) => booking.id == bookingId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Lấy chi tiết booking
  Future<Booking?> getBookingDetail({
    required String bookingId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = await _bookingService.getBookingDetail(
        bookingId: bookingId,
        onError: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );

      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset state
  void reset() {
    _myBookings.clear();
    _rentalBookings.clear();
    _isLoading = false;
    _isCreating = false;
    _errorMessage = null;
    _myBookingsPage = 1;
    _rentalBookingsPage = 1;
    _myBookingsTotalPages = 1;
    _rentalBookingsTotalPages = 1;
    _myBookingsTotal = 0;
    _rentalBookingsTotal = 0;
    notifyListeners();
  }

  // Helper methods
  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
