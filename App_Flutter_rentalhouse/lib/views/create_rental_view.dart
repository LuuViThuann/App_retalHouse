import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/MediaPickerWidget.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/area.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/contact_info.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/detail_create_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/info_basic_rental.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/location.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/rental_form.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/term_rental.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
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

  /// Handle payment với polling logic
  Future<void> _handlePaymentFirst() async {
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng điền đầy đủ thông tin bài đăng'),
      );
      return;
    }

    final totalMedia = _imagesNotifier.value.length + _videosNotifier.value.length;
    if (totalMedia == 0) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng chọn ít nhất một ảnh hoặc video'),
      );
      return;
    }

    if (totalMedia > 10) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Tối đa 10 ảnh/video được phép'),
      );
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

      final payment = await _paymentService.createPaymentTransaction(
        amount: 10000,
        description: 'Phí đăng bài bất động sản',
      );

      _currentPayment = payment;
      debugPrint('✅ Payment created: ${payment.transactionCode}');

      if (!mounted) return;

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

      debugPrint('\n⏰ Waiting 4 seconds for VNPay callback processing...');
      await Future.delayed(const Duration(seconds: 4));

      if (!mounted) return;

      debugPrint('\n🔍 Starting payment status polling...');
      await _pollAndProcessPayment(payment.transactionCode);

    } catch (e) {
      debugPrint('\n❌ Payment error: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi thanh toán: ${e.toString()}'),
        );
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

      if (paymentStatus == 'completed' || isCompleted == true) {
        debugPrint('\n✅ PAYMENT CONFIRMED SUCCESSFULLY!\n');

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

        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Thanh toán thành công! Đang đăng bài...',
            icon: Icons.check_circle_rounded,
            seconds: 3,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await _submitFormWithPayment();
        }
      } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
        debugPrint('\n❌ Payment failed or cancelled');
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Thanh toán thất bại hoặc đã bị hủy'),
        );
      } else {
        debugPrint('\n⚠️ Unexpected payment status: $paymentStatus');
        await _showManualCheckDialog(transactionCode);
      }
    } on Exception catch (e) {
      debugPrint('\n❌ Polling error: $e');

      if (e.toString().contains('Timeout')) {
        if (mounted) {
          final shouldRetry = await _showTimeoutDialog(transactionCode);
          if (shouldRetry == true && mounted) {
            await _pollAndProcessPayment(transactionCode);
          }
        }
      } else {
        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.error(message: 'Lỗi kiểm tra thanh toán: ${e.toString()}'),
          );
        }
      }
    }
  }

  /// Dialog khi timeout - Modern Banking Style
  Future<bool?> _showTimeoutDialog(String transactionCode) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: Colors.orange[700],
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Hết thời gian chờ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Không thể xác nhận trạng thái thanh toán.\nBạn muốn thử kiểm tra lại?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Transaction Code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        transactionCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Thử lại',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog yêu cầu check thủ công - Modern Banking Style
  Future<void> _showManualCheckDialog(String transactionCode) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue[700],
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Cần kiểm tra thủ công',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Không thể tự động xác nhận thanh toán.\n\nVui lòng kiểm tra trạng thái giao dịch trong lịch sử thanh toán.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Transaction Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 16,
                            color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Mã giao dịch',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      transactionCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Submit form with payment
  Future<void> _submitFormWithPayment() async {
    if (_completedPayment == null) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng thanh toán trước'),
      );
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final rentalViewModel = Provider.of<RentalViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Vui lòng đăng nhập'),
      );
      return;
    }

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

      await rentalViewModel.createRental(
        rental,
        _imagesNotifier.value.map((file) => file.path).toList(),
        videoPaths: _videosNotifier.value.map((file) => file.path).toList(),
      );

      if (!mounted) return;

      if (rentalViewModel.errorMessage == null) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Bài đăng đã được xuất bản thành công!',
            icon: Icons.celebration_rounded,
            seconds: 2,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: rentalViewModel.errorMessage ?? 'Lỗi tạo bài đăng',
          ),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi: $e'),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  /// Modern Banking Style Payment Confirmation Dialog
  Future<bool?> _showPaymentConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue[400]!, Colors.blue[700]!],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.payment_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Xác nhận thanh toán',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Để đăng bài, bạn cần thanh toán phí dịch vụ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Amount Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue[50]!, Colors.blue[100]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Số tiền thanh toán',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '10,000',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'đ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Info List
                _buildModernInfoRow(
                  Icons.schedule_rounded,
                  'Thời hạn',
                  '15 phút',
                ),
                const SizedBox(height: 12),
                _buildModernInfoRow(
                  Icons.account_balance_wallet_rounded,
                  'Phương thức',
                  'VNPay',
                ),
                const SizedBox(height: 12),
                _buildModernInfoRow(
                  Icons.check_circle_rounded,
                  'Kết quả',
                  'Tự động xuất bản',
                ),
                const SizedBox(height: 28),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue[700],
                          elevation: 0,
                          shadowColor: Colors.blue.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, size: 18 ,  color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Thanh toán',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
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

              // Payment Success Badge (Modern Banking Style)
              if (_completedPayment != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green[50]!, Colors.green[100]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[300]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Thanh toán thành công',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.verified_rounded,
                                  color: Colors.green,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 14,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _completedPayment!.transactionCode,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading State (Modern Banking Style)
              if (_isProcessingPayment || rentalViewModel.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[700]!,
                              ),
                            ),
                          ),
                          Icon(
                            _isProcessingPayment
                                ? Icons.payment_rounded
                                : Icons.cloud_upload_rounded,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isProcessingPayment
                            ? 'Đang xử lý thanh toán...'
                            : 'Đang tạo bài đăng...',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng không tắt ứng dụng',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              // Payment Button (Modern Banking Style)
              else if (_completedPayment == null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handlePaymentFirst,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 58),
                      backgroundColor: Colors.blue[700],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thanh toán và đăng bài',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Phí 10,000đ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              // Submit Button (Modern Banking Style)
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _submitFormWithPayment,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 58),
                      backgroundColor: Colors.green,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoàn tất đăng bài',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'Xuất bản ngay',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}