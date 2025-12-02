
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';

class UserFeedbackScreen extends StatefulWidget {
  const UserFeedbackScreen({super.key});

  @override
  State<UserFeedbackScreen> createState() => _UserFeedbackScreenState();
}

class _UserFeedbackScreenState extends State<UserFeedbackScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<File> _attachments = [];
  String _selectedType = 'suggestion';
  int _rating = 5;
  bool _isLoading = false;
  List<Map<String, dynamic>> _myFeedbacks = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyFeedbacks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  final Color primary = const Color(0xFF1565C0);

  Future<void> _loadMyFeedbacks() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        debugPrint('❌ Token is null');
        return;
      }

      debugPrint('✅ Loading feedbacks with token: ${token.substring(0, 30)}...');

      final response = await http
          .get(
        Uri.parse(ApiRoutes.myFeedback),
        headers: {'Authorization': 'Bearer $token'},
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 Load response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() =>
        _myFeedbacks = List<Map<String, dynamic>>.from(data['data'] ?? []));
        debugPrint('✅ Loaded ${_myFeedbacks.length} feedbacks');
      } else {
        debugPrint('❌ Failed to load feedbacks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Load feedback error: $e');
    }
  }

  Future<void> _pickAttachments() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _attachments.addAll(files.map((f) => File(f.path))));
    }
  }

  Future<void> _submitFeedback() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      _showErrorSnackBar('Vui lòng nhập tiêu đề và nội dung');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        _showErrorSnackBar('Không thể lấy token xác thực');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('📤 Submitting feedback...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiRoutes.feedback),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = _titleController.text.trim();
      request.fields['content'] = _contentController.text.trim();
      request.fields['feedbackType'] = _selectedType;
      request.fields['rating'] = _rating.toString();

      for (var file in _attachments) {
        debugPrint('📎 Adding file: ${file.path}');
        request.files.add(
          await http.MultipartFile.fromPath('attachments', file.path),
        );
      }

      debugPrint('⏳ Sending request with ${_attachments.length} attachments...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Gửi phản hồi quá lâu, vui lòng thử lại');
        },
      );

      debugPrint('📊 Response status: ${streamedResponse.statusCode}');

      final response =
      await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('📋 Response body: ${response.body}');

      if (response.statusCode == 201) {
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _attachments.clear();
          _selectedType = 'suggestion';
          _rating = 5;
        });

        _showSuccessSnackBar(
            'Gửi thành công! Cảm ơn bạn đã góp ý, chúng tôi sẽ xem xét sớm');
        debugPrint('✅ Feedback sent successfully');

        await _loadMyFeedbacks();
        _tabController.animateTo(1);
      } else if (response.statusCode == 401) {
        _showErrorSnackBar('Token hết hạn, vui lòng đăng nhập lại');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(
            'Lỗi: ${errorData['message'] ?? 'Dữ liệu không hợp lệ'}');
      } else {
        _showErrorSnackBar('Lỗi gửi phản hồi (${response.statusCode})');
      }
    } on TimeoutException catch (e) {
      _showErrorSnackBar(e.message ?? 'Yêu cầu hết thời gian chờ');
      debugPrint('❌ Timeout: $e');
    } catch (e) {
      _showErrorSnackBar('Lỗi: $e');
      debugPrint('❌ Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bug':
        return 'Báo lỗi';
      case 'suggestion':
        return 'Góp ý';
      case 'complaint':
        return 'Khiếu nại';
      case 'other':
        return 'Khác';
      default:
        return type;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chưa xử lý';
      case 'reviewing':
        return 'Đang xem xét';
      case 'resolved':
        return 'Đã giải quyết';
      case 'closed':
        return 'Đã đóng';
      default:
        return status;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Phản hồi ứng dụng',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: 'Gửi phản hồi'),
            Tab(text: 'Lịch sử'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==================== GỬI PHẢN HỒI ====================
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                TextField(
                  controller: _titleController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Tiêu đề phản hồi',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      disabledHint: Text(
                        _getTypeLabel(_selectedType),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          color: primary),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        {'value': 'suggestion', 'label': 'Góp ý cải thiện'},
                        {'value': 'bug', 'label': 'Báo lỗi'},
                        {'value': 'complaint', 'label': 'Khiếu nại'},
                        {'value': 'other', 'label': 'Khác'},
                      ]
                          .map((item) => DropdownMenuItem(
                        value: item['value'] as String,
                        child: Text(item['label'] as String),
                      ))
                          .toList(),
                      onChanged:
                      _isLoading
                          ? null
                          : (value) =>
                          setState(() => _selectedType = value!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Column(
                  children: [
                    Text('Đánh giá của bạn',
                        style:
                        TextStyle(color: Colors.grey[700], fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                            (i) => GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              i < _rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 44,
                              color: i < _rating
                                  ? Colors.amber
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _contentController,
                  enabled: !_isLoading,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: 'Mô tả chi tiết ý kiến của bạn...',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickAttachments,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      _attachments.isEmpty
                          ? 'Thêm ảnh minh họa (tùy chọn)'
                          : 'Đã chọn ${_attachments.length} ảnh',
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _attachments.map((f) {
                        final fileName = f.path.split('/').last;
                        return Chip(
                          backgroundColor: primary.withOpacity(0.08),
                          label: Text(
                            fileName.length > 20
                                ? '${fileName.substring(0, 20)}...'
                                : fileName,
                            style: TextStyle(
                              fontSize: 13,
                              color: primary,
                            ),
                          ),
                          deleteIconColor: primary,
                          onDeleted: _isLoading
                              ? null
                              : () =>
                              setState(() => _attachments.remove(f)),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Text(
                      'GỬI PHẢN HỒI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ==================== LỊCH SỬ PHẢN HỒI ====================
          _myFeedbacks.isEmpty
              ? const Center(
            child: Text('Chưa có phản hồi nào',
                style:
                TextStyle(fontSize: 16, color: Colors.grey)),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _myFeedbacks.length,
            itemBuilder: (_, i) {
              final fb = _myFeedbacks[i];
              final statusColor = _getStatusColor(fb['status']);
              final attachments =
              List<String>.from(fb['attachments'] ?? []);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  title: Text(fb['title'] ?? 'Không có tiêu đề',
                      style:
                      const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusLabel(fb['status']),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('⭐ ${fb['rating']}/5',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fb['content'] ?? '',
                              style:
                              const TextStyle(height: 1.5)),

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
                                    // Mở full screen
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

                          if (fb['adminResponse'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.reply,
                                          size: 18, color: primary),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Phản hồi từ đội ngũ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(fb['adminResponse']),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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