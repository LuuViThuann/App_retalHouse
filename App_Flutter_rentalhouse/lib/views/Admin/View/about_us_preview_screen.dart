import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'dart:io';

class AboutUsPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> previewData;

  const AboutUsPreviewScreen({
    super.key,
    required this.previewData,
  });

  @override
  State<AboutUsPreviewScreen> createState() => _AboutUsPreviewScreenState();
}

class _AboutUsPreviewScreenState extends State<AboutUsPreviewScreen> {
  int _currentImageIndex = 0;
  late PageController _pageController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final images = List<String>.from(widget.previewData['images'] ?? []);
      if (images.length <= 1) return;

      int nextPage = (_currentImageIndex + 1) % images.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImageWidget(String imagePath) {
    // Kiểm tra xem có phải URL từ server hay File local
    if (imagePath.startsWith('http') || imagePath.startsWith('/uploads')) {
      // URL từ server
      final imageUrl = imagePath.startsWith('http')
          ? imagePath
          : '${ApiRoutes.rootUrl}$imagePath';
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.image_not_supported,
            size: 60,
            color: Colors.grey,
          ),
        ),
      );
    } else {
      // File local
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.broken_image,
            size: 60,
            color: Colors.grey,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.previewData['title'] ?? 'Công ty chúng tôi';
    final description = widget.previewData['description'] ?? '';
    final images = List<String>.from(widget.previewData['images'] ?? []);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Xem trước'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(color: Colors.blue[700]),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === SLIDER ẢNH (có thể kéo tay + auto play) ===
            if (images.isNotEmpty) ...[
              SizedBox(
                height: 280,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return _buildImageWidget(images[index]);
                  },
                ),
              ),

              // Dots indicator
              if (images.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((entry) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentImageIndex == entry.key ? 28 : 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _currentImageIndex == entry.key
                              ? Colors.blue[700]
                              : Colors.grey[400],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ] else
            // Ảnh placeholder khi không có ảnh
              Container(
                height: 280,
                width: double.infinity,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // === TIÊU ĐỀ ĐƯỢC TÁCH RIÊNG - RÕ RÀNG, ĐẸP MẮT ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // === NỘI DUNG MÔ TẢ ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                color: Colors.white,
                elevation: 5,
                shadowColor: Colors.blue[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    description.isEmpty
                        ? 'Chưa có nội dung mô tả'
                        : description,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.9,
                      color: Colors.black87,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),

            // === FOOTER ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue],
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    'Công ty TNHH Nhà Cho Thuê',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '© 2025 - Đồng hành cùng hàng nghìn gia đình Việt',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Cảm ơn bạn đã tin tưởng!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
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
}