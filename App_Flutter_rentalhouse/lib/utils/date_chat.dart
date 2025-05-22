import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:image_picker/image_picker.dart';

bool checkAuthentication(AuthViewModel authViewModel, BuildContext context) {
  if (authViewModel.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng đăng nhập để gửi tin nhắn'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }
  return true;
}

bool validateSendInput(String content, List<XFile> selectedImages, BuildContext context) {
  if (content.isEmpty && selectedImages.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng nhập nội dung hoặc chọn hình ảnh'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }
  return true;
}

bool validateEditInput(String content, List<XFile> selectedImages, List<String> existingImagesToRemove, BuildContext context) {
  if (content.isEmpty && selectedImages.isEmpty && existingImagesToRemove.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng cung cấp nội dung hoặc hình ảnh để chỉnh sửa'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }
  return true;
}

void scrollToBottom(ScrollController scrollController) {
  if (scrollController.hasClients) {
    scrollController.jumpTo(0);
  }
}