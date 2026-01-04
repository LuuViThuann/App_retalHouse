// lib/views/Admin/View/ManageFeedbackScreen.dart - MODERN DESIGN
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

  Future<void> _updateFeedbackStatus(String feedbackId, String newStatus) async {
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
    }
  }

  Future<void> _deleteFeedback(String feedbackId, String feedbackTitle) async {
    if (_token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/admin/feedback/$feedbackId'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Đã xóa feedback: $feedbackTitle');
        await _loadFeedbacks();
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('Token hết hạn');
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('Không tìm thấy feedback');
      } else {
        _showErrorSnackBar('Lỗi: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi xóa: $e');
    }
  }

  void _showDeleteConfirmDialog(String feedbackId, String feedbackTitle) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Xóa feedback?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bạn có chắc muốn xóa feedback "$feedbackTitle"?\n\nDữ liệu có thể hoàn tác trong 7 ngày.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteFeedback(feedbackId, feedbackTitle);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

  List<String> _parseAttachments(dynamic attachmentsData) {
    if (attachmentsData == null) return [];

    if (attachmentsData is List) {
      final result = <String>[];
      for (final item in attachmentsData) {
        if (item is String && item.isNotEmpty) {
          result.add(item);
        } else if (item is Map) {
          final url = item['url'] ??
              item['cloudinaryUrl'] ??
              item['path'] ??
              item['filename'] ??
              '';
          if (url is String && url.isNotEmpty) {
            result.add(url);
          }
        }
      }
      return result;
    }

    return [];
  }

  bool _isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com') || url.contains('res.cloudinary.com');
  }

  String _optimizeCloudinaryUrl(String url) {
    if (!_isCloudinaryUrl(url)) {
      return url;
    }

    if (url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/w_800,h_800,c_limit,q_auto/');
    }
    return url;
  }

  String _getStatusText(String status) => _statusMap[status] ?? status;
  String _getTypeText(String type) => _feedbackTypeMap[type] ?? type;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFA500);
      case 'reviewing':
        return const Color(0xFF2196F3);
      case 'resolved':
        return const Color(0xFF4CAF50);
      case 'closed':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Quản lý phản hồi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ✅ FILTER SECTION - MODERN DESIGN
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bộ lọc',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernDropdown(
                        value: _selectedStatus,
                        items: [
                          'all',
                          'pending',
                          'reviewing',
                          'resolved',
                          'closed'
                        ],
                        getLabel: (val) => val == 'all'
                            ? 'Tất cả trạng thái'
                            : _getStatusText(val),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                            _currentPage = 1;
                          });
                          _loadFeedbacks();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernDropdown(
                        value: _selectedType,
                        items: ['all', 'bug', 'suggestion', 'complaint', 'other'],
                        getLabel: _getTypeText,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                            _currentPage = 1;
                          });
                          _loadFeedbacks();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ✅ FEEDBACK LIST
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2196F3)))
                : _feedbacks.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Không có phản hồi nào',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: _feedbacks.length,
              itemBuilder: (context, index) {
                final feedback = _feedbacks[index];
                final attachments =
                _parseAttachments(feedback['attachments']);

                return _buildFeedbackCard(
                  feedback,
                  attachments,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDropdown({
    required String value,
    required List<String> items,
    required String Function(String) getLabel,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        items: items
            .map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            getLabel(item),
            style: const TextStyle(fontSize: 14),
          ),
        ))
            .toList(),
        onChanged: (val) => val != null ? onChanged(val) : null,
      ),
    );
  }

  Widget _buildFeedbackCard(
      Map<String, dynamic> feedback,
      List<String> attachments,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feedback['title'] ?? 'Không có tiêu đề',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(feedback['status'])
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(feedback['status']),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(feedback['status']),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '⭐ ${feedback['rating'] ?? 3}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Người gửi',
                      '${feedback['userName']} (${feedback['userEmail']})'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Loại',
                      _getTypeText(feedback['feedbackType'])),
                  const SizedBox(height: 12),
                  const Text(
                    'Nội dung:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedback['content'] ?? 'Không có nội dung',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  // ✅ ATTACHMENTS SECTION
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ảnh đính kèm:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: attachments.length,
                      itemBuilder: (_, idx) {
                        final imgUrl = attachments[idx];
                        final displayUrl = _isCloudinaryUrl(imgUrl)
                            ? _optimizeCloudinaryUrl(imgUrl)
                            : '${ApiRoutes.rootUrl}$imgUrl';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FullScreenImage(imageUrl: displayUrl),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              displayUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.broken_image,
                                    color: Colors.grey[400]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ✅ STATUS UPDATE & DELETE ACTIONS
                  _buildActionSection(feedback),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection(Map<String, dynamic> feedback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cập nhật trạng thái:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: feedback['status'],
            underline: const SizedBox(),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            items: ['pending', 'reviewing', 'resolved', 'closed']
                .map((status) => DropdownMenuItem(
              value: status,
              child: Text(
                _getStatusText(status),
                style: const TextStyle(fontSize: 13),
              ),
            ))
                .toList(),
            onChanged: (newStatus) {
              if (newStatus != null && newStatus != feedback['status']) {
                _updateFeedbackStatus(feedback['_id'], newStatus);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteConfirmDialog(
              feedback['_id'],
              feedback['title'] ?? 'Feedback',
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Xóa Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.red.shade200, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ Full Screen Image Viewer
class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 64,
          ),
        ),
      ),
    );
  }
}