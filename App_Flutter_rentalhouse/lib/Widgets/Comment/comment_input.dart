import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CommentInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onSubmit;
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final List<XFile> selectedImages;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onCancel;
  final String? ratingError;

  const CommentInputField({
    Key? key,
    required this.controller,
    required this.isPosting,
    required this.onSubmit,
    required this.rating,
    required this.onRatingChanged,
    required this.selectedImages,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onCancel,
    this.ratingError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập bình luận của bạn...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            enabled: !isPosting,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (rating >= 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRating(
                        rating: rating, onRatingChanged: onRatingChanged),
                    if (ratingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ratingError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              GestureDetector(
                onTap: onPickImages,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_a_photo, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        "Thêm ảnh",
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Image.file(
                            File(selectedImages[index].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => onRemoveImage(index),
                              child: Container(
                                color: Colors.black54,
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isPosting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Đăng', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;

  const StarRating(
      {Key? key, required this.rating, required this.onRatingChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final boxWidth = 120.0;
          final starWidth = boxWidth / 5;
          double newRating = (details.localPosition.dx / starWidth).clamp(0, 5);
          newRating = (newRating * 2).roundToDouble() / 2;
          onRatingChanged(newRating);
        },
        onTapDown: (details) {
          final boxWidth = 120.0;
          final starWidth = boxWidth / 5;
          double newRating = (details.localPosition.dx / starWidth).clamp(0, 5);
          newRating = (newRating * 2).roundToDouble() / 2;
          onRatingChanged(newRating);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starValue = (index + 1).toDouble();
            return Icon(
              starValue <= rating
                  ? Icons.star
                  : starValue - 0.5 <= rating
                      ? Icons.star_half
                      : Icons.star_border,
              color: Colors.amber,
              size: 24,
            );
          }),
        ),
      ),
    );
  }
}
