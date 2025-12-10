import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  Map<String, dynamic>? _aboutUs;
  List<String> _imageUrls = []; // ✅ FIX: Tách riêng list URLs
  bool _isLoading = true;
  String? _error;
  int _currentImageIndex = 0;
  late PageController _pageController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchAboutUs();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_imageUrls.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _imageUrls.isEmpty) return;

      int nextPage = (_currentImageIndex + 1) % _imageUrls.length;
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

  Future<void> _fetchAboutUs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse('${ApiRoutes.baseUrl}/aboutus'))
          .timeout(const Duration(seconds: 15));

      print('📥 [ABOUTUS SCREEN] Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          final data = json['data'];

          // ✅ FIX: Parse images correctly (cả object array và string array)
          final List<String> urls = [];
          if (data['images'] != null) {
            final images = data['images'] as List;
            print('🔍 Images type: ${images.runtimeType}');
            print('🔍 Images length: ${images.length}');

            for (int i = 0; i < images.length; i++) {
              final img = images[i];
              if (img is Map<String, dynamic>) {
                // Format mới: {url, cloudinaryId, order}
                final url = img['url'] as String?;
                if (url != null && url.isNotEmpty) {
                  urls.add(url);
                }
              } else if (img is String) {
                // Format cũ: chỉ URL string
                if (img.isNotEmpty) {
                  urls.add(img);
                }
              }
            }
          }

          print('✅ Parsed ${urls.length} image URLs');

          setState(() {
            _aboutUs = data;
            _imageUrls = urls;
            _currentImageIndex = 0;
          });

          _startAutoPlay();
        } else {
          setState(() {
            _error = json['message'] ?? 'Chưa có nội dung giới thiệu';
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _error = 'Chưa có nội dung giới thiệu về chúng tôi';
        });
      } else {
        throw Exception('Lỗi tải dữ liệu');
      }
    } catch (e) {
      print('❌ [ABOUTUS SCREEN] Error: $e');
      setState(() {
        _error = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối và thử lại.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Giới thiệu về chúng tôi'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(color: Colors.blue[700]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAboutUs,
        color: Colors.blue[700],
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Colors.blue,
            strokeWidth: 3,
          ),
        )
            : _error != null
            ? _buildErrorState()
            : _buildModernContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchAboutUs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernContent() {
    final title = _aboutUs!['title'] ?? 'Công ty chúng tôi';
    final description = _aboutUs!['description'] ?? '';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === SLIDER ẢNH (có thể kéo tay + auto play) ===
          if (_imageUrls.isNotEmpty) ...[
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemCount: _imageUrls.length,
                itemBuilder: (context, index) {
                  final imageUrl = _imageUrls[index];

                  // ✅ FIX: Kiểm tra URL đã có protocol chưa
                  final fullUrl = imageUrl.startsWith('http')
                      ? imageUrl
                      : '${ApiRoutes.rootUrl}$imageUrl';

                  return CachedNetworkImage(
                    imageUrl: fullUrl,
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
                },
              ),
            ),

            // Dots indicator
            if (_imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _imageUrls.asMap().entries.map((entry) {
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
          ],

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  description,
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  '© 2025 - Đồng hành cùng hàng nghìn gia đình Việt',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                SizedBox(height: 14),
                Text(
                  'Cảm ơn bạn đã tin tưởng!',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}