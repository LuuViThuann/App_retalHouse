import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
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

  List<File> newImages = [];
  List<String> existingImageUrls = [];
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

    // Sử dụng getAllFullImageUrls() từ NewsModel mới
    existingImageUrls = widget.news.getAllFullImageUrls(ApiRoutes.serverBaseUrl);

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

  Future<void> _pickNewImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        newImages = picked.map((p) => File(p.path)).toList();
        existingImageUrls = [];
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      existingImageUrls.removeAt(index);
    });
  }

  Future<void> _updateNews() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(
          context, AppSnackBar.error(message: 'Vui lòng nhập tiêu đề'));
      return;
    }

    if (newImages.isEmpty && existingImageUrls.isEmpty) {
      AppSnackBar.show(context,
          AppSnackBar.error(message: 'Vui lòng giữ lại hoặc chọn ảnh'));
      return;
    }

    final html = await _editorKey.currentState?.getHtml();
    if (html == null ||
        html.trim().isEmpty ||
        html == '<br>' ||
        html == '<p><br></p>') {
      AppSnackBar.show(context,
          AppSnackBar.error(message: 'Vui lòng nhập nội dung bài viết'));
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await _newsService.updateNews(
        newsId: widget.news.id,
        title: title,
        content: html,
        summary: summaryController.text.trim(),
        imageFiles: newImages.isNotEmpty ? newImages : null,
        author: authorController.text.trim(),
        category: categoryController.text.trim(),
        featured: featured,
        isActive: isActive,
      );

      if (mounted) {
        // Tạo NewsModel từ response
        NewsModel updatedNews;
        if (response is Map<String, dynamic> && response.containsKey('data')) {
          updatedNews = NewsModel.fromJson(response['data']);
        } else {
          // Fallback: tạo model từ dữ liệu local với imageUrls
          List<String> updatedImageUrls = [];

          if (newImages.isNotEmpty) {
            // Nếu có ảnh mới, tạm thời giữ imageUrls cũ
            // Server sẽ cập nhật URL mới sau khi upload thành công
            updatedImageUrls = widget.news.imageUrls;
          } else {
            // Giữ lại ảnh hiện tại, loại bỏ baseUrl
            updatedImageUrls = existingImageUrls
                .map((url) => url.replaceAll(ApiRoutes.serverBaseUrl, '').replaceAll('//', '/'))
                .toList();
          }

          updatedNews = NewsModel(
            id: widget.news.id,
            title: title,
            content: html,
            summary: summaryController.text.trim(),
            imageUrls: updatedImageUrls,
            imageUrl: updatedImageUrls.isNotEmpty ? updatedImageUrls[0] : '',
            author: authorController.text.trim(),
            category: categoryController.text.trim(),
            featured: featured,
            isActive: isActive,
            views: widget.news.views,
            createdAt: widget.news.createdAt,
            updatedAt: DateTime.now(),
          );
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(message: 'Cập nhật tin tức thành công!'),
          );

          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // Trả về data để cập nhật local
            Navigator.pop(context, {
              'success': true,
              'news': updatedNews,
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
            context, AppSnackBar.error(message: 'Lỗi: ${e.toString()}'));
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
    return WillPopScope(
      onWillPop: () async {
        // Cho phép pop mượt mà mà không trigger rebuild
        return true;
      },
      child: Scaffold(
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
              // Chọn ảnh mới
              GestureDetector(
                onTap: _pickNewImages,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[300]!, width: 2),
                    color: Colors.blue[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo,
                          size: 64, color: Colors.blue[700]),
                      const SizedBox(height: 16),
                      Text(
                        newImages.isEmpty ? 'Chọn ảnh mới' : 'Chọn thêm ảnh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Ảnh mới
              if (newImages.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh mới (${newImages.length})',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: newImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                  Border.all(color: Colors.orange, width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    newImages[index],
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
                                  onTap: () => _removeNewImage(index),
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

              // Ảnh cũ
              if (existingImageUrls.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh hiện tại (${existingImageUrls.length})',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: existingImageUrls.length,
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
                                  child: Image.network(
                                    existingImageUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      child:
                                      const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(index),
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
      ),
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