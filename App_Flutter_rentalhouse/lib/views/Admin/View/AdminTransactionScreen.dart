import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:lottie/lottie.dart';

class AdminTransactionScreen extends StatefulWidget {
  const AdminTransactionScreen({super.key});

  @override
  State<AdminTransactionScreen> createState() => _AdminTransactionScreenState();
}

class _AdminTransactionScreenState extends State<AdminTransactionScreen> {
  bool _isLoading = true;
  String? _error;

  // ✅ AuthService instance
  final AuthService _authService = AuthService();

  // Dashboard data
  int _totalRevenue = 0;
  int _revenueToday = 0;

  // Transactions data
  List<Map<String, dynamic>> _transactions = [];
  int _completedCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  /// ✅ FIX: Fetch both dashboard stats AND transaction details
  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get token
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Không tìm thấy token xác thực');
      }

      // Run both requests in parallel
      final results = await Future.wait([
        _fetchDashboardStats(token),
        _fetchPaymentHistory(token),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error ?? 'Có lỗi xảy ra'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: _fetchAllData,
            ),
          ),
        );
      }
    }
  }

  /// ✅ Fetch dashboard statistics (overview data)
  Future<void> _fetchDashboardStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.adminDashboard),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Dashboard Response Status: ${response.statusCode}');
      print('📊 Dashboard Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _totalRevenue = data['totalRevenue'] ?? 0;
          _revenueToday = data['revenueToday'] ?? 0;
        });

        print('✅ Dashboard stats loaded: total=$_totalRevenue, today=$_revenueToday');
      } else if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền truy cập');
      } else {
        throw Exception('Lỗi tải thống kê: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching dashboard: $e');
      rethrow;
    }
  }

  /// ✅ Fetch payment history (transaction details)
  Future<void> _fetchPaymentHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/vnpay/payment-history?page=1&limit=50'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('💳 Payment History Response Status: ${response.statusCode}');
      print('💳 Payment History Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ FIX: Handle various response structures
        List<dynamic> payments = [];

        if (data is Map<String, dynamic>) {
          payments = data['payments'] as List? ?? [];

          // Fallback if payments is not in the response
          if (payments.isEmpty && data['data'] != null) {
            payments = data['data'] as List? ?? [];
          }
        } else if (data is List) {
          payments = data;
        }

        print('💳 Found ${payments.length} payments');

        // ✅ Calculate statistics from payments
        int completedCount = 0;
        int pendingCount = 0;
        int failedCount = 0;

        for (var payment in payments) {
          if (payment is Map<String, dynamic>) {
            final status = payment['status'] as String? ?? 'unknown';

            if (status == 'completed') {
              completedCount++;
            } else if (status == 'processing') {
              pendingCount++;
            } else if (status == 'failed') {
              failedCount++;
            }
          }
        }

        setState(() {
          _transactions = List<Map<String, dynamic>>.from(
              payments.whereType<Map<String, dynamic>>()
          );
          _completedCount = completedCount;
          _pendingCount = pendingCount;
          _failedCount = failedCount;
        });

        print('✅ Payment history loaded: completed=$completedCount, pending=$pendingCount, failed=$failedCount');
      } else if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn');
      } else if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền truy cập');
      } else {
        throw Exception('Lỗi tải giao dịch: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      rethrow;
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)}₫';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Doanh thu & Giao dịch',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: const Color(0xFF1F2937),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _isLoading ? null : _fetchAllData,
          ),
        ],
      ),
      body: _isLoading
          ?  Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                AssetsConfig.loadingLottie,
                width: 80,
                height: 80,
                fit: BoxFit.fill,
              ),
              SizedBox(height: 16),
              Text(
                'Đang tải dữ liệu...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),)
            ],
          )
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                'Có lỗi xảy ra',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchAllData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchAllData,
        color: const Color(0xFFDC2626),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Row 1
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Tổng doanh thu',
                      _formatCurrency(_totalRevenue),
                      Icons.trending_up_rounded,
                      const Color(0xFF06B6D4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'Doanh thu hôm nay',
                      _formatCurrency(_revenueToday),
                      Icons.today_rounded,
                      const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary Cards Row 2
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Giao dịch thành công',
                      '$_completedCount',
                      Icons.check_circle_rounded,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'Đang xử lý',
                      '$_pendingCount',
                      Icons.hourglass_bottom_rounded,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary Cards Row 3
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Thất bại',
                      '$_failedCount',
                      Icons.cancel_rounded,
                      const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'Tổng giao dịch',
                      '${_completedCount + _pendingCount + _failedCount}',
                      Icons.receipt_long_rounded,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transactions List Header
              const Text(
                'Danh sách giao dịch gần đây',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),

              // Transactions List
              _transactions.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có giao dịch nào',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  return _buildTransactionCard(
                    _transactions[index],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    // ✅ FIX: Safe access with null coalescing
    final status = transaction['status'] as String? ?? 'unknown';
    final amount = transaction['amount'] as int? ?? 0;
    final transactionCode = transaction['transactionCode'] as String? ?? 'N/A';
    final createdAt = transaction['createdAt'] as String?;
    final bankCode = transaction['bankCode'] as String?;

    // Status styling
    final statusColor = status == 'completed'
        ? const Color(0xFF10B981)
        : status == 'processing'
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    final statusText = status == 'completed'
        ? 'Thành công'
        : status == 'processing'
        ? 'Đang xử lý'
        : 'Thất bại';

    final statusIcon = status == 'completed'
        ? Icons.check_circle_rounded
        : status == 'processing'
        ? Icons.hourglass_bottom_rounded
        : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transactionCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${bankCode ?? 'Không xác định'} • ${_formatDateTime(createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}