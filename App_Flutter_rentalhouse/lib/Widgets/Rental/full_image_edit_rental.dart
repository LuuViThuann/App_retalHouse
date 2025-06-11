import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';

class FullImageEditRental extends StatelessWidget {
  final String imageUrl;
  final bool isNetworkImage;

  const FullImageEditRental({
    super.key,
    required this.imageUrl,
    required this.isNetworkImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: isNetworkImage
                ? NetworkImage(imageUrl)
                : FileImage(File(imageUrl)) as ImageProvider,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 3.0,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            errorBuilder: (context, error, stackTrace) {
              print(
                  'Image view error: $error for ${isNetworkImage ? 'network' : 'local'} image: $imageUrl');
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Đóng',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
