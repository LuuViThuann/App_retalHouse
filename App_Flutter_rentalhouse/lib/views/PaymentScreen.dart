// views/payment_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String transactionCode;
  final int amount;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.transactionCode,
    required this.amount,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timeoutTimer;
  int _loadAttempts = 0;
  final int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(minutes: 15), () {
      if (mounted) {
        Navigator.pop(context, {
          'success': false,
          'message': 'Giao dịch đã hết hạn (15 phút)',
        });
      }
    });
  }

  void _initializeWebView() {
    debugPrint('🌐 Initializing WebView with payment URL');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('🌐 Page started: $url');
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            debugPrint('✅ Page finished: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WebView error: ${error.description}');

            if (_loadAttempts < _maxLoadAttempts &&
                (error.errorType == WebResourceErrorType.hostLookup ||
                    error.errorType == WebResourceErrorType.timeout ||
                    error.errorType == WebResourceErrorType.connect)) {
              _loadAttempts++;
              debugPrint(
                  '⚠️ Retrying... Attempt $_loadAttempts/$_maxLoadAttempts');

              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _controller.loadRequest(Uri.parse(widget.paymentUrl));
                }
              });
            } else if (_loadAttempts >= _maxLoadAttempts) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Không thể kết nối đến VNPay.\n'
                      'Vui lòng kiểm tra kết nối internet và thử lại.';
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔍 Navigation to: ${request.url}');

            // Cho phép WebView điều hướng bình thường tới trang VNPay
            if (request.url.contains('sandbox.vnpayment.vn') ||
                request.url.contains('vnpayment.vn')) {
              return NavigationDecision.navigate;
            }

            // Khi VNPay redirect về RETURN URL (có vnp_ResponseCode),
            // không verify hash ở client nữa, chỉ cần đóng WebView
            // và để caller tự gọi API backend để kiểm tra trạng thái.
            if (request.url.contains('vnp_ResponseCode')) {
              debugPrint('✅ Detected VNPay return URL - closing WebView');
              _timeoutTimer?.cancel();
              Navigator.pop(context, {
                'success': true,
                'returnUrl': request.url,
              });
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // Không còn xử lý/verify chữ ký VNPay ở Flutter.
  // Trạng thái thanh toán sẽ được kiểm tra qua API backend
  // sau khi WebView đóng lại.

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _showCancelDialog();
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán VNPay'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldClose = await _showCancelDialog();
              if (shouldClose == true && mounted) {
                _timeoutTimer?.cancel();
                Navigator.pop(context, {
                  'success': false,
                  'message': 'Đã hủy thanh toán',
                });
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới trang',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                    _loadAttempts = 0;
                  });
                }
                _controller.loadRequest(Uri.parse(widget.paymentUrl));
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _errorMessage = null;
                                  _isLoading = true;
                                  _loadAttempts = 0;
                                });
                              }
                              _controller
                                  .loadRequest(Uri.parse(widget.paymentUrl));
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              _timeoutTimer?.cancel();
                              Navigator.pop(context, {
                                'success': false,
                                'message': _errorMessage,
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Quay lại'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              WebViewWidget(controller: _controller),
            if (_isLoading && _errorMessage == null)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        'Đang tải trang thanh toán VNPay...',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng đợi trong giây lát',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_loadAttempts > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Đang thử lại... ($_loadAttempts/$_maxLoadAttempts)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showCancelDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy thanh toán?'),
        content: const Text(
          'Bạn có chắc muốn hủy giao dịch thanh toán này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }
}
