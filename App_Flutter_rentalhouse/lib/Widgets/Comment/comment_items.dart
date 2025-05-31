import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Comment/comment_input.dart';
import 'package:flutter_rentalhouse/models/Reply.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/vm_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_routes.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final User user;
  final bool hasLiked;
  final bool isOwnComment;
  final bool isTogglingLike;
  final bool isTogglingReplyLike;
  final bool isPostingReply;
  final String? selectedCommentId;
  final String? selectedReplyId;
  final String? editingCommentId;
  final String? editingReplyId;
  final TextEditingController editController;
  final TextEditingController replyController;
  final bool isExpanded;
  final List<XFile> selectedReplyImages;
  final List<XFile> editSelectedImages;
  final List<String> editImagesToRemove;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;
  final ValueChanged<String> onToggleReplyLike;
  final VoidCallback onReply;
  final ValueChanged<String> onReplyToReply;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitReply;
  final VoidCallback onEditComment;
  final ValueChanged<String> onSaveEditComment;
  final VoidCallback onCancelEdit;
  final VoidCallback onToggleReplies;
  final void Function(String, String) onEditReply;
  final Function(String, String) onSaveEditReply;
  final ValueChanged<String> onDeleteReply;
  final ValueChanged<String> onImageTap;
  final VoidCallback onPickReplyImages;
  final ValueChanged<int> onRemoveReplyImage;
  final VoidCallback onPickEditImages;
  final ValueChanged<int> onRemoveEditImage;
  final ValueChanged<String> onRemoveExistingImage;

  const CommentItem({
    Key? key,
    required this.comment,
    required this.user,
    required this.hasLiked,
    required this.isOwnComment,
    required this.isTogglingLike,
    required this.isTogglingReplyLike,
    required this.isPostingReply,
    required this.selectedCommentId,
    required this.selectedReplyId,
    required this.editingCommentId,
    required this.editingReplyId,
    required this.editController,
    required this.replyController,
    required this.isExpanded,
    required this.selectedReplyImages,
    required this.editSelectedImages,
    required this.editImagesToRemove,
    required this.onDelete,
    required this.onToggleLike,
    required this.onToggleReplyLike,
    required this.onReply,
    required this.onReplyToReply,
    required this.onCancelReply,
    required this.onSubmitReply,
    required this.onEditComment,
    required this.onSaveEditComment,
    required this.onCancelEdit,
    required this.onToggleReplies,
    required this.onEditReply,
    required this.onSaveEditReply,
    required this.onDeleteReply,
    required this.onImageTap,
    required this.onPickReplyImages,
    required this.onRemoveReplyImage,
    required this.onPickEditImages,
    required this.onRemoveEditImage,
    required this.onRemoveExistingImage,
  }) : super(key: key);

  void _showCommentDropdownMenu(BuildContext context, GlobalKey iconKey) {
    final RenderBox renderBox = iconKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Chỉnh sửa', style: TextStyle(color: Colors.blue)),
            onTap: () {
              Navigator.pop(context);
              onEditComment();
            },
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Xóa', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
    );
  }

  void _showReplyDropdownMenu(BuildContext context, String replyId, String parentCommentId, GlobalKey iconKey) {
    final RenderBox renderBox = iconKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Chỉnh sửa', style: TextStyle(color: Colors.blue)),
            onTap: () {
              Navigator.pop(context);
              Reply? findReply(List<Reply> replies) {
                for (var reply in replies) {
                  if (reply.id == replyId) return reply;
                  final nestedReply = findReply(reply.replies);
                  if (nestedReply != null) return nestedReply;
                }
                return null;
              }
              final reply = findReply(comment.replies);
              if (reply != null) {
                onEditReply(replyId, reply.content);
              }
            },
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Xóa', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onDeleteReply(replyId);
            },
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
    );
  }

  List<Reply> _flattenReplies(List<Reply> replies) {
    List<Reply> flattened = [];
    void flatten(List<Reply> replies) {
      for (var reply in replies) {
        flattened.add(reply);
        flatten(reply.replies);
      }
    }
    flatten(replies);
    return flattened;
  }

  Widget _buildReplies(BuildContext context, List<Reply> replies, String commentId) {
    final currentUserId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.id;
    final flattenedReplies = _flattenReplies(replies);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: flattenedReplies.length,
      itemBuilder: (context, index) {
        final reply = flattenedReplies[index];
        final isEditingReply = editingReplyId == reply.id;
        final hasLikedReply = reply.likes.any((like) => like.userId == currentUserId);
        final isOwnReply = reply.userId.id == currentUserId;
        final GlobalKey replyMoreIconKey = GlobalKey();

        return Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: reply.userId.avatarBytes != null
                              ? MemoryImage(reply.userId.avatarBytes!)
                              : const AssetImage('assets/img/imageuser.png') as ImageProvider,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reply.userId.username.isEmpty ? 'không có' : reply.userId.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(reply.createdAt),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                  ),
                                  if (isOwnReply)
                                    GestureDetector(
                                      key: replyMoreIconKey,
                                      onTap: () => _showReplyDropdownMenu(context, reply.id, commentId, replyMoreIconKey),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Icon(Icons.more_horiz, color: Colors.grey[600], size: 22),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isEditingReply)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: editController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: onPickEditImages,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
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
                      ),
                      const SizedBox(height: 15),
                      if (reply.images.isNotEmpty || editSelectedImages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: reply.images.length + editSelectedImages.length,
                              itemBuilder: (context, index) {
                                if (index < reply.images.length) {
                                  final imageUrl = reply.images[index];
                                  if (editImagesToRemove.contains(imageUrl)) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () => onImageTap(imageUrl),
                                          child: CachedNetworkImage(
                                            imageUrl: '${ApiRoutes.serverBaseUrl}$imageUrl',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const CircularProgressIndicator(),
                                            errorWidget: (context, url, error) => const Icon(Icons.error),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => onRemoveExistingImage(imageUrl),
                                            child: Container(
                                              color: Colors.black54,
                                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  final newImageIndex = index - reply.images.length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        Image.file(
                                          File(editSelectedImages[newImageIndex].path),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => onRemoveEditImage(newImageIndex),
                                            child: Container(
                                              color: Colors.black54,
                                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: onCancelEdit,
                            child: const Text('Hủy'),
                          ),
                          ElevatedButton(
                            onPressed: () => onSaveEditReply(reply.id, editController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reply.content, style: const TextStyle(fontSize: 12)),
                      if (reply.images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: reply.images.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => onImageTap(reply.images[index]),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: CachedNetworkImage(
                                      imageUrl: '${ApiRoutes.serverBaseUrl}${reply.images[index]}',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            hasLikedReply ? Icons.favorite : Icons.favorite_border,
                            color: hasLikedReply ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          onPressed: isTogglingReplyLike ? null : () => onToggleReplyLike(reply.id),
                        ),
                        Text('${reply.likes.length}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => onReplyToReply(reply.id),
                          child: const Text('Phản hồi', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (selectedCommentId == commentId && selectedReplyId == reply.id)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CommentInputField(
                      controller: replyController,
                      isPosting: isPostingReply,
                      onSubmit: onSubmitReply,
                      rating: -1,
                      onRatingChanged: (_) {},
                      selectedImages: selectedReplyImages,
                      onPickImages: onPickReplyImages,
                      onRemoveImage: onRemoveReplyImage,
                      onCancel: onCancelReply,
                      ratingError: null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.id;
    final isEditing = editingCommentId == comment.id;
    final GlobalKey commentMoreIconKey = GlobalKey();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user.avatarBytes != null
                      ? MemoryImage(user.avatarBytes!)
                      : const AssetImage('assets/img/imageuser.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            user.username.isEmpty ? 'không có' : user.username,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              if (isOwnComment)
                                GestureDetector(
                                  key: commentMoreIconKey,
                                  onTap: () => _showCommentDropdownMenu(context, commentMoreIconKey),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Icon(Icons.more_horiz, color: Colors.grey[600], size: 27),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (comment.rating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < comment.rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: editController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: onPickEditImages,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
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
                  ),
                  const SizedBox(height: 15),
                  if (comment.images.isNotEmpty || editSelectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: comment.images.length + editSelectedImages.length,
                          itemBuilder: (context, index) {
                            if (index < comment.images.length) {
                              final imageUrl = comment.images[index];
                              if (editImagesToRemove.contains(imageUrl)) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => onImageTap(imageUrl),
                                      child: CachedNetworkImage(
                                        imageUrl: '${ApiRoutes.serverBaseUrl}$imageUrl',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => onRemoveExistingImage(imageUrl),
                                        child: Container(
                                          color: Colors.black54,
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              final newImageIndex = index - comment.images.length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    Image.file(
                                      File(editSelectedImages[newImageIndex].path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => onRemoveEditImage(newImageIndex),
                                        child: Container(
                                          color: Colors.black54,
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancelEdit,
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        onPressed: () => onSaveEditComment(editController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Lưu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.content, style: const TextStyle(fontSize: 14)),
                  if (comment.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: comment.images.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => onImageTap(comment.images[index]),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CachedNetworkImage(
                                  imageUrl: '${ApiRoutes.serverBaseUrl}${comment.images[index]}',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        hasLiked ? Icons.favorite : Icons.favorite_border,
                        color: hasLiked ? Colors.red : Colors.grey,
                      ),
                      onPressed: isTogglingLike ? null : onToggleLike,
                    ),
                    Text('${comment.likes.length}'),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: onReply,
                      child: const Text('Phản hồi'),
                    ),
                  ],
                ),
              ],
            ),
            if (selectedCommentId == comment.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CommentInputField(
                  controller: replyController,
                  isPosting: isPostingReply,
                  onSubmit: onSubmitReply,
                  rating: -1,
                  onRatingChanged: (_) {},
                  selectedImages: selectedReplyImages,
                  onPickImages: onPickReplyImages,
                  onRemoveImage: onRemoveReplyImage,
                  onCancel: onCancelReply,
                  ratingError: null,
                ),
              ),
            if (comment.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: onToggleReplies,
                  child: Text(
                    isExpanded ? 'Ẩn ${comment.replies.length} phản hồi' : 'Xem ${comment.replies.length} phản hồi',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            if (isExpanded && comment.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildReplies(context, comment.replies, comment.id),
              ),
          ],
        ),
      ),
    );
  }
}