import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/rental.dart';
import '../viewmodels/vm_booking.dart';
import '../constants/app_color.dart';
import '../constants/app_style.dart';
import '../config/api_routes.dart';
import 'rental_detail_view.dart';

class BookingDetailView extends StatefulWidget {
  final Booking booking;

  const BookingDetailView({super.key, required this.booking});

  @override
  _BookingDetailViewState createState() => _BookingDetailViewState();
}

class _BookingDetailViewState extends State<BookingDetailView> {
  Booking? _bookingDetail;

  @override
  void initState() {
    super.initState();
    _loadBookingDetail();
  }

  Future<void> _loadBookingDetail() async {
    final bookingViewModel =
        Provider.of<BookingViewModel>(context, listen: false);
    final detail =
        await bookingViewModel.getBookingDetail(bookingId: widget.booking.id);
    if (detail != null) {
      setState(() {
        _bookingDetail = detail;
      });
    }
  }

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatDeposit(String deposit) {
    try {
      final amount = double.tryParse(deposit.replaceAll(RegExp(r'[^\d.]'), ''));
      if (amount != null) {
        return formatCurrency(amount);
      }
      return deposit;
    } catch (e) {
      return deposit;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'confirmed':
        return const Color(0xFF2196F3);
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: const Text('Bạn có chắc chắn muốn hủy đặt chỗ này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Có'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final bookingViewModel =
          Provider.of<BookingViewModel>(context, listen: false);
      final success =
          await bookingViewModel.cancelBooking(bookingId: widget.booking.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy đặt chỗ thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(bookingViewModel.errorMessage ?? 'Hủy đặt chỗ thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa hợp đồng này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final bookingViewModel =
          Provider.of<BookingViewModel>(context, listen: false);
      final success =
          await bookingViewModel.deleteBooking(bookingId: widget.booking.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa hợp đồng thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(bookingViewModel.errorMessage ?? 'Xóa hợp đồng thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRentalDetail() {
    try {
      if (widget.booking.rentalId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có thông tin bài viết để xem'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _navigateToRealRental();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở chi tiết bài viết: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error navigating to rental detail: $e');
    }
  }

  void _navigateToRealRental() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
        ),
      );

      final rental = Rental(
        id: widget.booking.rentalId,
        title: widget.booking.rentalTitle ?? 'Không có tiêu đề',
        price: widget.booking.rentalPrice ?? 0.0,
        area: {
          'total': 0.0,
          'livingRoom': 0.0,
          'bedrooms': 0.0,
          'bathrooms': 0.0
        },
        location: {
          'short': '',
          'fullAddress': widget.booking.rentalAddress ?? ''
        },
        propertyType: widget.booking.propertyType ?? 'Khác',
        furniture: widget.booking.furniture ?? [],
        amenities: widget.booking.amenities ?? [],
        surroundings: widget.booking.surroundings ?? [],
        rentalTerms: widget.booking.rentalTerms ??
            {
              'minimumLease': '',
              'deposit': '',
              'paymentMethod': '',
              'renewalTerms': ''
            },
        contactInfo: {
          'name': widget.booking.ownerName ?? '',
          'phone': widget.booking.ownerPhone ?? '',
          'availableHours': ''
        },
        userId: '',
        images: widget.booking.rentalImage != null
            ? [widget.booking.rentalImage!]
            : [],
        status: 'available',
        createdAt: DateTime.now(),
        landlord: '',
      );

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RentalDetailScreen(rental: rental),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showRentalInfoDialog();
      print('Error navigating to real rental: $e');
    }
  }

  void _showRentalInfoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thông tin bài viết',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.booking.rentalImage != null &&
                        widget.booking.rentalImage!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            '${ApiRoutes.baseUrl.replaceAll('/api', '')}${widget.booking.rentalImage}',
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey[400],
                                  size: 30,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                width: double.infinity,
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    _buildInfoRowDialog('Tiêu đề',
                        widget.booking.rentalTitle ?? 'Không có tiêu đề'),
                    _buildInfoRowDialog('Địa chỉ',
                        widget.booking.rentalAddress ?? 'Không có địa chỉ'),
                    if (widget.booking.rentalPrice != null)
                      _buildInfoRowDialog('Giá thuê',
                          formatCurrency(widget.booking.rentalPrice!)),
                    if (widget.booking.propertyType?.isNotEmpty == true)
                      _buildInfoRowDialog(
                          'Loại bất động sản', widget.booking.propertyType!),
                    if (widget.booking.rentalId.isNotEmpty)
                      _buildInfoRowDialog(
                          'Mã bài viết', widget.booking.rentalId),
                    const SizedBox(height: 20),
                    const Text(
                      'Thông tin chủ bài viết',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRowDialog('Họ tên',
                        widget.booking.ownerName ?? 'Không có thông tin'),
                    _buildInfoRowDialog('Số điện thoại',
                        widget.booking.ownerPhone ?? 'Không có thông tin'),
                    if (widget.booking.ownerEmail?.isNotEmpty == true)
                      _buildInfoRowDialog('Email', widget.booking.ownerEmail!),
                    const SizedBox(height: 20),
                    const Text(
                      'Thông tin đặt chỗ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRowDialog(
                        'Thời gian xem', widget.booking.preferredViewingTime),
                    _buildInfoRowDialog(
                        'Ngày đặt chỗ', formatDate(widget.booking.bookingDate)),
                    _buildInfoRowDialog(
                        'Trạng thái', getStatusText(widget.booking.status)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowDialog(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = _bookingDetail ?? widget.booking;
    final String imageUrl = booking.rentalImage != null &&
            booking.rentalImage!.isNotEmpty
        ? '${ApiRoutes.baseUrl.replaceAll('/api', '')}${booking.rentalImage}'
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Chi tiết đặt chỗ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          if (booking.status == 'cancelled')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteBooking,
              tooltip: 'Xóa hợp đồng',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    getStatusColor(booking.status).withOpacity(0.1),
                    getStatusColor(booking.status).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: getStatusColor(booking.status).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: getStatusColor(booking.status).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: getStatusColor(booking.status).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getStatusIcon(booking.status),
                      size: 48,
                      color: getStatusColor(booking.status),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mã đặt chỗ #${booking.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          getStatusColor(booking.status),
                          getStatusColor(booking.status).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color:
                              getStatusColor(booking.status).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      getStatusText(booking.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Thông tin bài viết',
              icon: Icons.home_outlined,
              iconColor: const Color(0xFF4CAF50),
              children: [
                if (imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 220,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 220,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: double.infinity,
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                _buildInfoRow(
                  'Tiêu đề',
                  booking.rentalTitle ?? 'Không có tiêu đề',
                  icon: Icons.title,
                  iconColor: const Color(0xFF2196F3),
                ),
                _buildInfoRow(
                  'Địa chỉ',
                  booking.rentalAddress ?? 'Không có địa chỉ',
                  icon: Icons.location_on,
                  iconColor: const Color(0xFFFF5722),
                ),
                if (booking.rentalPrice != null)
                  _buildInfoRow(
                    'Giá thuê',
                    formatCurrency(booking.rentalPrice!),
                    icon: Icons.attach_money,
                    iconColor: const Color(0xFF4CAF50),
                    isPrice: true,
                  ),
                if (booking.propertyType?.isNotEmpty == true)
                  _buildInfoRow(
                    'Loại bất động sản',
                    booking.propertyType!,
                    icon: Icons.category,
                    iconColor: const Color(0xFF9C27B0),
                  ),
                if (booking.area != null)
                  _buildInfoRow(
                    'Diện tích tổng',
                    '${booking.area!['total']?.toString() ?? '0'} m²',
                    icon: Icons.square_foot,
                    iconColor: const Color(0xFF795548),
                  ),
                if (booking.amenities?.isNotEmpty == true)
                  _buildInfoRow(
                    'Tiện ích',
                    booking.amenities!.take(3).join(', ') +
                        (booking.amenities!.length > 3 ? '...' : ''),
                    icon: Icons.emoji_emotions,
                    iconColor: const Color(0xFFFF9800),
                  ),
                if (booking.furniture?.isNotEmpty == true)
                  _buildInfoRow(
                    'Nội thất',
                    booking.furniture!.take(3).join(', ') +
                        (booking.furniture!.length > 3 ? '...' : ''),
                    icon: Icons.chair,
                    iconColor: const Color(0xFF795548),
                  ),
                if (booking.surroundings?.isNotEmpty == true)
                  _buildInfoRow(
                    'Xung quanh',
                    booking.surroundings!.take(3).join(', ') +
                        (booking.surroundings!.length > 3 ? '...' : ''),
                    icon: Icons.nature_people,
                    iconColor: const Color(0xFF4CAF50),
                  ),
                const SizedBox(height: 20),
                if (booking.rentalId.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _navigateToRentalDetail,
                      icon: const Icon(Icons.visibility, size: 20),
                      label: const Text(
                        'Xem chi tiết bài viết',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Thông tin chủ bài viết',
              icon: Icons.person_pin_outlined,
              iconColor: const Color(0xFF2196F3),
              children: [
                _buildInfoRow(
                  'Họ tên',
                  booking.ownerName ?? 'Không có thông tin',
                  icon: Icons.person,
                  iconColor: const Color(0xFF4CAF50),
                ),
                _buildInfoRow(
                  'Số điện thoại',
                  booking.ownerPhone ?? 'Không có thông tin',
                  icon: Icons.phone,
                  iconColor: const Color(0xFF2196F3),
                ),
                if (booking.ownerEmail?.isNotEmpty == true)
                  _buildInfoRow(
                    'Email',
                    booking.ownerEmail!,
                    icon: Icons.email,
                    iconColor: const Color(0xFFFF9800),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2196F3),
                              const Color(0xFF1976D2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (booking.ownerPhone?.isNotEmpty == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Liên hệ: ${booking.ownerPhone}'),
                                  backgroundColor: const Color(0xFF2196F3),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text(
                            'Gọi điện',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50),
                              const Color(0xFF388E3C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (booking.ownerPhone?.isNotEmpty == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Nhắn tin: ${booking.ownerPhone}'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.message, size: 20),
                          label: const Text(
                            'Nhắn tin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (booking.rentalTerms != null && booking.rentalTerms!.isNotEmpty)
              _buildSection(
                title: 'Điều khoản thuê',
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF9C27B0),
                children: [
                  if (booking.rentalTerms!['minimumLease']?.isNotEmpty == true)
                    _buildInfoRow(
                      'Thời hạn thuê tối thiểu',
                      booking.rentalTerms!['minimumLease'],
                      icon: Icons.schedule,
                      iconColor: const Color(0xFFFF9800),
                    ),
                  if (booking.rentalTerms!['deposit']?.isNotEmpty == true)
                    _buildInfoRow(
                      'Tiền cọc',
                      _formatDeposit(booking.rentalTerms!['deposit']!),
                      icon: Icons.account_balance_wallet,
                      iconColor: const Color(0xFF4CAF50),
                      isPrice: true,
                    ),
                  if (booking.rentalTerms!['paymentMethod']?.isNotEmpty == true)
                    _buildInfoRow(
                      'Phương thức thanh toán',
                      booking.rentalTerms!['paymentMethod'],
                      icon: Icons.payment,
                      iconColor: const Color(0xFF2196F3),
                    ),
                  if (booking.rentalTerms!['renewalTerms']?.isNotEmpty == true)
                    _buildInfoRow(
                      'Điều khoản gia hạn',
                      booking.rentalTerms!['renewalTerms'],
                      icon: Icons.update,
                      iconColor: const Color(0xFF9C27B0),
                    ),
                ],
              ),
            if (booking.rentalTerms != null && booking.rentalTerms!.isNotEmpty)
              const SizedBox(height: 24),
            _buildSection(
              title: 'Thông tin đặt chỗ',
              icon: Icons.event_note_outlined,
              iconColor: const Color(0xFFFF9800),
              children: [
                _buildInfoRow(
                  'Thời gian xem',
                  booking.preferredViewingTime,
                  icon: Icons.schedule,
                  iconColor: const Color(0xFFFF9800),
                ),
                _buildInfoRow(
                  'Ngày đặt chỗ',
                  formatDate(booking.bookingDate),
                  icon: Icons.calendar_today,
                  iconColor: const Color(0xFF2196F3),
                ),
                _buildInfoRow(
                  'Ngày tạo',
                  formatDate(booking.createdAt),
                  icon: Icons.create,
                  iconColor: const Color(0xFF4CAF50),
                ),
                if (booking.updatedAt != booking.createdAt)
                  _buildInfoRow(
                    'Cập nhật lần cuối',
                    formatDate(booking.updatedAt),
                    icon: Icons.update,
                    iconColor: const Color(0xFF9C27B0),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Thông tin liên hệ',
              icon: Icons.person_outline,
              iconColor: const Color(0xFF4CAF50),
              children: [
                _buildInfoRow(
                  'Họ tên',
                  booking.customerInfo['name'] ?? '',
                  icon: Icons.person,
                  iconColor: const Color(0xFF4CAF50),
                ),
                _buildInfoRow(
                  'Số điện thoại',
                  booking.customerInfo['phone'] ?? '',
                  icon: Icons.phone,
                  iconColor: const Color(0xFF2196F3),
                ),
                _buildInfoRow(
                  'Email',
                  booking.customerInfo['email'] ?? '',
                  icon: Icons.email,
                  iconColor: const Color(0xFFFF9800),
                ),
                if (booking.customerInfo['message']?.isNotEmpty == true)
                  _buildInfoRow(
                    'Ghi chú',
                    booking.customerInfo['message'],
                    icon: Icons.note,
                    iconColor: const Color(0xFF9C27B0),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (booking.ownerNotes.isNotEmpty)
              _buildSection(
                title: 'Ghi chú từ chủ nhà',
                icon: Icons.note_outlined,
                iconColor: const Color(0xFF2196F3),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE3F2FD),
                          const Color(0xFFBBDEFB),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            booking.ownerNotes,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (booking.status == 'pending')
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF44336),
                      const Color(0xFFD32F2F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF44336).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _cancelBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hủy đặt chỗ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                iconColor.withOpacity(0.1),
                iconColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    bool isPrice = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color:
                    isPrice ? const Color(0xFF4CAF50) : const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
