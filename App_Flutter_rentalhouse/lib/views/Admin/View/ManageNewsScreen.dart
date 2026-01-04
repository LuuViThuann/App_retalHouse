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

  void _updateNewsInList(NewsModel updatedNews) {
    final index = newsList.indexWhere((n) => n.id == updatedNews.id);
    if (index != -1) {
      setState(() {
        newsList[index] = updatedNews;
      });
    }
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa tin tức',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        content: const Text(
            'Bạn có chắc chắn muốn xóa?\nHành động này không thể hoàn tác.',
            style: TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _newsService.deleteNews(newsId);

      if (mounted) {
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

    if (result != null && result['success'] == true && mounted) {
      final updatedNews = result['news'] as NewsModel?;
      if (updatedNews != null) {
        _updateNewsInList(updatedNews);
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

    if (result != null && result['success'] == true && mounted) {
      final newNews = result['news'] as NewsModel?;
      if (newNews != null) {
        _addNewsToList(newNews);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _silentRefresh();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: isLoading && newsList.isEmpty
          ? _buildShimmerLoading()
          : newsList.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchNews,
        color: Colors.blue[700],
        backgroundColor: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
          itemCount: newsList.length,
          itemBuilder: (context, index) =>
              _buildNewsCard(newsList[index]),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Quản lý Tin tức',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black)),
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      toolbarHeight: 64,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _fetchNews,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                ),
                child: Icon(Icons.refresh, color: Colors.blue[700], size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 8),
      child: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _navigateToAdd,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNewsCard(NewsModel news) {
    final imageUrl = news.getFullImageUrl(ApiRoutes.serverBaseUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: Stack(
            children: [
              // Ảnh nền
              Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    height: 200,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image,
                      size: 50, color: Colors.grey),
                ),
              ),

              // Gradient overlay
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75)
                    ],
                  ),
                ),
              ),

              // Nội dung chính
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              news.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryBadge(news.category),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.visibility,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text('${news.views}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: news.featured
                                  ? Colors.orange.shade600
                                  : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    news.featured
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.white,
                                    size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  news.featured ? 'Nổi bật' : 'Bình thường',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons - top right
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<String>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                color: Colors.blue[700], size: 20),
                            const SizedBox(width: 12),
                            const Text('Xem chi tiết',
                                style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.blue[700], size: 20),
                            const SizedBox(width: 12),
                            const Text('Chỉnh sửa',
                                style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red[600], size: 20),
                            const SizedBox(width: 12),
                            Text('Xóa',
                                style: TextStyle(
                                    color: Colors.red[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view') {
                        _viewNewsDetail(news);
                      } else if (value == 'edit') {
                        _navigateToEdit(news);
                      } else if (value == 'delete') {
                        _deleteNews(news.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    final colors = {
      'Tin tức': Colors.blue,
      'Sự kiện': Colors.green,
      'Khuyến mãi': Colors.red,
      'Cập nhật': Colors.purple,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[category] ?? Colors.blue).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _viewNewsDetail(NewsModel news) async {
    AppLoadingDialog.show(context, message: 'Đang mở...');

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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[100],
            ),
            child: Icon(Icons.newspaper_outlined,
                size: 50, color: Colors.blue[700]),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có tin tức',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text('Nhấn nút + để thêm tin tức đầu tiên',
              style:
              TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}