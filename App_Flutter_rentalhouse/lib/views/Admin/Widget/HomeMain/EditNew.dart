import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:flutter_rentalhouse/views/Admin/model/news.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rich_editor/rich_editor.dart';

class EditNewsScreen extends StatefulWidget {
  final NewsModel news;
  final VoidCallback onNewsUpdated;

  const EditNewsScreen({
    required this.news,
    required this.onNewsUpdated,
    super.key,
  });

  @override
  State<EditNewsScreen> createState() => _EditNewsScreenState();
}

class _EditNewsScreenState extends State<EditNewsScreen> {
  final NewsService _newsService = NewsService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController titleController;
  late TextEditingController summaryController;
  late TextEditingController authorController;
  late TextEditingController categoryController;

  File? selectedImage;
  String? existingImageUrl;
  bool featured = false;
  bool isActive = true;
  bool isLoading = false;

  final GlobalKey<RichEditorState> _editorKey = GlobalKey<RichEditorState>();

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.news.title);
    summaryController = TextEditingController(text: widget.news.summary);
    authorController = TextEditingController(text: widget.news.author);
    categoryController = TextEditingController(text: widget.news.category);
    featured = widget.news.featured;
    isActive = widget.news.isActive;
    existingImageUrl = widget.news.getFullImageUrl(ApiRoutes.serverBaseUrl);

    // Delay để chắc chắn editor đã load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEditorContent();
    });
  }

  Future<void> _loadEditorContent() async {
    if (_editorKey.currentState != null) {
      try {
        await _editorKey.currentState?.setHtml(widget.news.content);
      } catch (e) {
        debugPrint('Error loading editor content: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateNews() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      return _showSnackBar('Vui lòng nhập tiêu đề', isError: true);
    }

    final html = await _editorKey.currentState?.getHtml();
    if (html == null ||
        html.trim().isEmpty ||
        html == '<br>' ||
        html == '<p><br></p>') {
      return _showSnackBar('Vui lòng nhập nội dung bài viết', isError: true);
    }

    setState(() => isLoading = true);

    try {
      await _newsService.updateNews(
        newsId: widget.news.id,
        title: title,
        content: html,
        summary: summaryController.text.trim(),
        imageFile: selectedImage,
        author: authorController.text.trim(),
        category: categoryController.text.trim(),
        featured: featured,
        isActive: isActive,
      );

      _showSnackBar('Cập nhật tin tức thành công!');
      widget.onNewsUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Lỗi: ${e.toString()}', isError: true);
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
        title: const Text('Chỉnh sửa Tin tức'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh đại diện
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[300]!, width: 2),
                  color: Colors.blue[50],
                ),
                child: selectedImage == null
                    ? (existingImageUrl != null && existingImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildImagePlaceholder(),
                            ),
                          )
                        : _buildImagePlaceholder())
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(selectedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField('Tiêu đề *', titleController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Danh mục', categoryController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField('Tác giả', authorController),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Tóm tắt', summaryController, maxLines: 4),
            const SizedBox(height: 20),
            const Text(
              'Nội dung bài viết *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
                const Text(
                  'Đánh dấu là tin tức nổi bật',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => isActive = v ?? true),
                ),
                const Text(
                  'Kích hoạt tin tức',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _updateNews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Cập nhật Tin tức',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 64, color: Colors.blue[700]),
        const SizedBox(height: 16),
        Text(
          'Nhấn để thay đổi ảnh',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
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
