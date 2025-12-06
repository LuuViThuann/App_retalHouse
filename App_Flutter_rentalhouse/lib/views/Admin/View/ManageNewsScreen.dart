import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/utils/loadingDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:flutter_rentalhouse/views/Admin/View/AddNewScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/View/NewsDetailScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/HomeMain/EditNew.dart';
import 'package:flutter_rentalhouse/views/Admin/model/news.dart';
import 'package:shimmer/shimmer.dart';

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});

  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen> with AutomaticKeepAliveClientMixin {
  final NewsService _newsService = NewsService();
  List<NewsModel> newsList = [];
  bool isLoading = false;

  @override
  bool get wantKeepAlive => true;

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
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi tải tin tức: ${e.toString()}'),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Fetch trong background không làm giật màn hình
  Future<void> _silentRefresh() async {
    try {
      final result = await _newsService.fetchAllNewsAdmin(page: 1, limit: 50);
      if (!mounted) return;

      setState(() {
        newsList = (result['data'] as List)
            .map((e) => NewsModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Silent refresh error: $e');
    }
  }

  // Cập nhật item trong danh sách
  void _updateNewsInList(NewsModel updatedNews) {
    final index = newsList.indexWhere((n) => n.id == updatedNews.id);
    if (index != -1) {
      setState(() {
        newsList[index] = updatedNews;
      });
    }
  }

  // Thêm item vào đầu danh sách
  void _addNewsToList(NewsModel newNews) {
    setState(() {
      newsList.insert(0, newNews);
    });
  }

  Future<void> _deleteNews(String newsId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
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

    try {
      await _newsService.deleteNews(newsId);

      if (mounted) {
        // Xóa khỏi danh sách ngay lập tức
        setState(() {
          newsList.removeWhere((n) => n.id == newsId);
        });

        AppSnackBar.show(
          context,
          AppSnackBar.success(message: 'Xóa tin tức thành công'),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Xóa thất bại: ${e.toString()}'),
        );
      }
    }
  }

  Future<void> _navigateToEdit(NewsModel news) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditNewsScreen(
          news: news,
          onNewsUpdated: () {},
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Chỉ cập nhật khi có thay đổi thực sự
    if (result != null && result['success'] == true && mounted) {
      final updatedNews = result['news'] as NewsModel?;
      if (updatedNews != null) {
        _updateNewsInList(updatedNews);

        // Fetch trong background để đồng bộ
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _silentRefresh();
        });
      }
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AddNewsScreen(
          onNewsAdded: () {},
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Chỉ cập nhật khi có thay đổi thực sự
    if (result != null && result['success'] == true && mounted) {
      final newNews = result['news'] as NewsModel?;
      if (newNews != null) {
        _addNewsToList(newNews);

        // Fetch trong background để đồng bộ
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _silentRefresh();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // QUAN TRỌNG: Phải gọi super.build cho AutomaticKeepAliveClientMixin
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
        onPressed: _navigateToAdd,
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

            // === NÚT XEM CHI TIẾT ===
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
              right: 80,
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

            // === Menu Chỉnh sửa / Xóa ===
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                child: PopupMenuButton<String>(
                  color: Colors.white,
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
                      _navigateToEdit(news);
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

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) {
      AppLoadingDialog.hide(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailView(news: news),
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