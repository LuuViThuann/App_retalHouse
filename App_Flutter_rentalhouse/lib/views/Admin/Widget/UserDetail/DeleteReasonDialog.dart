import 'package:flutter/material.dart';

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

  final List<String> _deleteReasons = [
    '❌ Bài viết vi phạm quy tắc cộng đồng',
    '🚫 Thông tin không chính xác/sai lệch',
    '📵 Bài viết có nội dung không phù hợp',
    '⚠️ Bài viết bị báo cáo bởi người dùng',
    '🔒 Phát hành bất hợp pháp',
    '💬 Lý do khác',
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _handleDelete() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn lý do xóa bài viết'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedReason == '💬 Lý do khác' &&
        _otherReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập lý do khác'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Ghi log lý do xóa
    _logDeletionReason();

    Navigator.pop(context);
    widget.onConfirmDelete();
  }

  void _logDeletionReason() {
    final reason = _selectedReason == '💬 Lý do khác'
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.red[200]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 40,
                    color: Colors.red[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Xóa bài viết',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng chọn lý do xóa bài viết này',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[600],
                        ),
                  ),
                ],
              ),
            ),

            // ===== CONTENT =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Information
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin bài viết:',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Tiêu đề:', widget.postTitle),
                        const SizedBox(height: 6),
                        _buildInfoRow('Địa chỉ:', widget.postAddress),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Giá:',
                          '${widget.postPrice.toStringAsFixed(0)} VNĐ',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hành động này KHÔNG thể hoàn tác',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reason Selection
                  Text(
                    'Lý do xóa:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Reason Options
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deleteReasons.length,
                    itemBuilder: (context, index) {
                      final reason = _deleteReasons[index];
                      final isSelected = _selectedReason == reason;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedReason = reason;
                              _showOtherReasonField = reason == '💬 Lý do khác';
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.red[50]
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.red[400]!
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.red[500]!
                                          : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? Colors.red[500]
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.red[700]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Other Reason Text Field
                  if (_showOtherReasonField) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otherReasonController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Nhập lý do xóa khác...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        counterText: '',
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ===== FOOTER BUTTONS =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text(
                        'Xóa',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
