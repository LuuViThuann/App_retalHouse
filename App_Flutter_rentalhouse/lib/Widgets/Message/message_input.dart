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

  const ChatInputArea({
    super.key,
    required this.messageController,
    required this.selectedImages,
    required this.existingImagesToRemove,
    required this.editingMessageId,
    required this.conversationId,
    required this.onCancelEditing,
  });

  Future<void> _pickImages(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null) {
      selectedImages.addAll(images);
      (context as Element).markNeedsBuild();
    }
  }

  Future<void> _sendMessage(BuildContext context, ChatViewModel chatViewModel,
      AuthViewModel authViewModel, String content) async {
    bool isLoading = true;
    (context as Element).markNeedsBuild();
    final success = await chatViewModel.sendMessage(
      conversationId: conversationId,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: selectedImages.map((x) => x.path).toList(),
      senderId: authViewModel.currentUser!.id,
    );
    isLoading = false;
    if (success) {
      messageController.clear();
      selectedImages.clear();
    }
    (context as Element).markNeedsBuild();
    scrollToBottom(ScrollController());
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatViewModel.errorMessage ?? 'Lỗi khi gửi tin nhắn'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _editMessage(BuildContext context, ChatViewModel chatViewModel,
      AuthViewModel authViewModel, String content) async {
    bool isLoading = true;
    (context as Element).markNeedsBuild();
    final success = await chatViewModel.editMessage(
      messageId: editingMessageId!,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: selectedImages.map((x) => x.path).toList(),
      removeImages: existingImagesToRemove,
    );
    isLoading = false;
    if (success) {
      onCancelEditing();
    }
    (context as Element).markNeedsBuild();
    scrollToBottom(ScrollController());
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn đã được chỉnh sửa'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(chatViewModel.errorMessage ?? 'Lỗi khi chỉnh sửa tin nhắn'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (editingMessageId != null &&
              chatViewModel.messages.any((msg) => msg.id == editingMessageId))
            Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: chatViewModel.messages
                    .firstWhere((msg) => msg.id == editingMessageId)
                    .images
                    .length,
                itemBuilder: (context, index) {
                  final imageUrl = chatViewModel.messages
                      .firstWhere((msg) => msg.id == editingMessageId)
                      .images[index];
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: '${ApiRoutes.serverBaseUrl}$imageUrl',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      ),
                      if (!existingImagesToRemove.contains(imageUrl))
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              existingImagesToRemove.add(imageUrl);
                              (context as Element).markNeedsBuild();
                            },
                            child: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (selectedImages.isNotEmpty)
            Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.file(
                          File(selectedImages[index].path),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            selectedImages.removeAt(index);
                            (context as Element).markNeedsBuild();
                          },
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: () => _pickImages(context),
                color: Colors.blue,
              ),
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: editingMessageId == null
                        ? 'Nhập tin nhắn...'
                        : 'Chỉnh sửa tin nhắn...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              if (editingMessageId != null)
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: onCancelEditing,
                  color: Colors.red,
                ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final content = messageController.text.trim();
                  if (!checkAuthentication(authViewModel, context)) return;
                  if (editingMessageId != null) {
                    if (!validateEditInput(content, selectedImages,
                        existingImagesToRemove, context)) return;
                    await _editMessage(
                        context, chatViewModel, authViewModel, content);
                  } else {
                    if (!validateSendInput(content, selectedImages, context))
                      return;
                    await _sendMessage(
                        context, chatViewModel, authViewModel, content);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
