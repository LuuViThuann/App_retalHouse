import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/utils/loadingDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/news.dart';
import 'package:flutter_rentalhouse/views/Admin/View/NewsDetailScreen.dart';
import 'package:flutter_rentalhouse/views/Admin/model/news.dart';
import 'package:intl/intl.dart';

class NewsHighlightSection extends StatefulWidget {
  const NewsHighlightSection({super.key});

  @override
  State<NewsHighlightSection> createState() => _NewsHighlightSectionState();
}

class _NewsHighlightSectionState extends State<NewsHighlightSection> {
  final NewsService _newsService = NewsService();
  List<NewsModel> newsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => isLoading = true);
    try {
      final result = await _newsService.fetchAllNews(limit: 10);
      if (!mounted) return;

      setState(() {
        newsList = (result['data'] as List)
            .map((e) => NewsModel.fromJson(e as Map<String, dynamic>))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _navigateToNewsDetail(NewsModel news) async {
    AppLoadingDialog.show(context, message: 'Đang mở tin tức...');

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsDetailView(news: news)),
    );

    if (mounted) AppLoadingDialog.hide(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === Tiêu đề phần tin tức ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tin tức mới',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Thêm trang liệt kê tất cả tin tức
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Danh sách tin tức - Sắp có!')),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem tất cả',
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward,
                        size: 16, color: Colors.blue[700]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // === Danh sách tin tức hoặc loading ===
        isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: NewsCardShimmer(),
              )
            : newsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Chưa có tin tức nào',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: newsList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final news = newsList[index];
                      final imageUrl =
                          news.getFullImageUrl(ApiRoutes.serverBaseUrl);
                      final date =
                          DateFormat('dd/MM/yyyy').format(news.createdAt);

                      return GestureDetector(
                        onTap: () => _navigateToNewsDetail(news),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // === Ảnh thumbnail ===
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: Colors.grey[200],
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // === Nội dung bên phải ===
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Tiêu đề
                                          Text(
                                            news.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),

                                          // Mô tả ngắn
                                          Text(
                                            news.summary,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),

                                          // Hashtag + Ngày đăng
                                          Row(
                                            children: [
                                              Text(
                                                '#${news.category.replaceAll(' ', '')} #TinHot',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue[600],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                date,
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
                                  ],
                                ),
                              ),

                              // === Nút Xem chi tiết ===
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _navigateToNewsDetail(news),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.12),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Xem chi tiết',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: Colors.blue[700],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // === Tag HOT ===
                              if (news.featured)
                                Positioned(
                                  top: 14,
                                  left: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      'HOT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

        const SizedBox(height: 20),
      ],
    );
  }
}

// === Shimmer Loading ===
class NewsCardShimmer extends StatelessWidget {
  const NewsCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        height: 132,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 16,
                      width: double.infinity,
                      color: Colors.grey[200]),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 200, color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 140, color: Colors.grey[200]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
