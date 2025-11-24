// lib/views/Admin/screens/manage_news_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/loadingDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:flutter_rentalhouse/views/Admin/View/NewsDetailScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/HomeMain/EditNew.dart';
import 'package:flutter_rentalhouse/views/Admin/model/news.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rich_editor/rich_editor.dart';
import 'package:shimmer/shimmer.dart';

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});

  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen> {
  final NewsService _newsService = NewsService();
  List<NewsModel> newsList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final result = await _newsService.fetchAllNewsAdmin(page: 1, limit: 50);
      if (!mounted) return;

      setState(() {
        newsList = (result['data'] as List)
            .map((e) => NewsModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      _showSnackBar('Lỗi tải tin tức: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteNews(String newsId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tin tức'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa tin tức này?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      await _newsService.deleteNews(newsId);
      _showSnackBar('Xóa tin tức thành công');
      _fetchNews();
    } catch (e) {
      _showSnackBar('Xóa thất bại: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quản lý Tin tức'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNews,
          ),
        ],
      ),
      body: isLoading && newsList.isEmpty
          ? _buildShimmerLoading()
          : newsList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchNews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: newsList.length,
                    itemBuilder: (context, index) =>
                        _buildNewsCard(newsList[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddNewsScreen(onNewsAdded: _fetchNews),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(NewsModel news) {
    final imageUrl = news.getFullImageUrl(ApiRoutes.serverBaseUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Ảnh nền
            Image.network(
              imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()));
              },
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image,
                    size: 60, color: Colors.grey),
              ),
            ),

            // Lớp mờ + nội dung
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),

            // === NÚT XEM CHI TIẾT - DỄ BẤM NHẤT ===
            Positioned(
              top: 12,
              left: 12,
              child: ElevatedButton.icon(
                onPressed: () => _viewNewsDetail(news),
                icon: const Icon(Icons.visibility, size: 18),
                label:
                    const Text('Xem chi tiết', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[700],
                  elevation: 4,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),

            // === Tag nổi bật ===
            Positioned(
              top: 12,
              right: 80, // để chừa chỗ cho menu
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: news.featured
                      ? Colors.orange.shade600
                      : Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(news.featured ? Icons.star : Icons.star_border,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      news.featured ? 'Nổi bật' : 'Bình thường',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            // === Menu Chỉnh sửa / Xóa (giờ dễ bấm hơn nhờ icon lớn) ===
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                child: PopupMenuButton<String>(
                  padding: const EdgeInsets.all(12),
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white, size: 28),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Chỉnh sửa')
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Xóa', style: TextStyle(color: Colors.red))
                        ])),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditNewsScreen(
                              news: news, onNewsUpdated: _fetchNews),
                        ),
                      );
                    } else if (value == 'delete') {
                      _deleteNews(news.id);
                    }
                  },
                ),
              ),
            ),

            // Nội dung tiêu đề
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.visibility,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text('${news.views} lượt xem',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      Text(news.category,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewNewsDetail(NewsModel news) async {
    AppLoadingDialog.show(context, message: 'Đang mở tin tức...');

    // Đợi chút để animation mượt
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) {
      AppLoadingDialog.hide(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NewsDetailView(news: news), // Dùng chung trang chi tiết người dùng
      ),
    );

    if (mounted) {
      AppLoadingDialog.hide(context);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_outlined, size: 100, color: Colors.blue[300]),
          const SizedBox(height: 24),
          const Text(
            'Chưa có tin tức nào',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text('Nhấn nút + để thêm tin tức đầu tiên',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ===================== ADD NEWS SCREEN =====================
class AddNewsScreen extends StatefulWidget {
  final VoidCallback onNewsAdded;
  const AddNewsScreen({required this.onNewsAdded, super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final NewsService _newsService = NewsService();
  final ImagePicker _picker = ImagePicker();

  File? selectedImage;
  final titleController = TextEditingController();
  final summaryController = TextEditingController();
  final authorController = TextEditingController(text: 'Admin');
  final categoryController = TextEditingController(text: 'Tin tức');

  final GlobalKey<RichEditorState> _editorKey = GlobalKey<RichEditorState>();
  bool featured = false;
  bool isLoading = false;

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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

  Future<void> _createNews() async {
    final title = titleController.text.trim();
    if (title.isEmpty)
      return _showSnackBar('Vui lòng nhập tiêu đề', isError: true);
    if (selectedImage == null)
      return _showSnackBar('Vui lòng chọn ảnh', isError: true);

    final html = await _editorKey.currentState?.getHtml();
    if (html == null ||
        html.trim().isEmpty ||
        html == '<br>' ||
        html == '<p><br></p>') {
      return _showSnackBar('Vui lòng nhập nội dung bài viết', isError: true);
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
        imageFile: selectedImage!,
        author: authorController.text.trim(),
        category: categoryController.text.trim(),
        featured: featured,
      );

      _showSnackBar('Thêm tin tức thành công!');
      widget.onNewsAdded();
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
            // Ảnh đại diện
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.blue[300]!,
                      width: 2,
                      style: BorderStyle.solid),
                  color: Colors.blue[50],
                ),
                child: selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 64, color: Colors.blue[700]),
                          const SizedBox(height: 16),
                          Text(
                            'Chọn ảnh tin tức',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700]),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 260),
                      ),
              ),
            ),
            const SizedBox(height: 24),

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
