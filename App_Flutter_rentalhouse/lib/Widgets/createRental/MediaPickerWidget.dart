import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';

class MediaPickerWidget extends StatefulWidget {
  final ValueNotifier<List<File>> imagesNotifier;
  final ValueNotifier<List<File>> videosNotifier;
  final Function(File) onMediaTap;

  const MediaPickerWidget({
    super.key,
    required this.imagesNotifier,
    required this.videosNotifier,
    required this.onMediaTap,
  });

  @override
  State<MediaPickerWidget> createState() => _MediaPickerWidgetState();
}

class _MediaPickerWidgetState extends State<MediaPickerWidget> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      if (isVideo) {
        final XFile? video = await _picker.pickVideo(source: source);
        if (video != null) {
          // Check file size (max 100MB)
          final file = File(video.path);
          final fileSize = await file.length();
          if (fileSize > 100 * 1024 * 1024) {
            _showError('Video không được vượt quá 100MB');
            return;
          }

          setState(() {
            widget.videosNotifier.value = [
              ...widget.videosNotifier.value,
              file
            ];
          });
        }
      } else {
        final List<XFile> images = source == ImageSource.camera
            ? [(await _picker.pickImage(source: source))!]
            : await _picker.pickMultiImage();

        if (images.isNotEmpty) {
          setState(() {
            widget.imagesNotifier.value = [
              ...widget.imagesNotifier.value,
              ...images.map((xFile) => File(xFile.path))
            ];
          });
        }
      }
    } catch (e) {
      _showError('Lỗi khi chọn ${isVideo ? "video" : "ảnh"}: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMediaPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn ảnh hoặc video',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOption(
              icon: Icons.photo_library_outlined,
              title: 'Thư viện ảnh',
              subtitle: 'Chọn nhiều ảnh từ thiết bị',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.camera_alt_outlined,
              title: 'Chụp ảnh',
              subtitle: 'Chụp ảnh mới bằng camera',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.videocam_outlined,
              title: 'Chọn video',
              subtitle: 'Tối đa 100MB',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.video_call_outlined,
              title: 'Quay video',
              subtitle: 'Quay video mới bằng camera',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.imagesNotifier,
      builder: (context, images, _) {
        return ValueListenableBuilder(
          valueListenable: widget.videosNotifier,
          builder: (context, videos, _) {
            final totalMedia = images.length + videos.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ảnh & Video',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$totalMedia/10',
                      style: TextStyle(
                        fontSize: 14,
                        color: totalMedia >= 10 ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Display selected media
                if (totalMedia > 0) ...[
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: totalMedia,
                      itemBuilder: (context, index) {
                        if (index < images.length) {
                          return _buildImageThumbnail(images[index], index);
                        } else {
                          return _buildVideoThumbnail(
                            videos[index - images.length],
                            index - images.length,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Add media button
                GestureDetector(
                  onTap: totalMedia >= 10 ? null : _showMediaPickerBottomSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: totalMedia >= 10
                          ? Colors.grey[200]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: totalMedia >= 10
                            ? Colors.grey[300]!
                            : Colors.grey[200]!,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: totalMedia >= 10
                                ? Colors.grey[300]
                                : Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: totalMedia >= 10 ? Colors.grey : Colors.blue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          totalMedia >= 10
                              ? 'Đã đạt giới hạn'
                              : 'Thêm ảnh hoặc video',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: totalMedia >= 10
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalMedia >= 10
                              ? 'Tối đa 10 ảnh/video'
                              : 'Ảnh: JPG, PNG | Video: MP4, MOV (max 100MB)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImageThumbnail(File file, int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => widget.onMediaTap(file),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  final newList = [...widget.imagesNotifier.value];
                  newList.removeAt(index);
                  widget.imagesNotifier.value = newList;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 6,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(File file, int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => widget.onMediaTap(file),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FutureBuilder<VideoPlayerController>(
                      future: _initializeVideoController(file),
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data!.value.isInitialized) {
                          return VideoPlayer(snapshot.data!);
                        }
                        return Container(
                          color: Colors.black87,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  final newList = [...widget.videosNotifier.value];
                  newList.removeAt(index);
                  widget.videosNotifier.value = newList;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 6,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<VideoPlayerController> _initializeVideoController(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    return controller;
  }
}