import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/message.dart';
import '../../utils/date_chat.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController messageController;
  final List<XFile> selectedImages;
  final List<String> existingImagesToRemove;
  final String? editingMessageId;
  final String conversationId;
  final VoidCallback onCancelEditing;
  final ScrollController scrollController;
  final Map<String, GlobalKey> messageKeys;

  const ChatInputArea({
    super.key,
    required this.messageController,
    required this.selectedImages,
    required this.existingImagesToRemove,
    required this.editingMessageId,
    required this.conversationId,
    required this.onCancelEditing,
    required this.scrollController,
    required this.messageKeys,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  // ✅ Track existing images được load khi edit
  List<String> _currentExistingImages = [];

  @override
  void didUpdateWidget(ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ CRITICAL: Khi editingMessageId thay đổi, load ảnh hiện tại
    if (widget.editingMessageId != null &&
        oldWidget.editingMessageId != widget.editingMessageId) {
      _loadExistingImages();
    }

    // ✅ Clear khi cancel edit
    if (oldWidget.editingMessageId != null && widget.editingMessageId == null) {
      _currentExistingImages.clear();
    }
  }

  // ✅ Load ảnh hiện tại từ message
  void _loadExistingImages() {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    // ✅ FIX: Dùng firstWhere với orElse thay vì firstWhereOrNull
    Message? message;
    try {
      message = chatViewModel.messages
          .firstWhere((msg) => msg.id == widget.editingMessageId);
    } catch (e) {
      message = null;
    }

    if (message != null && message.images.isNotEmpty) {
      print('📸 [ChatInputArea] Loading existing images for edit:');
      print('   - Message ID: ${message.id}');
      print('   - Images count: ${message.images.length}');
      for (int i = 0; i < message.images.length; i++) {
        print('      [$i] ${message.images[i]}');
      }

      setState(() {
        // ✅ Copy ảnh hiện tại - chỉ những ảnh không bị remove
        _currentExistingImages = message!.images
            .where((img) => !widget.existingImagesToRemove.contains(img))
            .toList();
      });

      print('   ✅ Loaded ${_currentExistingImages.length} images to UI');
    } else {
      print('⚠️ [ChatInputArea] No message found or no images');
      setState(() {
        _currentExistingImages.clear();
      });
    }
  }

  Future<void> _pickImages(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (images != null && images.isNotEmpty) {
      widget.selectedImages.addAll(images);
      print('📸 [ChatInputArea] Picked ${images.length} new images');
      // Force rebuild
      setState(() {});
    }
  }

  void _scrollToMessage(String? messageId) {
    if (widget.scrollController.hasClients) {
      if (messageId != null && widget.messageKeys.containsKey(messageId)) {
        final key = widget.messageKeys[messageId]!;
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (widget.scrollController.hasClients) {
            widget.scrollController.animateTo(
              widget.scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final ValueNotifier<bool> isEditingLoading = ValueNotifier(false);

    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ✅ FIXED: Preview ảnh khi edit (hiển thị ảnh hiện tại)
              if (widget.editingMessageId != null)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // ✅ Hiển thị ảnh cũ (network)
                      ..._currentExistingImages.map((imageUrl) {
                        print('🖼️ [ChatInputArea] Rendering existing image: $imageUrl');

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print('❌ Error loading image: $url');
                                    print('   Error: $error');
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.red[100],
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red[600],
                                        size: 24,
                                      ),
                                    );
                                  },
                                  memCacheHeight: 160,
                                  memCacheWidth: 160,
                                ),
                              ),
                              // ✅ Nút xóa ảnh cũ
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    print('🗑️ Removing image: $imageUrl');
                                    widget.existingImagesToRemove.add(imageUrl);
                                    setState(() {
                                      _currentExistingImages.remove(imageUrl);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red[600],
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      // ✅ Hiển thị ảnh mới (local)
                      ...widget.selectedImages.map((img) {
                        print('🖼️ [ChatInputArea] Rendering new image: ${img.path}');

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(img.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('❌ Error loading local image: $error');
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.red[100],
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red[600],
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // ✅ Nút xóa ảnh mới
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    print('🗑️ Removing new image: ${img.path}');
                                    widget.selectedImages.remove(img);
                                    setState(() {});
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red[600],
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

              // ✅ Preview ảnh mới khi send (chỉ khi không edit)
              if (widget.editingMessageId == null && widget.selectedImages.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...widget.selectedImages.map((img) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(img.path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                    Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.error,
                                          color: Colors.red[400]),
                                    ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  widget.selectedImages.remove(img);
                                  setState(() {});
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red[600],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                        Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),

              // ✅ Input controls
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.image, color: Colors.blue[600]),
                    onPressed: () => _pickImages(context),
                    padding: const EdgeInsets.all(12),
                    style: ButtonStyle(
                      backgroundColor:
                      MaterialStateProperty.all(Colors.grey[100]),
                      shape: MaterialStateProperty.all(const CircleBorder()),
                      elevation: MaterialStateProperty.all(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: widget.messageController,
                        decoration: InputDecoration(
                          hintText: widget.editingMessageId == null
                              ? 'Nhập tin nhắn...'
                              : 'Chỉnh sửa tin nhắn...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontFamily: 'Roboto',
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Roboto'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.editingMessageId != null)
                    IconButton(
                      icon: Icon(Icons.cancel, color: Colors.red[600]),
                      onPressed: widget.onCancelEditing,
                      padding: const EdgeInsets.all(12),
                      style: ButtonStyle(
                        backgroundColor:
                        MaterialStateProperty.all(Colors.grey[100]),
                        shape: MaterialStateProperty.all(const CircleBorder()),
                        elevation: MaterialStateProperty.all(2),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: isEditingLoading,
                    builder: (context, loading, child) {
                      return IconButton(
                        icon: Icon(
                          widget.editingMessageId != null ? Icons.check : Icons.send,
                          color: Colors.blue[600],
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                          final content = widget.messageController.text.trim();
                          if (!checkAuthentication(
                              authViewModel, context)) return;

                          isEditingLoading.value = true;

                          if (widget.editingMessageId != null) {
                            // ✅ Edit message
                            if (!validateEditInput(
                                content,
                                widget.selectedImages,
                                widget.existingImagesToRemove,
                                context)) {
                              isEditingLoading.value = false;
                              return;
                            }
                            final success =
                            await chatViewModel.editMessage(
                              messageId: widget.editingMessageId!,
                              content: content,
                              token: authViewModel.currentUser!.token!,
                              imagePaths: widget.selectedImages
                                  .map((x) => x.path)
                                  .toList(),
                              removeImages: widget.existingImagesToRemove,
                            );
                            isEditingLoading.value = false;

                            if (success) {
                              widget.onCancelEditing();
                              widget.selectedImages.clear();
                              widget.existingImagesToRemove.clear();
                              _currentExistingImages.clear();

                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Tin nhắn đã được chỉnh sửa'),
                                    backgroundColor: Colors.green[600],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                              _scrollToMessage(widget.editingMessageId);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        chatViewModel.errorMessage ??
                                            'Lỗi khi chỉnh sửa tin nhắn'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          } else {
                            // ✅ Send new message
                            if (!validateSendInput(
                                content, widget.selectedImages, context)) {
                              isEditingLoading.value = false;
                              return;
                            }

                            final success =
                            await chatViewModel.sendMessage(
                              conversationId: widget.conversationId,
                              content: content,
                              token: authViewModel.currentUser!.token!,
                              imagePaths: widget.selectedImages
                                  .map((x) => x.path)
                                  .toList(),
                              senderId: authViewModel.currentUser!.id,
                            );
                            isEditingLoading.value = false;

                            if (success) {
                              widget.messageController.clear();
                              widget.selectedImages.clear();
                              setState(() {});
                              _scrollToMessage(null);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        chatViewModel.errorMessage ??
                                            'Lỗi khi gửi tin nhắn'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        padding: const EdgeInsets.all(12),
                        style: ButtonStyle(
                          backgroundColor:
                          MaterialStateProperty.all(Colors.grey[100]),
                          shape:
                          MaterialStateProperty.all(const CircleBorder()),
                          elevation: MaterialStateProperty.all(2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}