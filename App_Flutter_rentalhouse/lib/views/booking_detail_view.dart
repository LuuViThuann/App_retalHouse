import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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
    // Tạo một Rental object từ thông tin có sẵn để điều hướng
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
      propertyType: 'Khác',
      furniture: [],
      amenities: [],
      surroundings: [],
      rentalTerms: {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalDetailScreen(rental: rental),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = _bookingDetail ?? widget.booking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đặt chỗ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Nút xóa chỉ hiển thị khi booking đã hủy
          if (booking.status == 'cancelled')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteBooking,
              tooltip: 'Xóa hợp đồng',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với trạng thái
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getStatusColor(booking.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: getStatusColor(booking.status)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event,
                    size: 48,
                    color: getStatusColor(booking.status),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đặt chỗ #${booking.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(booking.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      getStatusText(booking.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Thông tin bài viết đã đặt chỗ
            _buildSection(
              title: 'Thông tin bài viết',
              icon: Icons.home,
              children: [
                // Hình ảnh và thông tin cơ bản
                if (booking.rentalImage != null)
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: booking.rentalImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                _buildInfoRow(
                    'Tiêu đề', booking.rentalTitle ?? 'Không có tiêu đề'),
                _buildInfoRow(
                    'Địa chỉ', booking.rentalAddress ?? 'Không có địa chỉ'),
                if (booking.rentalPrice != null)
                  _buildInfoRow(
                      'Giá thuê', formatCurrency(booking.rentalPrice!)),
                if (booking.propertyType?.isNotEmpty == true)
                  _buildInfoRow('Loại bất động sản', booking.propertyType!),
                // Thêm thông tin chi tiết nếu có
                if (booking.rentalId.isNotEmpty)
                  _buildInfoRow(
                      'Mã bài viết', booking.rentalId.substring(0, 8)),

                // Thông tin diện tích
                if (booking.area != null)
                  _buildInfoRow('Diện tích tổng',
                      '${booking.area!['total']?.toString() ?? '0'} m²'),

                // Thông tin tiện ích
                if (booking.amenities?.isNotEmpty == true)
                  _buildInfoRow(
                      'Tiện ích',
                      booking.amenities!.take(3).join(', ') +
                          (booking.amenities!.length > 3 ? '...' : '')),

                // Thông tin nội thất
                if (booking.furniture?.isNotEmpty == true)
                  _buildInfoRow(
                      'Nội thất',
                      booking.furniture!.take(3).join(', ') +
                          (booking.furniture!.length > 3 ? '...' : '')),

                // Thông tin xung quanh
                if (booking.surroundings?.isNotEmpty == true)
                  _buildInfoRow(
                      'Xung quanh',
                      booking.surroundings!.take(3).join(', ') +
                          (booking.surroundings!.length > 3 ? '...' : '')),

                const SizedBox(height: 16),
                // Nút xem chi tiết bài viết
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToRentalDetail,
                    icon: const Icon(Icons.visibility, size: 20),
                    label: const Text(
                      'Xem chi tiết bài viết',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Thông tin chủ bài viết
            _buildSection(
              title: 'Thông tin chủ bài viết',
              icon: Icons.person_pin,
              children: [
                _buildInfoRow(
                    'Họ tên', booking.ownerName ?? 'Không có thông tin'),
                _buildInfoRow('Số điện thoại',
                    booking.ownerPhone ?? 'Không có thông tin'),
                if (booking.ownerEmail?.isNotEmpty == true)
                  _buildInfoRow('Email', booking.ownerEmail!),
                const SizedBox(height: 16),
                // Nút liên hệ chủ bài viết
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (booking.ownerPhone?.isNotEmpty == true) {
                              // Có thể mở ứng dụng gọi điện hoặc chat
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Liên hệ: ${booking.ownerPhone}'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text(
                            'Gọi điện',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (booking.ownerPhone?.isNotEmpty == true) {
                              // Có thể mở ứng dụng nhắn tin
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Nhắn tin: ${booking.ownerPhone}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.message, size: 20),
                          label: const Text(
                            'Nhắn tin',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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

            // Thông tin điều khoản thuê (nếu có)
            if (booking.rentalTerms != null && booking.rentalTerms!.isNotEmpty)
              _buildSection(
                title: 'Điều khoản thuê',
                icon: Icons.description,
                children: [
                  if (booking.rentalTerms!['minimumLease']?.isNotEmpty == true)
                    _buildInfoRow('Thời hạn thuê tối thiểu',
                        booking.rentalTerms!['minimumLease']),
                  if (booking.rentalTerms!['deposit']?.isNotEmpty == true)
                    _buildInfoRow('Tiền cọc', booking.rentalTerms!['deposit']),
                  if (booking.rentalTerms!['paymentMethod']?.isNotEmpty == true)
                    _buildInfoRow('Phương thức thanh toán',
                        booking.rentalTerms!['paymentMethod']),
                  if (booking.rentalTerms!['renewalTerms']?.isNotEmpty == true)
                    _buildInfoRow('Điều khoản gia hạn',
                        booking.rentalTerms!['renewalTerms']),
                ],
              ),
            if (booking.rentalTerms != null && booking.rentalTerms!.isNotEmpty)
              const SizedBox(height: 24),

            // Thông tin đặt chỗ
            _buildSection(
              title: 'Thông tin đặt chỗ',
              icon: Icons.event_note,
              children: [
                _buildInfoRow('Thời gian xem', booking.preferredViewingTime),
                _buildInfoRow('Ngày đặt chỗ', formatDate(booking.bookingDate)),
                _buildInfoRow('Ngày tạo', formatDate(booking.createdAt)),
                if (booking.updatedAt != booking.createdAt)
                  _buildInfoRow(
                      'Cập nhật lần cuối', formatDate(booking.updatedAt)),
              ],
            ),
            const SizedBox(height: 24),

            // Thông tin khách hàng
            _buildSection(
              title: 'Thông tin liên hệ',
              icon: Icons.person,
              children: [
                _buildInfoRow('Họ tên', booking.customerInfo['name'] ?? ''),
                _buildInfoRow(
                    'Số điện thoại', booking.customerInfo['phone'] ?? ''),
                _buildInfoRow('Email', booking.customerInfo['email'] ?? ''),
                if (booking.customerInfo['message']?.isNotEmpty == true)
                  _buildInfoRow('Ghi chú', booking.customerInfo['message']),
              ],
            ),
            const SizedBox(height: 24),

            // Ghi chú từ chủ nhà
            if (booking.ownerNotes.isNotEmpty)
              _buildSection(
                title: 'Ghi chú từ chủ nhà',
                icon: Icons.note,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      booking.ownerNotes,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Nút hủy đặt chỗ (chỉ hiển thị khi đang chờ xác nhận)
            if (booking.status == 'pending')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Hủy đặt chỗ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppStyles.titleText.copyWith(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
