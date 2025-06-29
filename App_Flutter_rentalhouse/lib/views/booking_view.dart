import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rental.dart';
import '../viewmodels/vm_booking.dart';
import '../viewmodels/vm_auth.dart';
import '../constants/app_color.dart';
import '../constants/app_style.dart';
import 'package:intl/intl.dart';

class BookingView extends StatefulWidget {
  final Rental rental;

  const BookingView({super.key, required this.rental});

  @override
  _BookingViewState createState() => _BookingViewState();
}

class _BookingViewState extends State<BookingView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedTime = 'Sáng (8:00 - 12:00)';
  final List<String> _timeSlots = [
    'Sáng (8:00 - 12:00)',
    'Chiều (13:00 - 17:00)',
    'Tối (18:00 - 21:00)',
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserInfo();
  }

  void _initializeUserInfo() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser != null) {
      final user = authViewModel.currentUser!;
      _nameController.text = user.username;
      _phoneController.text = user.phoneNumber;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
    return formatter.format(amount);
  }

  bool _isOwnRental() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    return authViewModel.currentUser?.id == widget.rental.userId;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bookingViewModel =
        Provider.of<BookingViewModel>(context, listen: false);

    final customerInfo = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'message': _messageController.text.trim(),
    };

    final success = await bookingViewModel.createBooking(
      rentalId: widget.rental.id,
      customerInfo: customerInfo,
      preferredViewingTime: _selectedTime,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Đặt chỗ thành công! Chủ nhà sẽ liên hệ với bạn sớm nhất.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingViewModel.errorMessage ?? 'Đặt chỗ thất bại'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra nếu là bài viết của chính mình
    if (_isOwnRental()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Đặt chỗ xem nhà'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 80,
                  color: Colors.orange[600],
                ),
                const SizedBox(height: 24),
                Text(
                  'Không thể đặt chỗ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bạn không thể đặt chỗ xem nhà cho bài viết của chính mình.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt chỗ xem nhà'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<BookingViewModel>(
        builder: (context, bookingViewModel, child) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thông tin nhà
                      _buildRentalInfo(),
                      const SizedBox(height: 24),

                      // Thông tin chủ bài viết
                      _buildOwnerInfo(),
                      const SizedBox(height: 24),

                      // Form đặt chỗ
                      _buildBookingForm(),
                      const SizedBox(height: 32),

                      // Nút đặt chỗ
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: bookingViewModel.isCreating
                              ? null
                              : _submitBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: bookingViewModel.isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Đặt chỗ ngay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Thông tin bổ sung
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sau khi đặt chỗ, chủ nhà sẽ liên hệ với bạn để xác nhận thời gian xem nhà cụ thể.',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (bookingViewModel.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRentalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin nhà',
                style: AppStyles.titleText.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.rental.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.rental.location['fullAddress'],
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.attach_money, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${formatCurrency(widget.rental.price)}/tháng',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Thông tin chủ nhà',
                style: AppStyles.titleText.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.rental.contactInfo['name']
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rental.contactInfo['name'] ?? 'Chủ nhà',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.rental.contactInfo['phone'] != null &&
                        widget.rental.contactInfo['phone'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            widget.rental.contactInfo['phone'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.rental.contactInfo['availableHours'] != null &&
                        widget.rental.contactInfo['availableHours']
                            .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Giờ liên hệ: ${widget.rental.contactInfo['availableHours']}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              'Thông tin liên hệ',
              style: AppStyles.titleText.copyWith(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Họ tên
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Họ và tên *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
            hintText: 'Nhập họ và tên đầy đủ',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập họ tên';
            }
            if (value.trim().length < 2) {
              return 'Họ tên phải có ít nhất 2 ký tự';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Số điện thoại
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
            hintText: 'Nhập số điện thoại 10 chữ số',
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập số điện thoại';
            }
            if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
              return 'Số điện thoại phải có 10 chữ số';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
            hintText: 'Nhập địa chỉ email',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
              return 'Email không hợp lệ';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Thời gian xem nhà
        DropdownButtonFormField<String>(
          value: _selectedTime,
          decoration: const InputDecoration(
            labelText: 'Thời gian xem nhà *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.schedule),
          ),
          items: _timeSlots.map((time) {
            return DropdownMenuItem(
              value: time,
              child: Text(time),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedTime = value!;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng chọn thời gian xem nhà';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Ghi chú
        TextFormField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (tùy chọn)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note),
            hintText: 'Nhập thông tin bổ sung nếu cần...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}
