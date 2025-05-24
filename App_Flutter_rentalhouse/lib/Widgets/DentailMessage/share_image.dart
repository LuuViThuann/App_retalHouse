import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Message/chat_image_full_screen.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';

class SharedImages extends StatelessWidget {
  final List<String> imageUrls;
  final Color themeColor;

  const SharedImages({
    super.key,
    required this.imageUrls,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData currentTheme = Theme.of(context);
    if (imageUrls.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 50, color: currentTheme.disabledColor.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text(
                'Chưa có ảnh nào được chia sẻ',
                style: currentTheme.textTheme.bodyMedium
                    ?.copyWith(color: currentTheme.disabledColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            final imageUrl = '${ApiRoutes.serverBaseUrl}${imageUrls[index]}';
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => ChatFullImage(imageUrl: imageUrl),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        color: currentTheme.hoverColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2.5,
                          color: themeColor,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: currentTheme.hoverColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.broken_image_outlined,
                        color: currentTheme.disabledColor, size: 40),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}