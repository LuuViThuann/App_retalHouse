import 'package:flutter/material.dart';
import 'dart:io';

class FullScreenImageScreen extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;

  const FullScreenImageScreen({super.key, this.imageUrl, this.imageFile})
      : assert(imageUrl != null || imageFile != null, 'Phải cung cấp imageUrl hoặc imageFile');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: Hero(
            tag: imageUrl ?? imageFile!.path,
            child: imageFile != null
                ? Image.file(
              imageFile!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
            )
                : Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
            ),
          ),
        ),
      ),
    );
  }
}