import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:intl/intl.dart';

class DeleteReasonDialog extends StatefulWidget {
  final String postTitle;
  final String postAddress;
  final double postPrice;
  final VoidCallback onConfirmDelete;

  const DeleteReasonDialog({
    Key? key,
    required this.postTitle,
    required this.postAddress,
    required this.postPrice,
    required this.onConfirmDelete,
  }) : super(key: key);

  @override
  State<DeleteReasonDialog> createState() => _DeleteReasonDialogState();
}

class _DeleteReasonDialogState extends State<DeleteReasonDialog> {
  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _showOtherReasonField = false;
  bool _isDeleting = false;

  final _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  final List<Map<String, dynamic>> _deleteReasons = [
    {
      'icon': Icons.gavel_outlined,
      'text': 'Vi phạm quy tắc cộng đồng',
      'color': Color(0xFFEF4444),
    },
    {
      'icon': Icons.error_outline,
      'text': 'Thông tin không chính xác',
      'color': Color(0xFFF97316),
    },
    {
      'icon': Icons.block_outlined,
      'text': 'Nội dung không phù hợp',
      'color': Color(0xFFEAB308),
    },
    {
      'icon': Icons.flag_outlined,
      'text': 'Bị báo cáo bởi người dùng',
      'color': Color(0xFF8B5CF6),
    },
    {
      'icon': Icons.lock_outline,
      'text': 'Phát hành bất hợp pháp',
      'color': Color(0xFF6366F1),
    },
    {
      'icon': Icons.edit_outlined,
      'text': 'Lý do khác',
      'color': Color(0xFF64748B),
    },
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _handleDelete() async {
    if (_selectedReason == null) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng chọn lý do xóa bài viết'),
      );
      return;
    }

    if (_selectedReason == 'Lý do khác' && _otherReasonController.text.isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng nhập lý do cụ thể'),
      );
      return;
    }

    setState(() => _isDeleting = true);

    // Simulate deletion delay
    await Future.delayed(const Duration(milliseconds: 500));

    _logDeletionReason();

    if (mounted) {
      Navigator.pop(context);
      widget.onConfirmDelete();
    }
  }

  void _logDeletionReason() {
    final reason = _selectedReason == 'Lý do khác'
        ? _otherReasonController.text
        : _selectedReason;

    debugPrint('═══════════════════════════════════════════');
    debugPrint('🗑️ BÀI VIẾT BỊ XÓA - ADMIN ACTION');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('📌 Tiêu đề: ${widget.postTitle}');
    debugPrint('📍 Địa chỉ: ${widget.postAddress}');
    debugPrint('💰 Giá: ${widget.postPrice}');
    debugPrint('⏰ Thời gian xóa: ${DateTime.now()}');
    debugPrint('📋 Lý do xóa: $reason');
    debugPrint('═══════════════════════════════════════════');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 32,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Xóa bài viết',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng chọn lý do để xóa bài viết này',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Information
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.article_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Thông tin bài viết',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.title_outlined,
                            'Tiêu đề',
                            widget.postTitle,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Địa chỉ',
                            widget.postAddress,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.payments_outlined,
                            'Giá thuê',
                            '${_currencyFormatter.format(widget.postPrice)} VNĐ',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Warning Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE047)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFEAB308),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Hành động này không thể hoàn tác',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Reason Selection
                    const Text(
                      'Chọn lý do xóa',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reason Options
                    ...List.generate(_deleteReasons.length, (index) {
                      final reason = _deleteReasons[index];
                      final isSelected = _selectedReason == reason['text'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedReason = reason['text'];
                              _showOtherReasonField =
                                  reason['text'] == 'Lý do khác';
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFEE2E2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    reason['icon'],
                                    size: 20,
                                    color: isSelected
                                        ? reason['color']
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reason['text'],
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF475569),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Other Reason Text Field
                    if (_showOtherReasonField) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otherReasonController,
                        maxLines: 3,
                        maxLength: 200,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập lý do cụ thể...',
                          hintStyle: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFEF4444), width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          counterStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isDeleting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isDeleting ? null : _handleDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFFFCA5A5),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Xóa bài viết',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}