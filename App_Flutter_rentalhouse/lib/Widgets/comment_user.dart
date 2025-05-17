import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/comment_input.dart';
import 'package:flutter_rentalhouse/Widgets/comment_items.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/services/comment_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:lottie/lottie.dart';
import '../config/api_routes.dart';
import '../viewmodels/vm_auth.dart';

class CommentSection extends StatefulWidget {
  final String rentalId;
  final ValueChanged<int>? onCommentCountChanged;

  const CommentSection({super.key, required this.rentalId, this.onCommentCountChanged});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  String? _currentUserAvatar;
  String? _currentUsername;
  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isPostingComment = false;
  bool _isPostingReply = false;
  bool _isTogglingLike = false;
  bool _isTogglingReplyLike = false;
  String? _selectedCommentId;
  String? _selectedReplyId;
  String? _editingCommentId;
  String? _editingReplyId;
  double _selectedRating = 0.0;
  String? _ratingError;
  List<XFile> _selectedImages = [];
  List<XFile> _selectedReplyImages = [];
  List<XFile> _editSelectedImages = [];
  List<String> _editImagesToRemove = [];
  Set<String> _expandedReplies = {};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalComments = 0;
  bool _isLoadingMore = false;
  late AnimationController _controller;
  final CommentService _commentService = CommentService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadUserInfo();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _loadUserInfo() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.loadCurrentUserInfo(
      authViewModel: authViewModel,
      onUserInfoLoaded: (username, avatar) {
        setState(() {
          _currentUsername = username;
          _currentUserAvatar = avatar;
        });
      },
    );
  }

  void _fetchComments({int page = 1}) {
    _commentService.fetchComments(
      rentalId: widget.rentalId,
      page: page,
      onCommentsLoaded: (comments, totalComments, currentPage, totalPages) {
        setState(() {
          if (page == 1) {
            _comments = comments;
          } else {
            _comments.addAll(comments);
          }
          _totalComments = totalComments;
          _currentPage = currentPage;
          _totalPages = totalPages;
          widget.onCommentCountChanged?.call(_totalComments);
        });
      },
      onError: _showErrorSnackBar,
      setLoading: (value) => setState(() => _isLoading = value),
      setLoadingMore: (value) => setState(() => _isLoadingMore = value),
    );
  }

  void _loadMoreComments() {
    if (_currentPage < _totalPages) {
      _fetchComments(page: _currentPage + 1);
    }
  }

  void _pickImages({bool forReply = false, bool forEdit = false}) {
    _commentService.pickImages(
      forReply: forReply,
      forEdit: forEdit,
      selectedImages: _selectedImages,
      selectedReplyImages: _selectedReplyImages,
      editSelectedImages: _editSelectedImages,
      updateImages: (updatedImages) {
        setState(() {
          if (forReply) {
            _selectedReplyImages = updatedImages;
          } else if (forEdit) {
            _editSelectedImages = updatedImages;
          } else {
            _selectedImages = updatedImages;
          }
        });
      },
    );
  }

  void _postComment() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.postComment(
      authViewModel: authViewModel,
      rentalId: widget.rentalId,
      content: _commentController.text,
      rating: _selectedRating,
      selectedImages: _selectedImages,
      commentController: _commentController,
      onCommentPosted: (newComment, totalCommentsIncrement, totalPages) {
        setState(() {
          _comments.insert(0, newComment);
          _totalComments += totalCommentsIncrement;
          _totalPages = totalPages;
          _selectedRating = 0.0;
          _selectedImages.clear();
          widget.onCommentCountChanged?.call(_totalComments);
        });
      },
      onError: _showErrorSnackBar,
      setPosting: (isPosting, ratingError) {
        setState(() {
          _isPostingComment = isPosting;
          _ratingError = ratingError;
        });
      },
    );
  }

  void _editComment(String commentId, String newContent) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.editComment(
      authViewModel: authViewModel,
      commentId: commentId,
      newContent: newContent,
      editSelectedImages: _editSelectedImages,
      editImagesToRemove: _editImagesToRemove,
      onCommentEdited: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
          _editingCommentId = null;
          _editSelectedImages.clear();
          _editImagesToRemove.clear();
        });
        _showSuccessSnackBar('Chỉnh sửa bình luận thành công');
      },
      onError: _showErrorSnackBar,
      setLoading: (value) => setState(() => _isLoading = value),
    );
  }

  void _deleteComment(String commentId) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.deleteComment(
      authViewModel: authViewModel,
      commentId: commentId,
      onCommentDeleted: (totalCommentsDecrement, totalPages) {
        setState(() {
          _comments.removeWhere((comment) => comment.id == commentId);
          _totalComments -= totalCommentsDecrement;
          _totalPages = (_totalComments / 5).ceil();
          widget.onCommentCountChanged?.call(_totalComments);
        });
        _showSuccessSnackBar('Xóa bình luận thành công');
      },
      onError: _showErrorSnackBar,
      setLoading: (value) => setState(() => _isLoading = value),
    );
  }

  void _postReply(String commentId, {String? parentReplyId}) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.postReply(
      authViewModel: authViewModel,
      commentId: commentId,
      content: _replyController.text,
      selectedReplyImages: _selectedReplyImages,
      replyController: _replyController,
      parentReplyId: parentReplyId,
      onReplyPosted: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
          _selectedCommentId = null;
          _selectedReplyId = null;
          _selectedReplyImages.clear();
          _expandedReplies.add(commentId);
        });
      },
      onError: _showErrorSnackBar,
      setPostingReply: (value) => setState(() => _isPostingReply = value),
    );
  }

  void _editReply(String commentId, String replyId, String newContent) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.editReply(
      authViewModel: authViewModel,
      commentId: commentId,
      replyId: replyId,
      newContent: newContent,
      editSelectedImages: _editSelectedImages,
      editImagesToRemove: _editImagesToRemove,
      onReplyEdited: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
          _editingReplyId = null;
          _editSelectedImages.clear();
          _editImagesToRemove.clear();
        });
        _showSuccessSnackBar('Chỉnh sửa phản hồi thành công');
      },
      onError: _showErrorSnackBar,
      setLoading: (value) => setState(() => _isLoading = value),
    );
  }

  void _deleteReply(String commentId, String replyId) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.deleteReply(
      authViewModel: authViewModel,
      commentId: commentId,
      replyId: replyId,
      onReplyDeleted: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
        });
        _showSuccessSnackBar('Xóa phản hồi thành công');
      },
      onError: _showErrorSnackBar,
      setLoading: (value) => setState(() => _isLoading = value),
    );
  }

  void _toggleLike(String commentId) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.toggleLike(
      authViewModel: authViewModel,
      commentId: commentId,
      comments: _comments,
      onLikeToggled: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
          _showLikeAnimation();
        });
      },
      onError: _showErrorSnackBar,
      setTogglingLike: (value) => setState(() => _isTogglingLike = value),
    );
  }

  void _toggleReplyLike(String commentId, String replyId) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _commentService.toggleReplyLike(
      authViewModel: authViewModel,
      commentId: commentId,
      replyId: replyId,
      comments: _comments,
      onReplyLikeToggled: (updatedComment) {
        setState(() {
          final index = _comments.indexWhere((c) => c.id == commentId);
          if (index != -1) _comments[index] = updatedComment;
          _showLikeAnimation();
        });
      },
      onError: _showErrorSnackBar,
      setTogglingReplyLike: (value) => setState(() => _isTogglingReplyLike = value),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: PhotoView(
                  imageProvider: NetworkImage('${ApiRoutes.serverBaseUrl}$imageUrl'),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLikeAnimation() {
    _controller.reset();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Lottie.asset(
          'assets/lottie/like.json',
          controller: _controller,
          width: 100,
          height: 100,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
            _controller.forward().then((_) => Navigator.pop(context));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUserId = authViewModel.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Bình luận / đánh giá'),
          const SizedBox(height: 16),
          CommentInputField(
            controller: _commentController,
            isPosting: _isPostingComment,
            onSubmit: _postComment,
            rating: _selectedRating,
            onRatingChanged: (rating) => setState(() => _selectedRating = rating),
            selectedImages: _selectedImages,
            onPickImages: () => _pickImages(),
            onRemoveImage: (index) => setState(() => _selectedImages.removeAt(index)),
            onCancel: () => setState(() {
              _commentController.clear();
              _selectedRating = 0.0;
              _selectedImages.clear();
              _ratingError = null;
            }),
            ratingError: _ratingError,
          ),
          const SizedBox(height: 16),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (!_isLoading && _comments.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length + (_currentPage < _totalPages ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _comments.length && _currentPage < _totalPages) {
                  return _LoadMoreButton(
                    isLoading: _isLoadingMore,
                    onPressed: _loadMoreComments,
                    label: 'Hiển thị thêm bình luận',
                  );
                }
                final comment = _comments[index];
                final user = comment.userId;
                final hasLiked = comment.likes.any((like) => like.userId == currentUserId);
                final isOwnComment = user.id == currentUserId;
                final isExpanded = _expandedReplies.contains(comment.id);
                return CommentItem(
                  comment: comment,
                  user: user,
                  hasLiked: hasLiked,
                  isOwnComment: isOwnComment,
                  isTogglingLike: _isTogglingLike,
                  isTogglingReplyLike: _isTogglingReplyLike,
                  isPostingReply: _isPostingReply,
                  selectedCommentId: _selectedCommentId,
                  selectedReplyId: _selectedReplyId,
                  editingCommentId: _editingCommentId,
                  editingReplyId: _editingReplyId,
                  editController: _editController,
                  replyController: _replyController,
                  isExpanded: isExpanded,
                  selectedReplyImages: _selectedReplyImages,
                  editSelectedImages: _editSelectedImages,
                  editImagesToRemove: _editImagesToRemove,
                  onDelete: () => _deleteComment(comment.id),
                  onToggleLike: () => _toggleLike(comment.id),
                  onToggleReplyLike: (replyId) => _toggleReplyLike(comment.id, replyId),
                  onReply: () => setState(() => _selectedCommentId = comment.id),
                  onReplyToReply: (replyId) => setState(() {
                    _selectedCommentId = comment.id;
                    _selectedReplyId = replyId;
                  }),
                  onCancelReply: () => setState(() {
                    _selectedCommentId = null;
                    _selectedReplyId = null;
                    _replyController.clear();
                    _selectedReplyImages.clear();
                  }),
                  onSubmitReply: () => _postReply(comment.id, parentReplyId: _selectedReplyId),
                  onEditComment: () {
                    setState(() {
                      _editingCommentId = comment.id;
                      _editController.text = comment.content;
                      _editImagesToRemove.clear();
                      _editSelectedImages.clear();
                    });
                  },
                  onSaveEditComment: (newContent) => _editComment(comment.id, newContent),
                  onCancelEdit: () => setState(() {
                    _editingCommentId = null;
                    _editingReplyId = null;
                    _editImagesToRemove.clear();
                    _editSelectedImages.clear();
                  }),
                  onToggleReplies: () => setState(() {
                    if (isExpanded) {
                      _expandedReplies.remove(comment.id);
                    } else {
                      _expandedReplies.add(comment.id);
                    }
                  }),
                  onEditReply: (replyId, content) {
                    setState(() {
                      _editingReplyId = replyId;
                      _editController.text = content;
                      _editImagesToRemove.clear();
                      _editSelectedImages.clear();
                    });
                  },
                  onSaveEditReply: (replyId, newContent) => _editReply(comment.id, replyId, newContent),
                  onDeleteReply: (replyId) => _deleteReply(comment.id, replyId),
                  onImageTap: _showFullScreenImage,
                  onPickReplyImages: () => _pickImages(forReply: true),
                  onRemoveReplyImage: (index) => setState(() => _selectedReplyImages.removeAt(index)),
                  onPickEditImages: () => _pickImages(forEdit: true),
                  onRemoveEditImage: (index) => setState(() => _editSelectedImages.removeAt(index)),
                  onRemoveExistingImage: (imageUrl) => setState(() {
                    _editImagesToRemove.add(imageUrl);
                  }),
                );
              },
            ),
          if (!_isLoading && _comments.isEmpty)
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('Chưa có bình luận nào!', style: TextStyle(color: Colors.grey))),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  const _LoadMoreButton({required this.isLoading, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoading
          ? const CircularProgressIndicator()
          : TextButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(color: Colors.blue)),
      ),
    );
  }
}