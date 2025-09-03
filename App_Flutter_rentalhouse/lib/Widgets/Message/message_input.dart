import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../utils/date_chat.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController messageController;
  final List<XFile> selectedImages;
  final List<String> existingImagesToRemove;
  final String? editingMessageId;
  final String conversationId;
  final VoidCallback onCancelEditing;
  final ScrollController scrollController; // Thêm ScrollController
  final Map<String, GlobalKey>
      messageKeys; // Thêm Map để lưu GlobalKey của tin nhắn

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

  Future<void> _pickImages(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (images != null && images.isNotEmpty) {
      selectedImages.addAll(images);
      Provider.of<ChatViewModel>(context, listen: false).notifyListeners();
    }
  }

  void _scrollToMessage(String? messageId) {
    if (scrollController.hasClients) {
      if (messageId != null && messageKeys.containsKey(messageId)) {
        final key = messageKeys[messageId]!;
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5, // Đặt tin nhắn ở giữa màn hình
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        // Nếu không có messageId hoặc key, cuộn xuống dưới cùng
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

//Code xử lý gửi tin nhắn --------------------------
  Future<void> _sendMessage(BuildContext context, ChatViewModel chatViewModel,
      AuthViewModel authViewModel, String content) async {
    final success = await chatViewModel.sendMessage(
      conversationId: conversationId,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: selectedImages.map((x) => x.path).toList(),
      senderId: authViewModel.currentUser!.id,
    );
    if (success) {
      messageController.clear();
      selectedImages.clear();
      Provider.of<ChatViewModel>(context, listen: false).notifyListeners();
      // Cuộn xuống tin nhắn mới nhất (không cần messageId vì là tin nhắn mới)
      _scrollToMessage(null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatViewModel.errorMessage ?? 'Lỗi khi gửi tin nhắn'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _editMessage(BuildContext context, ChatViewModel chatViewModel,
      AuthViewModel authViewModel, String content) async {
    final success = await chatViewModel.editMessage(
      messageId: editingMessageId!,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: selectedImages.map((x) => x.path).toList(),
      removeImages: existingImagesToRemove,
    );
    if (success) {
      onCancelEditing();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tin nhắn đã được chỉnh sửa'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // Cuộn đến tin nhắn vừa chỉnh sửa
      _scrollToMessage(editingMessageId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(chatViewModel.errorMessage ?? 'Lỗi khi chỉnh sửa tin nhắn'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    // Thêm biến loading để disable nút khi đang gửi/chỉnh sửa
    final ValueNotifier<bool> isEditingLoading = ValueNotifier(false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (editingMessageId != null &&
              chatViewModel.messages.any((msg) => msg.id == editingMessageId))
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Render ảnh network (cũ)
                  ...chatViewModel.messages
                      .firstWhere((msg) => msg.id == editingMessageId)
                      .images
                      .where((img) => !existingImagesToRemove.contains(img))
                      .map((imageUrl) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        '${ApiRoutes.serverBaseUrl}$imageUrl',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: Center(
                                          child: CircularProgressIndicator(
                                        color: Colors.blue[400],
                                      )),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                        Icons.error,
                                        color: Colors.red[400]),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      existingImagesToRemove.add(imageUrl);
                                      chatViewModel.updateMessageById(
                                        editingMessageId!,
                                        chatViewModel.messages.firstWhere(
                                            (msg) =>
                                                msg.id == editingMessageId!),
                                      );
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
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.cancel,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  // Render ảnh local (mới thêm) chỉ bằng Image.file
                  ...selectedImages.map((img) => Padding(
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
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.error, color: Colors.red[400]),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  selectedImages.remove(img);
                                  chatViewModel.updateMessageById(
                                    editingMessageId!,
                                    chatViewModel.messages.firstWhere(
                                        (msg) => msg.id == editingMessageId!),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red[600],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.cancel,
                                    color: Colors.white,
                                    size: 24,
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
          Row(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                child: IconButton(
                  icon: Icon(Icons.image, color: Colors.blue[600]),
                  onPressed: () => _pickImages(context),
                  padding: EdgeInsets.all(12),
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.grey[100]),
                    shape: MaterialStateProperty.all(CircleBorder()),
                    elevation: MaterialStateProperty.all(2),
                  ),
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
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: editingMessageId == null
                          ? 'Nhập tin nhắn...'
                          : 'Chỉnh sửa tin nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontFamily: 'Roboto',
                      ),
                    ),
                    style: TextStyle(fontFamily: 'Roboto'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (editingMessageId != null)
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  child: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red[600]),
                    onPressed: onCancelEditing,
                    padding: EdgeInsets.all(12),
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.grey[100]),
                      shape: MaterialStateProperty.all(CircleBorder()),
                      elevation: MaterialStateProperty.all(2),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                child: ValueListenableBuilder<bool>(
                  valueListenable: isEditingLoading,
                  builder: (context, loading, child) {
                    return IconButton(
                      icon: Icon(
                        editingMessageId != null ? Icons.check : Icons.send,
                        color: Colors.blue[600],
                      ),
                      onPressed: loading
                          ? null
                          : () async {
                              final content = messageController.text.trim();
                              if (!checkAuthentication(authViewModel, context))
                                return;
                              isEditingLoading.value = true;
                              if (editingMessageId != null) {
                                if (!validateEditInput(content, selectedImages,
                                    existingImagesToRemove, context)) {
                                  isEditingLoading.value = false;
                                  return;
                                }
                                final success = await chatViewModel.editMessage(
                                  messageId: editingMessageId!,
                                  content: content,
                                  token: authViewModel.currentUser!.token!,
                                  imagePaths: selectedImages
                                      .map((x) => x.path)
                                      .toList(),
                                  removeImages: existingImagesToRemove,
                                );
                                isEditingLoading.value = false;
                                if (success) {
                                  onCancelEditing();
                                  selectedImages.clear();
                                  existingImagesToRemove.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Tin nhắn đã được chỉnh sửa'),
                                      backgroundColor: Colors.green[600],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  _scrollToMessage(editingMessageId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          chatViewModel.errorMessage ??
                                              'Lỗi khi chỉnh sửa tin nhắn'),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (!validateSendInput(
                                    content, selectedImages, context)) {
                                  isEditingLoading.value = false;
                                  return;
                                }
                                final success = await chatViewModel.sendMessage(
                                  conversationId: conversationId,
                                  content: content,
                                  token: authViewModel.currentUser!.token!,
                                  imagePaths: selectedImages
                                      .map((x) => x.path)
                                      .toList(),
                                  senderId: authViewModel.currentUser!.id,
                                );
                                isEditingLoading.value = false;
                                if (success) {
                                  messageController.clear();
                                  selectedImages.clear();
                                  Provider.of<ChatViewModel>(context,
                                          listen: false)
                                      .notifyListeners();
                                  _scrollToMessage(null);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          chatViewModel.errorMessage ??
                                              'Lỗi khi gửi tin nhắn'),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      padding: EdgeInsets.all(12),
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.grey[100]),
                        shape: MaterialStateProperty.all(CircleBorder()),
                        elevation: MaterialStateProperty.all(2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
