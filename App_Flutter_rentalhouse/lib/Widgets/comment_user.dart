import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_routes.dart';
import '../viewmodels/vm_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart';

class CommentSection extends StatefulWidget {
  final String rentalId;
  final ValueChanged<int>? onCommentCountChanged;

  const CommentSection({super.key, required this.rentalId, this.onCommentCountChanged});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
    _fetchComments();
  }

  Future<void> _loadCurrentUserInfo() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final user = authViewModel.currentUser;
    if (user != null) {
      setState(() {
        _currentUsername = user.username.isEmpty ? 'không có' : user.username;
        _currentUserAvatar = user.avatarBase64 != null && user.avatarBase64!.isNotEmpty
            ? 'data:image/jpeg;base64,${user.avatarBase64}'
            : null;
      });
    }
  }

  Future<void> _fetchComments({int page = 1}) async {
    if (page == 1) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.comments}/${widget.rentalId}?page=$page&limit=5'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load comments: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      final commentsData = data['comments'] as List<dynamic>? ?? [];
      final comments = commentsData
          .map((json) => Comment.fromJson(json))
          .where((comment) => comment.userId.id.isNotEmpty)
          .toList();
      setState(() {
        if (page == 1) {
          _comments = comments;
        } else {
          _comments.addAll(comments);
        }
        _totalComments = data['totalComments'] ?? 0;
        _currentPage = data['currentPage'] ?? 1;
        _totalPages = data['totalPages'] ?? 1;
        widget.onCommentCountChanged?.call(_totalComments);
      });
    } catch (e) {
      _showErrorSnackBar('Lỗi khi tải bình luận: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_currentPage < _totalPages) {
      await _fetchComments(page: _currentPage + 1);
    }
  }

  Future<void> _pickImages({bool forReply = false, bool forEdit = false}) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        if (forReply) {
          _selectedReplyImages.addAll(pickedFiles);
        } else if (forEdit) {
          _editSelectedImages.addAll(pickedFiles);
        } else {
          _selectedImages.addAll(pickedFiles);
        }
      });
    }
  }

  Future<void> _postComment() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_commentController.text.isEmpty || authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập và nhập nội dung bình luận');
      return;
    }
    if (_selectedRating < 1 || _selectedRating > 5) {
      setState(() {
        _ratingError = 'Điểm đánh giá phải từ 1 đến 5 sao';
      });
      return;
    }
    setState(() {
      _ratingError = null;
      _isPostingComment = true;
    });
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.comments));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['rentalId'] = widget.rentalId;
      request.fields['content'] = _commentController.text;
      request.fields['rating'] = _selectedRating.round().toString();
      for (var image in _selectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Đăng bình luận thất bại');
      }
      final data = jsonDecode(responseBody);
      final newComment = Comment.fromJson(data);
      setState(() {
        _comments.insert(0, newComment);
        _totalComments++;
        _totalPages = (_totalComments / 5).ceil();
        _commentController.clear();
        _selectedRating = 0.0;
        _selectedImages.clear();
        widget.onCommentCountChanged?.call(_totalComments);
      });
    } catch (e) {
      _showErrorSnackBar('Lỗi khi đăng bình luận: $e');
    } finally {
      setState(() => _isPostingComment = false);
    }
  }

  Future<void> _editComment(String commentId, String newContent) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để chỉnh sửa bình luận');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest('PUT', Uri.parse('${ApiRoutes.comments}/$commentId'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(_editImagesToRemove);
      for (var image in _editSelectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Chỉnh sửa bình luận thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
        _editingCommentId = null;
        _editSelectedImages.clear();
        _editImagesToRemove.clear();
      });
      _showSuccessSnackBar('Chỉnh sửa bình luận thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi chỉnh sửa bình luận: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để xóa bình luận');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final response = await http.delete(
        Uri.parse('${ApiRoutes.comments}/$commentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Xóa bình luận thất bại');
      }
      setState(() {
        _comments.removeWhere((comment) => comment.id == commentId);
        _totalComments--;
        _totalPages = (_totalComments / 5).ceil();
        widget.onCommentCountChanged?.call(_totalComments);
      });
      _showSuccessSnackBar('Xóa bình luận thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi xóa bình luận: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postReply(String commentId, {String? parentReplyId}) async {
    if (_replyController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập nội dung phản hồi');
      return;
    }
    setState(() => _isPostingReply = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final token = authViewModel.currentUser?.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.commentReplies(commentId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = _replyController.text;
      if (parentReplyId != null) {
        request.fields['parentReplyId'] = parentReplyId;
      }
      for (var image in _selectedReplyImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Đăng phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
        _replyController.clear();
        _selectedCommentId = null;
        _selectedReplyId = null;
        _selectedReplyImages.clear();
        _expandedReplies.add(commentId);
      });
    } catch (e) {
      _showErrorSnackBar('Lỗi khi đăng phản hồi: $e');
    } finally {
      setState(() => _isPostingReply = false);
    }
  }

  Future<void> _editReply(String commentId, String replyId, String newContent) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để chỉnh sửa phản hồi');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiRoutes.reply(commentId, replyId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(_editImagesToRemove);
      for (var image in _editSelectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Chỉnh sửa phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
        _editingReplyId = null;
        _editSelectedImages.clear();
        _editImagesToRemove.clear();
      });
      _showSuccessSnackBar('Chỉnh sửa phản hồi thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi chỉnh sửa phản hồi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để xóa phản hồi');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final response = await http.delete(
        Uri.parse('${ApiRoutes.reply(commentId, replyId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Xóa phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(response.body)['comment']);
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
      });
      _showSuccessSnackBar('Xóa phản hồi thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi xóa phản hồi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để thích bình luận');
      return;
    }
    setState(() => _isTogglingLike = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final comment = _comments.firstWhere((c) => c.id == commentId);
      final hasLiked = comment.likes.any((like) => like.userId == authViewModel.currentUser!.id);
      final method = hasLiked ? http.delete : http.post;
      final url = hasLiked
          ? ApiRoutes.unlikeComment(commentId)
          : ApiRoutes.likeComment(commentId);
      final response = await method(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Thao tác like thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(response.body)['comment']);
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
      });
    } catch (e) {
      _showErrorSnackBar('Lỗi khi thao tác like: $e');
    } finally {
      setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _toggleReplyLike(String commentId, String replyId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập để thích phản hồi');
      return;
    }
    setState(() => _isTogglingReplyLike = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final comment = _comments.firstWhere((c) => c.id == commentId);
      Reply? findReply(List<Reply> replies) {
        for (var reply in replies) {
          if (reply.id == replyId) return reply;
          final nestedReply = findReply(reply.replies);
          if (nestedReply != null) return nestedReply;
        }
        return null;
      }
      final reply = findReply(comment.replies);
      if (reply == null) throw Exception('Reply not found');
      final hasLiked = reply.likes.any((like) => like.userId == authViewModel.currentUser!.id);
      final method = hasLiked ? http.delete : http.post;
      final url = hasLiked
          ? ApiRoutes.unlikeReply(commentId, replyId)
          : ApiRoutes.likeReply(commentId, replyId);
      final response = await method(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Thao tác like phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(response.body)['comment']);
      setState(() {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) _comments[index] = updatedComment;
      });
    } catch (e) {
      _showErrorSnackBar('Lỗi khi thao tác like phản hồi: $e');
    } finally {
      setState(() => _isTogglingReplyLike = false);
    }
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

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
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
          _CommentInputField(
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
                return _CommentItem(
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

class _CommentInputField extends StatelessWidget {
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

  const _CommentInputField({
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
  });

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
                    _StarRating(rating: rating, onRatingChanged: onRatingChanged),
                    if (ratingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ratingError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              GestureDetector(
                onTap: onPickImages,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isPosting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

class _StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;

  const _StarRating({required this.rating, required this.onRatingChanged});

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

class _CommentItem extends StatelessWidget {
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

  const _CommentItem({
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
  });

  void _showCommentDropdownMenu(BuildContext context, GlobalKey iconKey) {
    final RenderBox renderBox = iconKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height, // Hiển thị ngay dưới icon
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
        position.dy + size.height, // Hiển thị ngay dưới icon
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.id;
    final isEditing = editingCommentId == comment.id;
    final GlobalKey commentMoreIconKey = GlobalKey(); // Key cho icon của comment

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
                                  key: commentMoreIconKey, // Gắn key vào GestureDetector
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
                  const SizedBox(height: 15,),
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
                          backgroundColor: Colors.blue, // Màu nền
                          foregroundColor: Colors.white, // Màu chữ/icon
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // Bo tròn nút
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
                child: _CommentInputField(
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
        final GlobalKey replyMoreIconKey = GlobalKey(); // Key cho icon của reply

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
                                      key: replyMoreIconKey, // Gắn key vào GestureDetector
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
                      const SizedBox(height: 15,),
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
                              backgroundColor: Colors.blue, // Màu nền
                              foregroundColor: Colors.white, // Màu chữ/icon
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30), // Bo tròn nút
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
                    child: _CommentInputField(
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
}