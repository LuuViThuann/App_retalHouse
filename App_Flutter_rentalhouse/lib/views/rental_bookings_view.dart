import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/rental.dart';
import '../viewmodels/vm_booking.dart';
import '../constants/app_color.dart';
import '../constants/app_style.dart';
import 'package:intl/intl.dart';

class RentalBookingsView extends StatefulWidget {
  final Rental rental;

  const RentalBookingsView({super.key, required this.rental});

  @override
  _RentalBookingsViewState createState() => _RentalBookingsViewState();
}

class _RentalBookingsViewState extends State<RentalBookingsView> {
  String _selectedStatus = 'all';
  final List<String> _statusOptions = [
    'all',
    'pending',
    'confirmed',
    'rejected',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingViewModel =
          Provider.of<BookingViewModel>(context, listen: false);
      bookingViewModel.fetchRentalBookings(rentalId: widget.rental.id, page: 1);
    });
  }

  String _getStatusText(String status) {
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

  Color _getStatusColor(String status) {
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

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _updateBookingStatus(Booking booking) async {
    String? newStatus;
    String? notes;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: booking.status,
              decoration: const InputDecoration(
                labelText: 'Trạng thái',
                border: OutlineInputBorder(),
              ),
              items: ['pending', 'confirmed', 'rejected'].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_getStatusText(status)),
                );
              }).toList(),
              onChanged: (value) {
                newStatus = value;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
                hintText: 'Nhập ghi chú cho khách hàng...',
              ),
              maxLines: 3,
              onChanged: (value) {
                notes = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (newStatus != null) {
                _confirmUpdateStatus(booking, newStatus!, notes);
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUpdateStatus(
      Booking booking, String newStatus, String? notes) async {
    final bookingViewModel =
        Provider.of<BookingViewModel>(context, listen: false);
    final success = await bookingViewModel.updateBookingStatus(
      bookingId: booking.id,
      status: newStatus,
      ownerNotes: notes,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật trạng thái thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingViewModel.errorMessage ?? 'Cập nhật thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đặt chỗ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<BookingViewModel>(
        builder: (context, bookingViewModel, child) {
          return Column(
            children: [
              // Rental info
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rental.title,
                      style: AppStyles.titleText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.rental.location['fullAddress'],
                      style: AppStyles.subtitleText,
                    ),
                  ],
                ),
              ),

              // Filter
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Lọc theo: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Tất cả')),
                          ..._statusOptions
                              .where((status) => status != 'all')
                              .map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusText(status)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                          final status = value == 'all' ? null : value;
                          bookingViewModel.fetchRentalBookings(
                            rentalId: widget.rental.id,
                            page: 1,
                            status: status,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bookings list
              Expanded(
                child: bookingViewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : bookingViewModel.rentalBookings.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có đặt chỗ nào',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              final status = _selectedStatus == 'all'
                                  ? null
                                  : _selectedStatus;
                              await bookingViewModel.fetchRentalBookings(
                                rentalId: widget.rental.id,
                                page: 1,
                                status: status,
                                refresh: true,
                              );
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: bookingViewModel.rentalBookings.length,
                              itemBuilder: (context, index) {
                                final booking =
                                    bookingViewModel.rentalBookings[index];
                                return _buildBookingCard(
                                    booking, bookingViewModel);
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, BookingViewModel bookingViewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đặt chỗ #${booking.id.substring(0, 8)}',
                        style: AppStyles.titleText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Khách: ${booking.customerInfo['name']}',
                        style: AppStyles.subtitleText,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(booking.status)),
                  ),
                  child: Text(
                    _getStatusText(booking.status),
                    style: TextStyle(
                      color: _getStatusColor(booking.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Customer info
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  booking.customerInfo['phone'],
                  style: AppStyles.subtitleText,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  booking.customerInfo['email'],
                  style: AppStyles.subtitleText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Thời gian xem: ${booking.preferredViewingTime}',
                  style: AppStyles.subtitleText,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Đặt lúc: ${_formatDate(booking.createdAt)}',
                  style: AppStyles.subtitleText,
                ),
              ],
            ),

            if (booking.customerInfo['message']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ghi chú: ${booking.customerInfo['message']}',
                      style: AppStyles.subtitleText,
                    ),
                  ),
                ],
              ),
            ],

            if (booking.ownerNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ghi chú của bạn: ${booking.ownerNotes}',
                      style: AppStyles.subtitleText.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (booking.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cập nhật trạng thái'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
