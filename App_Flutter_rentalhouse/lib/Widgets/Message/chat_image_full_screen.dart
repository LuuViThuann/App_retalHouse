import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ChatFullImage extends StatelessWidget {
  final String imageUrl;

  const ChatFullImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered *
                3.0, // Tăng maxScale để zoom rõ hơn
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            loadingBuilder: (context, event) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20, // Đổi sang right để phù hợp giao diện
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded, // Sử dụng icon thoát mượt mà hơn
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Đóng', // Thêm tooltip cho accessibility
              ),
            ),
          ),
        ],
      ),
    );
  }
}
