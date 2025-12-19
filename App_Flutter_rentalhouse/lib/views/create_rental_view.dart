// views/create_rental_screen.dart - FINAL FIX
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/MediaPickerWidget.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/area.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/contact_info.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/detail_create_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/info_basic_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/location.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/rental_form.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/term_rental.dart';
import 'package:flutter_rentalhouse/views/PaymentScreen.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/Payment_service.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_rental.dart';
import '../models/payment.dart';
import '../Widgets/Detail/full_screen_image.dart';

class CreateRentalScreen extends StatefulWidget {
  const CreateRentalScreen({super.key});

  @override
  State<CreateRentalScreen> createState() => _CreateRentalScreenState();
}

class _CreateRentalScreenState extends State<CreateRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final FormStateManager _formStateManager;
  final PaymentService _paymentService = PaymentService();

  // Payment state
  Payment? _completedPayment;
  Payment? _currentPayment;
  bool _isProcessingPayment = false;

  // Form state
  final ValueNotifier<List<File>> _imagesNotifier = ValueNotifier<List<File>>([]);
  final ValueNotifier<List<File>> _videosNotifier = ValueNotifier<List<File>>([]);
  final ValueNotifier<String?> _propertyTypeNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>('Đang hoạt động');
  final ValueNotifier<double?> _latitudeNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<double?> _longitudeNotifier = ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _formStateManager = FormStateManager(
      authViewModel: Provider.of<AuthViewModel>(context, listen: false),
    );
  }

  @override
  void dispose() {
    _formStateManager.dispose();
    _imagesNotifier.dispose();
    _videosNotifier.dispose();
    _propertyTypeNotifier.dispose();
    _statusNotifier.dispose();
    _latitudeNotifier.dispose();
    _longitudeNotifier.dispose();
    super.dispose();
  }

  /// Handle payment với polling logic mới
  Future<void> _handlePaymentFirst() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Vui lòng điền đầy đủ thông tin bài đăng');
      return;
    }

    final totalMedia = _imagesNotifier.value.length + _videosNotifier.value.length;
    if (totalMedia == 0) {
      _showErrorSnackBar('Vui lòng chọn ít nhất một ảnh hoặc video');
      return;
    }

    if (totalMedia > 10) {
      _showErrorSnackBar('Tối đa 10 ảnh/video được phép');
      return;
    }

    final shouldProceed = await _showPaymentConfirmDialog();
    if (shouldProceed != true) return;

    if (!mounted) return;
    setState(() => _isProcessingPayment = true);

    try {
      debugPrint('\n' + '=' * 60);
      debugPrint('🚀 STARTING PAYMENT FLOW');
      debugPrint('=' * 60);

      // Step 1: Create payment
      final payment = await _paymentService.createPaymentTransaction(
        amount: 10000,
        description: 'Phí đăng bài bất động sản',
      );

      _currentPayment = payment;
      debugPrint('✅ Payment created: ${payment.transactionCode}');

      if (!mounted) return;

      // Step 2: Show WebView
      debugPrint('\n📱 Opening payment WebView...');
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewScreen(
            paymentUrl: payment.paymentUrl!,
            transactionCode: payment.transactionCode,
            amount: payment.amount,
          ),
        ),
      );

      if (!mounted) return;

      debugPrint('\n🔙 WebView closed');
      debugPrint('   Result: $result');

      // Step 3: Đợi một chút để VNPay callback xử lý
      debugPrint('\n⏰ Waiting 4 seconds for VNPay callback processing...');
      await Future.delayed(const Duration(seconds: 4));

      if (!mounted) return;

      // Step 4: Poll payment status với logic mới
      debugPrint('\n🔍 Starting payment status polling...');
      await _pollAndProcessPayment(payment.transactionCode);

    } catch (e) {
      debugPrint('\n❌ Payment error: $e');
      if (mounted) {
        _showErrorSnackBar('Lỗi thanh toán: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  /// Poll payment status và xử lý kết quả
  Future<void> _pollAndProcessPayment(String transactionCode) async {
    if (!mounted) return;

    try {
      // Sử dụng pollPaymentStatus từ PaymentService
      final status = await _paymentService.pollPaymentStatus(
        transactionCode: transactionCode,
        maxAttempts: 15,
        delayBetweenAttempts: const Duration(seconds: 3),
      );

      if (!mounted) return;

      final paymentStatus = status['status'] as String? ?? '';
      final isCompleted = status['isCompleted'] as bool? ?? false;

      debugPrint('\n📊 Final payment status:');
      debugPrint('   Status: $paymentStatus');
      debugPrint('   Is completed: $isCompleted');
      debugPrint('   Response code: ${status['responseCode']}');
      debugPrint('   Bank: ${status['bankCode']}');

      if (paymentStatus == 'completed' || isCompleted == true) {
        // ✅ THANH TOÁN THÀNH CÔNG
        debugPrint('\n' + '🎉' * 20);
        debugPrint('✅ PAYMENT CONFIRMED SUCCESSFULLY!');
        debugPrint('🎉' * 20 + '\n');

        if (mounted) {
          setState(() {
            _completedPayment = _currentPayment!.copyWith(
              status: 'completed',
              completedAt: DateTime.now(),
              vnpayTransactionId: status['transactionNo'] as String?,
              responseCode: status['responseCode'] as String?,
              bankCode: status['bankCode'] as String?,
              bankTranNo: status['bankTranNo'] as String?,
            );
          });
        }

        _showSuccessSnackBar('✅ Thanh toán thành công! Đang đăng bài...');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await _submitFormWithPayment();
        }
      } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
        // ❌ THANH TOÁN THẤT BẠI
        debugPrint('\n❌ Payment failed or cancelled');
        _showErrorSnackBar('Thanh toán thất bại hoặc đã bị hủy.');
      } else {
        // ⚠️ Trạng thái không xác định
        debugPrint('\n⚠️ Unexpected payment status: $paymentStatus');
        await _showManualCheckDialog(transactionCode);
      }
    } on Exception catch (e) {
      debugPrint('\n❌ Polling error: $e');

      if (e.toString().contains('Timeout')) {
        // Timeout - cho phép retry
        if (mounted) {
          final shouldRetry = await _showTimeoutDialog(transactionCode);
          if (shouldRetry == true && mounted) {
            await _pollAndProcessPayment(transactionCode);
          }
        }
      } else {
        // Lỗi khác
        if (mounted) {
          _showErrorSnackBar('Lỗi kiểm tra thanh toán: ${e.toString()}');
        }
      }
    }
  }

  /// Dialog khi timeout
  Future<bool?> _showTimeoutDialog(String transactionCode) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.access_time, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text('Hết thời gian chờ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Không thể xác nhận trạng thái thanh toán.\n\n'
                  'Bạn muốn thử kiểm tra lại?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                'Mã GD: $transactionCode',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog yêu cầu check thủ công
  Future<void> _showManualCheckDialog(String transactionCode) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cần kiểm tra thủ công'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Không thể tự động xác nhận thanh toán.\n\n'
                  'Vui lòng kiểm tra trạng thái giao dịch trong lịch sử thanh toán.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: SelectableText(
                'Mã GD: $transactionCode',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.blue[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  /// Submit form with payment
  Future<void> _submitFormWithPayment() async {
    if (_completedPayment == null) {
      _showErrorSnackBar('Vui lòng thanh toán trước');
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập');
      return;
    }

    debugPrint('\n' + '🏠' * 20);
    debugPrint('🚀 SUBMITTING RENTAL POST');
    debugPrint('🏠' * 20);
    debugPrint('Payment Code: ${_completedPayment!.transactionCode}');
    debugPrint('Payment Status: ${_completedPayment!.status}');
    debugPrint('User: ${authViewModel.currentUser!.id}');

    final rental = _formStateManager.buildRental(
      images: _imagesNotifier.value.map((file) => file.path).toList(),
      videos: _videosNotifier.value.map((file) => file.path).toList(),
      propertyType: _propertyTypeNotifier.value ?? 'Khác',
      status: _statusNotifier.value == 'Đang hoạt động' ? 'available' : 'rented',
      userId: authViewModel.currentUser!.id,
      latitude: _latitudeNotifier.value,
      longitude: _longitudeNotifier.value,
      paymentTransactionCode: _completedPayment!.transactionCode,
    );

    try {
      if (mounted) {
        setState(() => _isProcessingPayment = true);
      }

      debugPrint('\n📤 Calling createRental API...');

      await rentalViewModel.createRental(
        rental,
        _imagesNotifier.value.map((file) => file.path).toList(),
        videoPaths: _videosNotifier.value.map((file) => file.path).toList(),
      );

      if (!mounted) return;

      if (rentalViewModel.errorMessage == null) {
        debugPrint('\n' + '✅' * 20);
        debugPrint('🎉 RENTAL POSTED SUCCESSFULLY!');
        debugPrint('✅' * 20 + '\n');

        _showSuccessSnackBar('✅ Bài đăng đã được xuất bản thành công!');

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        debugPrint('\n❌ Rental creation failed:');
        debugPrint('   Error: ${rentalViewModel.errorMessage}');

        _showErrorSnackBar(
          rentalViewModel.errorMessage ?? 'Lỗi tạo bài đăng',
        );
      }
    } catch (e) {
      debugPrint('\n❌ Exception creating rental: $e');
      _showErrorSnackBar('Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  Future<bool?> _showPaymentConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.payment, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Thanh toán phí đăng bài',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Để đăng bài, bạn cần thanh toán:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Phí đăng bài:'),
                      Text(
                        '10,000 đ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Thời hạn: 15 phút'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.payment, 'Phương thức: VNPay'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.check_circle, 'Bài đăng tự động xuất bản'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.payment, size: 20),
            label: const Text('Thanh toán'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: const Text(
          "Tạo bài đăng mới",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 19,
          ),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              BasicInfoForm(
                titleController: _formStateManager.titleController!,
                priceController: _formStateManager.priceController!,
                statusNotifier: _statusNotifier,
              ),
              AreaForm(
                totalController: _formStateManager.areaTotalController!,
                livingRoomController: _formStateManager.areaLivingRoomController!,
                bedroomsController: _formStateManager.areaBedroomsController!,
                bathroomsController: _formStateManager.areaBathroomsController!,
              ),
              LocationForm(
                shortController: _formStateManager.locationShortController!,
                fullAddressController: _formStateManager.locationFullAddressController!,
                latitudeNotifier: _latitudeNotifier,
                longitudeNotifier: _longitudeNotifier,
              ),
              PropertyDetailsForm(
                propertyTypeNotifier: _propertyTypeNotifier,
                furnitureController: _formStateManager.furnitureController!,
                amenitiesController: _formStateManager.amenitiesController!,
                surroundingsController: _formStateManager.surroundingsController!,
              ),
              RentalTermsForm(
                minimumLeaseController: _formStateManager.rentalTermsMinimumLeaseController!,
                depositController: _formStateManager.rentalTermsDepositController!,
                paymentMethodController: _formStateManager.rentalTermsPaymentMethodController!,
                renewalTermsController: _formStateManager.rentalTermsRenewalTermsController!,
              ),
              ContactInfoForm(
                nameController: _formStateManager.contactInfoNameController!,
                phoneController: _formStateManager.contactInfoPhoneController!,
                availableHoursController: _formStateManager.contactInfoAvailableHoursController!,
              ),
              MediaPickerWidget(
                imagesNotifier: _imagesNotifier,
                videosNotifier: _videosNotifier,
                onMediaTap: (file) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageScreen(imageUrl: file.path),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              if (_completedPayment != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[50]!, Colors.green[100]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✅ Đã thanh toán',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mã: ${_completedPayment!.transactionCode}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isProcessingPayment || rentalViewModel.isLoading)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _isProcessingPayment
                            ? 'Đang xử lý thanh toán...'
                            : 'Đang tạo bài đăng...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_completedPayment == null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text(
                    'Thanh toán và đăng bài',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _handlePaymentFirst,
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text(
                    'Hoàn tất đăng bài',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitFormWithPayment,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}