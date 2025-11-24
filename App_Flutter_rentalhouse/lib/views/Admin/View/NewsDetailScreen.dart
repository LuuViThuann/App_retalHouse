// lib/views/news_detail_view.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:flutter_rentalhouse/views/Admin/model/news.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class NewsDetailView extends StatefulWidget {
  final NewsModel news;

  const NewsDetailView({required this.news, super.key});

  @override
  State<NewsDetailView> createState() => _NewsDetailViewState();
}

class _NewsDetailViewState extends State<NewsDetailView> {
  late NewsModel news;
  bool isLoading = true;
  final NewsService _newsService = NewsService();

  @override
  void initState() {
    super.initState();
    news = widget.news;
    _loadNewsDetail();
  }

  Future<void> _loadNewsDetail() async {
    try {
      final Map<String, dynamic> data =
          await _newsService.fetchNewsDetail(news.id);

      if (mounted) {
        setState(() {
          news = NewsModel.fromJson(data); // Chuyển Map thành NewsModel
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        debugPrint('Error loading news detail: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được chi tiết tin tức')),
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String _formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Vừa xong';
      }
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return _formatDate(dateTime);
    }
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 20, width: double.infinity, color: Colors.white),
                const SizedBox(height: 12),
                Container(height: 20, width: 200, color: Colors.white),
                const SizedBox(height: 20),
                Container(
                    height: 16, width: double.infinity, color: Colors.white),
                const SizedBox(height: 8),
                Container(
                    height: 16, width: double.infinity, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 16, width: 150, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? _buildShimmerLoading()
          : CustomScrollView(
              slivers: [
                // === App Bar với hình ảnh ===
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.blue[700],
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              news.getFullImageUrl(ApiRoutes.serverBaseUrl),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 60),
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        // Featured badge
                        if (news.featured)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TIN NỔI BẬT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // === Nội dung chính ===
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // === Tiêu đề ===
                        Text(
                          news.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // === Metadata (Tác giả, Ngày, Lượt xem) ===
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      news.author.isNotEmpty
                                          ? news.author[0].toUpperCase()
                                          : 'A',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Thông tin tác giả
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          news.author,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatRelativeDate(news.createdAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Lượt xem
                                  Column(
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        size: 20,
                                        color: Colors.orange[600],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${news.views}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Divider
                              Container(
                                height: 1,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              // Category
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      news.category,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(news.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // === Tóm tắt ===
                        if (news.summary.isNotEmpty) ...[
                          Text(
                            news.summary,
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 2,
                            color: Colors.grey[200],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // === Nội dung HTML ===
                        _buildHtmlContent(news.content),
                        const SizedBox(height: 40),

                        // === Social sharing buttons ===
                        _buildShareSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHtmlContent(String htmlContent) {
    // Loại bỏ các tag HTML và giữ lại text
    String plainText = _stripHtmlTags(htmlContent);

    return SelectableText(
      plainText,
      style: const TextStyle(
        fontSize: 16,
        height: 1.8,
        color: Colors.black87,
        letterSpacing: 0.2,
      ),
    );
  }

  String _stripHtmlTags(String htmlText) {
    RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    String plainText = htmlText.replaceAll(exp, '');
    plainText = plainText
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('\n\n', '\n');
    return plainText.trim();
  }

  Widget _buildShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chia sẻ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildShareButton(
              icon: Icons.share,
              label: 'Chia sẻ',
              color: Colors.blue[600]!,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng chia sẻ sắp có')),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildShareButton(
              icon: Icons.bookmark_border,
              label: 'Lưu',
              color: Colors.orange[600]!,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu tin tức này')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
