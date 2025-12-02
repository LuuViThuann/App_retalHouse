// lib/views/Admin/View/ManageFeedbackScreen.dart - CẬP NHẬT HIỂN THỊ ATTACHMENTS
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';

class ManageFeedbackScreen extends StatefulWidget {
  const ManageFeedbackScreen({super.key});

  @override
  State<ManageFeedbackScreen> createState() => _ManageFeedbackScreenState();
}

class _ManageFeedbackScreenState extends State<ManageFeedbackScreen> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = false;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  int _currentPage = 1;
  String? _token;

  static const Map<String, String> _feedbackTypeMap = {
    'all': 'Tất cả loại',
    'bug': 'Lỗi hệ thống',
    'suggestion': 'Góp ý cải tiến',
    'complaint': 'Khiếu nại',
    'other': 'Khác',
  };

  static const Map<String, String> _statusMap = {
    'pending': 'Chưa xử lý',
    'reviewing': 'Đang xem xét',
    'resolved': 'Đã giải quyết',
    'closed': 'Đã đóng',
  };

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    _token = await Provider.of<AuthService>(context, listen: false).getIdToken();
    if (_token != null) {
      await _loadFeedbacks();
    } else {
      _showErrorSnackBar('Không thể lấy token xác thực');
    }
  }

  Future<void> _loadFeedbacks() async {
    if (_token == null) return;

    setState(() => _isLoading = true);

    try {
      String url =
          '${ApiRoutes.baseUrl}/admin/feedback?page=$_currentPage&limit=20';
      if (_selectedStatus != 'all') {
        url += '&status=$_selectedStatus';
      }
      if (_selectedType != 'all') {
        url += '&feedbackType=$_selectedType';
      }

      debugPrint('📡 Fetching feedbacks from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _feedbacks = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
        debugPrint('✅ Loaded ${_feedbacks.length} feedbacks');
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('Token hết hạn');
      } else if (response.statusCode == 403) {
        _showErrorSnackBar('Bạn không có quyền admin');
      } else {
        _showErrorSnackBar('Lỗi tải feedback: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi: $e');
      debugPrint('❌ Load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFeedbackStatus(
      String feedbackId,
      String newStatus,
      ) async {
    if (_token == null) return;

    try {
      final response = await http.patch(
        Uri.parse('${ApiRoutes.baseUrl}/admin/feedback/$feedbackId/status'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 Update response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Cập nhật trạng thái thành công');
        await _loadFeedbacks();
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('Token hết hạn');
      } else {
        _showErrorSnackBar('Lỗi: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi: $e');
      debugPrint('❌ Update error: $e');
    }
  }

  String _getStatusText(String status) => _statusMap[status] ?? status;
  String _getTypeText(String type) => _feedbackTypeMap[type] ?? type;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewing':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý phản hồi người dùng'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Bộ lọc
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    hint: const Text('Chọn trạng thái'),
                    items: [
                      'all',
                      'pending',
                      'reviewing',
                      'resolved',
                      'closed'
                    ]
                        .map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status == 'all'
                            ? 'Tất cả trạng thái'
                            : _getStatusText(status)),
                      );
                    })
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                          _currentPage = 1;
                        });
                        _loadFeedbacks();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    hint: const Text('Chọn loại'),
                    items: ['all', 'bug', 'suggestion', 'complaint', 'other']
                        .map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeText(type)),
                      );
                    })
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                          _currentPage = 1;
                        });
                        _loadFeedbacks();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Danh sách
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _feedbacks.isEmpty
                ? const Center(child: Text('Không có phản hồi nào'))
                : ListView.builder(
              itemCount: _feedbacks.length,
              itemBuilder: (context, index) {
                final feedback = _feedbacks[index];
                final attachments =
                List<String>.from(feedback['attachments'] ?? []);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  elevation: 3,
                  child: ExpansionTile(
                    title: Text(
                      feedback['title'] ?? 'Không có tiêu đề',
                      style:
                      const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(feedback['status'])
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(feedback['status']),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(
                                  feedback['status']),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loại: ${_getTypeText(feedback['feedbackType'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '⭐ ${feedback['rating'] ?? 3}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Từ: ${feedback['userName']} (${feedback['userEmail']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Nội dung:'),
                            const SizedBox(height: 8),
                            Text(
                              feedback['content'] ??
                                  'Không có nội dung',
                            ),

                            // ✅ HIỂN THỊ ATTACHMENTS
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Ảnh đính kèm:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: attachments.length,
                                itemBuilder: (_, idx) {
                                  final imgUrl = attachments[idx];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FullScreenImage(
                                                imageUrl:
                                                '${ApiRoutes.rootUrl}$imgUrl',
                                              ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      child: Image.network(
                                        '${ApiRoutes.rootUrl}$imgUrl',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                            Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                              ),
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],

                            const SizedBox(height: 16),
                            const Text(
                              'Cập nhật trạng thái:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: feedback['status'],
                              items: [
                                'pending',
                                'reviewing',
                                'resolved',
                                'closed'
                              ]
                                  .map((status) =>
                                  DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                        _getStatusText(status)),
                                  ))
                                  .toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null &&
                                    newStatus !=
                                        feedback['status']) {
                                  _updateFeedbackStatus(
                                    feedback['_id'],
                                    newStatus,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Widget để xem ảnh full screen
class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 64,
          ),
        ),
      ),
    );
  }
}