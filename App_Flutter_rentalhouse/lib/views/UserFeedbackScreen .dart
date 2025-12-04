import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/constants/app_color.dart';
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
  // Controller & Variables
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<File> _attachments = [];
  String _selectedType = 'suggestion';
  int _rating = 5;
  bool _isLoading = false;

  // List & Selection
  List<Map<String, dynamic>> _myFeedbacks = [];
  List<Map<String, dynamic>> _deletedFeedbacks = [];
  bool _isSelectionMode = false;
  final Set<String> _selectedFeedbackIds = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          if (_isSelectionMode) _cancelSelection();
        });
      }
    });

    _loadMyFeedbacks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ================= API METHODS =================

  Future<void> _loadMyFeedbacks() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiRoutes.myFeedback),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _myFeedbacks = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isSelectionMode = false;
            _selectedFeedbackIds.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Load feedback error: $e');
    }
  }

  // ================= DELETED FEEDBACKS =================

  Future<void> _loadDeletedFeedbacks() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiRoutes.rootUrl}/api/feedback/deleted/list'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _deletedFeedbacks =
            List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Load deleted feedbacks error: $e');
    }
  }

  Future<void> _restoreFeedback(String feedbackId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        AppSnackBar.show(context, AppSnackBar.error(message: 'Lỗi xác thực'));
        return;
      }

      setState(() => _isLoading = true);

      final response = await http.post(
        Uri.parse('${ApiRoutes.rootUrl}/api/feedback/$feedbackId/restore'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Hoàn tác phản hồi thành công',
              icon: Icons.restore,
            ),
          );
        }

        setState(() {
          _deletedFeedbacks.removeWhere((fb) => fb['id'] == feedbackId);
        });

        await _loadMyFeedbacks();
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Hoàn tác thất bại'),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi kết nối: $e'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _permanentlyDeleteFeedback(String feedbackId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever, color: Colors.red[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Xóa vĩnh viễn?'),
          ],
        ),
        content: const Text('Hành động này không thể hoàn tác. Feedback sẽ bị xóa vĩnh viễn khỏi hệ thống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) return;

      setState(() => _isLoading = true);

      final response = await http.delete(
        Uri.parse('${ApiRoutes.rootUrl}/api/feedback/$feedbackId/permanent'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _deletedFeedbacks.removeWhere((fb) => fb['id'] == feedbackId);
        });
        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Feedback đã xóa vĩnh viễn',
              icon: Icons.delete_forever,
            ),
          );
        }
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Xóa thất bại'),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi kết nối: $e'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_titleController.text
        .trim()
        .isEmpty || _contentController.text
        .trim()
        .isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng nhập tiêu đề và nội dung'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        AppSnackBar.show(context, AppSnackBar.error(message: 'Lỗi xác thực'));
        setState(() => _isLoading = false);
        return;
      }

      final request = http.MultipartRequest(
          'POST', Uri.parse(ApiRoutes.feedback));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = _titleController.text.trim();
      request.fields['content'] = _contentController.text.trim();
      request.fields['feedbackType'] = _selectedType;
      request.fields['rating'] = _rating.toString();

      for (var file in _attachments) {
        request.files.add(
            await http.MultipartFile.fromPath('attachments', file.path));
      }

      final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _resetForm();
        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Gửi thành công! Cảm ơn ý kiến của bạn.',
              icon: Icons.check_circle,
            ),
          );
        }
        await _loadMyFeedbacks();
        _tabController.animateTo(1);
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi: ${response.statusCode}'),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi kết nối: $e'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedFeedbacks() async {
    if (_selectedFeedbackIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xóa ${_selectedFeedbackIds.length} mục?'),
        content: const Text(
            'Phản hồi sẽ được lưu trong 7 ngày. Bạn có thể hoàn tác trong thời gian này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      if (token == null) return;

      int deletedCount = 0;
      for (final id in _selectedFeedbackIds) {
        final response = await http.delete(
          Uri.parse(ApiRoutes.deleteMyFeedback(id)),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) deletedCount++;
      }

      setState(() {
        _myFeedbacks.removeWhere((item) =>
            _selectedFeedbackIds.contains(item['_id']));
        _isSelectionMode = false;
        _selectedFeedbackIds.clear();
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Đã xóa $deletedCount phản hồi. Có thể hoàn tác trong 7 ngày.',
            icon: Icons.delete_sweep,
          ),
        );
      }
      await _loadMyFeedbacks();
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Có lỗi xảy ra khi xóa'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteSingle(String feedbackId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa phản hồi này?'),
        content: const Text('Bạn có thể hoàn tác trong 7 ngày.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse(ApiRoutes.deleteMyFeedback(feedbackId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myFeedbacks.removeAt(index);
        });
        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Đã xóa phản hồi. Hoàn tác trong 7 ngày.',
              icon: Icons.delete_outline,
            ),
          );
        }
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Xóa thất bại'),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi kết nối'),
      );
    }
  }

  // ================= HELPER METHODS =================

  void _resetForm() {
    _titleController.clear();
    _contentController.clear();
    setState(() {
      _attachments.clear();
      _selectedType = 'suggestion';
      _rating = 5;
    });
  }

  Future<void> _pickAttachments() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _attachments.addAll(files.map((f) => File(f.path))));
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedFeedbackIds.contains(id)) {
        _selectedFeedbackIds.remove(id);
        if (_selectedFeedbackIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedFeedbackIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedFeedbackIds.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFeedbackIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedFeedbackIds.length == _myFeedbacks.length) {
        _selectedFeedbackIds.clear();
      } else {
        _selectedFeedbackIds.clear();
        for (var fb in _myFeedbacks) {
          _selectedFeedbackIds.add(fb['_id']);
        }
      }
    });
  }

  // ================= UI HELPERS =================

  String _getTypeLabel(String type) {
    const types = {
      'bug': 'Báo lỗi',
      'suggestion': 'Góp ý',
      'complaint': 'Khiếu nại',
      'other': 'Khác'
    };
    return types[type] ?? type;
  }

  String _getStatusLabel(String status) {
    const statuses = {
      'pending': 'Chưa xử lý',
      'reviewing': 'Đang xem xét',
      'resolved': 'Đã giải quyết',
      'closed': 'Đã đóng'
    };
    return statuses[status] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewing':
        return AppColors.primaryBlue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return AppColors.grey600;
      default:
        return AppColors.grey600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'reviewing':
        return Icons.visibility;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.lock_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'bug':
        return Colors.red;
      case 'suggestion':
        return AppColors.primaryBlue;
      case 'complaint':
        return Colors.orange;
      default:
        return AppColors.grey600;
    }
  }

  String _formatDeletedTime(String deletedAtStr) {
    try {
      final deletedAt = DateTime.parse(deletedAtStr);
      final now = DateTime.now();
      final diff = now.difference(deletedAt);

      if (diff.inMinutes < 1) {
        return 'Vừa xóa';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      } else {
        return '${diff.inDays} ngày trước';
      }
    } catch (_) {
      return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _isSelectionMode
            ? Text('${_selectedFeedbackIds.length} đã chọn',
            style: const TextStyle(fontWeight: FontWeight.w600))
            : const Text('Phản hồi ứng dụng',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _cancelSelection,
          tooltip: 'Hủy chọn',
        )
            : null,
        actions: _isSelectionMode
            ? [
          IconButton(
            icon: Icon(
              _selectedFeedbackIds.length == _myFeedbacks.length
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
            ),
            tooltip: 'Chọn tất cả',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa',
            onPressed: _deleteSelectedFeedbacks,
          ),
        ]
            : [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadMyFeedbacks();
              AppSnackBar.show(
                context,
                AppSnackBar.success(
                  message: 'Đã làm mới danh sách',
                  icon: Icons.refresh_rounded,
                ),
              );
            },
            tooltip: 'Làm mới',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Gửi phản hồi'),
            Tab(text: 'Lịch sử'),
            Tab(text: 'Thùng rác'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendFeedbackForm(),
          _buildFeedbackHistory(),
          _buildDeletedFeedbacksList(),
        ],
      ),
      floatingActionButton: _tabController.index == 1 && !_isSelectionMode &&
          _myFeedbacks.isNotEmpty
          ? FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.checklist_rounded, color: Colors.white),
        label: const Text('Chọn nhiều mục',
            style: TextStyle(color: Colors.white)),
        onPressed: () => setState(() => _isSelectionMode = true),
      )
          : null,
    );
  }

  Widget _buildSendFeedbackForm() {
    return SingleChildScrollView(
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
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryBlue),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: [
                  {'value': 'suggestion', 'label': 'Góp ý cải thiện'},
                  {'value': 'bug', 'label': 'Báo lỗi'},
                  {'value': 'complaint', 'label': 'Khiếu nại'},
                  {'value': 'other', 'label': 'Khác'},
                ]
                    .map((item) =>
                    DropdownMenuItem(
                      value: item['value'] as String,
                      child: Text(item['label'] as String),
                    ))
                    .toList(),
                onChanged: _isLoading ? null : (value) =>
                    setState(() => _selectedType = value!),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Text('Đánh giá của bạn',
                  style: TextStyle(color: AppColors.grey700, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                      (i) =>
                      GestureDetector(
                        onTap: _isLoading ? null : () =>
                            setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons
                                .star_border_rounded,
                            size: 44,
                            color: i < _rating ? Colors.amber : Colors
                                .grey[400],
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
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
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
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                  final fileName = f.path
                      .split('/')
                      .last;
                  return Chip(
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.08),
                    label: Text(
                      fileName.length > 20
                          ? '${fileName.substring(0, 20)}...'
                          : fileName,
                      style: const TextStyle(fontSize: 13,
                          color: AppColors.primaryBlue),
                    ),
                    deleteIconColor: AppColors.primaryBlue,
                    onDeleted: _isLoading ? null : () =>
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
                backgroundColor: AppColors.primaryBlue,
                elevation: 0,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'GỬI PHẢN HỒI',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeedbackHistory() {
    if (_myFeedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Chưa có phản hồi nào',
                style: TextStyle(color: AppColors.grey600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _myFeedbacks.length,
      itemBuilder: (_, i) {
        final fb = _myFeedbacks[i];
        final id = fb['_id'] as String;
        final isSelected = _selectedFeedbackIds.contains(id);
        final statusColor = _getStatusColor(fb['status']);
        final attachments = List<String>.from(fb['attachments'] ?? []);

        return GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) {
              _enterSelectionMode(id);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                  width: 1.5
              ),
              boxShadow: isSelected
                  ? []
                  : [
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                leading: _isSelectionMode
                    ? Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (val) => _toggleSelection(id),
                )
                    : CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(_getStatusIcon(fb['status']), color: statusColor,
                      size: 20),
                ),
                title: Text(
                  fb['title'] ?? 'Không tiêu đề',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primaryBlue : Colors.black87),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: Text(_getStatusLabel(fb['status']),
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.grey700)),
                        ),
                        const SizedBox(width: 8),
                        Text('⭐ ${fb['rating']}', style: const TextStyle(
                            fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                trailing: _isSelectionMode ? null : IconButton(
                  icon: const Icon(
                      Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteSingle(id, i),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(fb['content'] ?? '', style: const TextStyle(
                            height: 1.5, fontSize: 15)),
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: attachments.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                              itemBuilder: (_, idx) {
                                final url = '${ApiRoutes
                                    .rootUrl}${attachments[idx]}';
                                return GestureDetector(
                                  onTap: () =>
                                      Navigator.push(context,
                                          MaterialPageRoute(builder: (_) =>
                                              FullScreenImage(imageUrl: url))),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                              width: 80,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.error)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (fb['adminResponse'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.support_agent, size: 18,
                                      color: AppColors.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text('Admin phản hồi:', style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue)),
                                ]),
                                const SizedBox(height: 6),
                                Text(fb['adminResponse']),
                              ],
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeletedFeedbacksList() {
    return FutureBuilder(
      future: _tabController.index == 2 ? _loadDeletedFeedbacks() : Future
          .value(),
      builder: (context, snapshot) {
        if (_deletedFeedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Thùng rác trống',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tất cả phản hồi của bạn vẫn còn nguyên vẹn',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _deletedFeedbacks.length,
          itemBuilder: (_, i) {
            final fb = _deletedFeedbacks[i];
            final feedbackId = fb['id'] as String;
            final attachments = List<String>.from(fb['attachments'] ?? []);
            final deletedTime = _formatDeletedTime(fb['deletedAt'] ?? '');
            final feedbackType = fb['feedbackType'] as String? ?? 'other';
            final rating = fb['rating'] as int? ?? 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red[200]!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.feedback_rounded,
                        color: Colors.red[400],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fb['title'] ?? 'Không tiêu đề',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fb['content'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 12,
                                color: AppColors.grey500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deletedTime,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grey500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: Colors.amber[600],
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$rating',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Restore button
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _restoreFeedback(feedbackId),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text(
                          'Hoàn tác',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete forever button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _isLoading ? null : () => _permanentlyDeleteFeedback(feedbackId),
                        icon: Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                          color: Colors.red[700],
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Xóa vĩnh viễn',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}