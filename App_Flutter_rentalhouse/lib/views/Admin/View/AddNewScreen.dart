import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rich_editor/rich_editor.dart';

class AddNewsScreen extends StatefulWidget {
  final VoidCallback onNewsAdded;
  const AddNewsScreen({required this.onNewsAdded, super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final NewsService _newsService = NewsService();
  final ImagePicker _picker = ImagePicker();

  List<File> selectedImages = [];
  final titleController = TextEditingController();
  final summaryController = TextEditingController();
  final authorController = TextEditingController(text: 'Admin');
  final categoryController = TextEditingController(text: 'Tin tức');

  final GlobalKey<RichEditorState> _editorKey = GlobalKey<RichEditorState>();
  bool featured = false;
  bool isLoading = false;

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        selectedImages = picked.map((p) => File(p.path)).toList();
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> _createNews() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(context, AppSnackBar.error(message: 'Vui lòng nhập tiêu đề'));
      return;
    }

    if (selectedImages.isEmpty) {
      AppSnackBar.show(context, AppSnackBar.error(message: 'Vui lòng chọn ít nhất 1 ảnh'));
      return;
    }

    final html = await _editorKey.currentState?.getHtml();
    if (html == null ||
        html.trim().isEmpty ||
        html == '<br>' ||
        html == '<p><br></p>') {
      AppSnackBar.show(context, AppSnackBar.error(message: 'Vui lòng nhập nội dung bài viết'));
      return;
    }

    setState(() => isLoading = true);

    try {
      final defaultSummary =
      title.length > 120 ? '${title.substring(0, 120)}...' : title;

      await _newsService.createNews(
        title: title,
        content: html,
        summary: summaryController.text.trim().isEmpty
            ? defaultSummary
            : summaryController.text.trim(),
        imageFiles: selectedImages,
        author: authorController.text.trim(),
        category: categoryController.text.trim(),
        featured: featured,
      );

      if (mounted) {
        AppSnackBar.show(context, AppSnackBar.success(message: 'Thêm tin tức thành công!'));
        widget.onNewsAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, AppSnackBar.error(message: 'Lỗi: ${e.toString()}'));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    authorController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thêm Tin tức Mới'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chọn ảnh
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.blue[300]!,
                      width: 2,
                      style: BorderStyle.solid),
                  color: Colors.blue[50],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 64, color: Colors.blue[700]),
                    const SizedBox(height: 16),
                    Text(
                      selectedImages.isEmpty
                          ? 'Chọn ảnh tin tức'
                          : 'Chọn thêm ảnh',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hiển thị ảnh đã chọn
            if (selectedImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ảnh đã chọn (${selectedImages.length})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(
                                  selectedImages[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            _buildTextField('Tiêu đề *', titleController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField('Danh mục', categoryController)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Tác giả', authorController)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Tóm tắt (không bắt buộc)', summaryController,
                maxLines: 4),
            const SizedBox(height: 20),

            const Text('Nội dung bài viết *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              height: 420,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichEditor(
                key: _editorKey,
                editorOptions: RichEditorOptions(
                  placeholder: 'Viết nội dung bài viết tại đây...',
                  padding: const EdgeInsets.all(12),
                  baseTextColor: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: featured,
                  activeColor: Colors.orange,
                  onChanged: (v) => setState(() => featured = v ?? false),
                ),
                const Text('Đánh dấu là tin tức nổi bật',
                    style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createNews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
                    : const Text('Thêm Tin tức',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}