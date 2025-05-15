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

class CommentSection extends StatefulWidget {
  final String rentalId;

  const CommentSection({super.key, required this.rentalId});

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
  String? _selectedCommentId; // For replying
  String? _editingCommentId; // For editing comments
  String? _editingReplyId; // For editing replies
  double _selectedRating = 0.0;
  List<XFile> _selectedImages = []; // For image uploads
  Set<String> _expandedReplies = {}; // Track which comments have expanded replies

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

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('${ApiRoutes.rentals}/${widget.rentalId}'));
      if (response.statusCode != 200) {
        throw Exception('Failed to load comments: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      final commentsData = data['comments'] as List<dynamic>? ?? [];
      final comments = commentsData
          .map((json) => Comment.fromJson(json))
          .where((comment) => comment.userId.id.isNotEmpty)
          .toList();
      setState(() => _comments = comments);
    } catch (e) {
      _showErrorSnackBar('Lỗi khi tải bình luận: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _selectedImages = pickedFiles;
      });
    }
  }

  Future<void> _postComment() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_commentController.text.isEmpty || authViewModel.currentUser == null) {
      _showErrorSnackBar('Vui lòng đăng nhập và nhập nội dung bình luận');
      return;
    }

    setState(() => _isPostingComment = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiRoutes.comments),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['rentalId'] = widget.rentalId;
      request.fields['content'] = _commentController.text;
      request.fields['rating'] = _selectedRating.toString();

      for (var image in _selectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 201) {
        final errorBody = jsonDecode(responseBody);
        throw Exception(errorBody['message'] ?? 'Đăng bình luận thất bại');
      }

      final data = jsonDecode(responseBody);
      if (data is! Map<String, dynamic> || !data.containsKey('_id')) {
        throw Exception('Invalid response structure: $data');
      }

      final newComment = Comment.fromJson(data);
      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
        _selectedRating = 0.0;
        _selectedImages.clear();
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
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final response = await http.put(
        Uri.parse('${ApiRoutes.comments}/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': newContent}),
      );

      if (response.statusCode != 200) {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Chỉnh sửa bình luận thất bại';
        throw Exception(errorMsg);
      }

      await _fetchComments();
      setState(() {
        _editingCommentId = null;
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
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final response = await http.delete(
        Uri.parse('${ApiRoutes.comments}/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Xóa bình luận thất bại';
        throw Exception(errorMsg);
      }

      setState(() {
        _comments.removeWhere((comment) => comment.id == commentId);
      });
      _showSuccessSnackBar('Xóa bình luận thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi xóa bình luận: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postReply(String commentId) async {
    if (_replyController.text.isEmpty) return;
    setState(() => _isPostingReply = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final token = authViewModel.currentUser?.token;
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final response = await http.post(
        Uri.parse(ApiRoutes.commentReplies(commentId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': _replyController.text}),
      );

      if (response.statusCode != 201) {
        throw Exception('Đăng phản hồi thất bại: ${response.body}');
      }

      setState(() {
        _replyController.clear();
        _selectedCommentId = null;
      });
      await _fetchComments();
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
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final response = await http.put(
        Uri.parse('${ApiRoutes.comments}/$commentId/replies/$replyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': newContent}),
      );

      if (response.statusCode != 200) {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Chỉnh sửa phản hồi thất bại';
        throw Exception(errorMsg);
      }

      await _fetchComments();
      setState(() {
        _editingReplyId = null;
      });
      _showSuccessSnackBar('Chỉnh sửa phản hồi thành công');
    } catch (e) {
      _showErrorSnackBar('Lỗi khi chỉnh sửa phản hồi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.currentUser?.id;
    final comment = _comments.firstWhere((c) => c.id == commentId,
        orElse: () => Comment(id: '', rentalId: '', userId: const User(id: ''), content: '', rating: 0.0, images: [], createdAt: DateTime.now(), replies: const [], likes: const []));
    final hasLiked = comment.likes.any((like) => like.userId == userId);

    setState(() => _isTogglingLike = true);
    try {
      final token = authViewModel.currentUser?.token;
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final url = hasLiked ? ApiRoutes.unlikeComment(commentId) : ApiRoutes.likeComment(commentId);
      final response = hasLiked
          ? await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          : await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Thao tác like thất bại: ${response.body}');
      }

      await _fetchComments();
    } catch (e) {
      _showErrorSnackBar('Lỗi khi thao tác like: $e');
    } finally {
      setState(() => _isTogglingLike = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Bình luận'),
        const SizedBox(height: 16),
        _CommentInputField(
          controller: _commentController,
          isPosting: _isPostingComment,
          onSubmit: _postComment,
          rating: _selectedRating,
          onRatingChanged: (rating) {
            setState(() => _selectedRating = rating);
          },
          selectedImages: _selectedImages,
          onPickImages: _pickImages,
          onRemoveImage: (index) {
            setState(() {
              _selectedImages.removeAt(index);
            });
          },
        ),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        if (!_isLoading && _comments.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
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
                isPostingReply: _isPostingReply,
                selectedCommentId: _selectedCommentId,
                editingCommentId: _editingCommentId,
                editingReplyId: _editingReplyId,
                editController: _editController,
                replyController: _replyController,
                isExpanded: isExpanded,
                onDelete: () => _deleteComment(comment.id),
                onToggleLike: () => _toggleLike(comment.id),
                onReply: () => setState(() => _selectedCommentId = comment.id),
                onSubmitReply: () => _postReply(comment.id),
                onEditComment: () {
                  setState(() {
                    _editingCommentId = comment.id;
                    _editController.text = comment.content;
                  });
                },
                onSaveEditComment: (newContent) => _editComment(comment.id, newContent),
                onCancelEdit: () {
                  setState(() {
                    _editingCommentId = null;
                    _editingReplyId = null;
                  });
                },
                onToggleReplies: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedReplies.remove(comment.id);
                    } else {
                      _expandedReplies.add(comment.id);
                    }
                  });
                },
                onEditReply: (replyId, content) {
                  setState(() {
                    _editingReplyId = replyId;
                    _editController.text = content;
                  });
                },
                onSaveEditReply: (replyId, newContent) => _editReply(comment.id, replyId, newContent),
              );
            },
          ),
        if (!_isLoading && _comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Chưa có bình luận nào.'),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
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

  const _CommentInputField({
    required this.controller,
    required this.isPosting,
    required this.onSubmit,
    required this.rating,
    required this.onRatingChanged,
    required this.selectedImages,
    required this.onPickImages,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Viết bình luận...',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: onPickImages,
                ),
                if (!isPosting)
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: onSubmit,
                  ),
                if (isPosting)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          onSubmitted: (_) => onSubmit(),
          enabled: !isPosting,
        ),
        const SizedBox(height: 8),
        _StarRating(
          rating: rating,
          onRatingChanged: onRatingChanged,
        ),
        const SizedBox(height: 8),
        if (selectedImages.isNotEmpty)
          Wrap(
            spacing: 8,
            children: List.generate(selectedImages.length, (index) {
              return Stack(
                children: [
                  Image.file(
                    File(selectedImages[index].path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => onRemoveImage(index),
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;

  const _StarRating({
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final starWidth = box.size.width / 5;
        double newRating = (localPosition.dx / starWidth).clamp(0, 5);
        newRating = (newRating * 2).roundToDouble() / 2; // Round to nearest 0.5
        onRatingChanged(newRating);
      },
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final starWidth = box.size.width / 5;
        double newRating = (localPosition.dx / starWidth).clamp(0, 5);
        newRating = (newRating * 2).roundToDouble() / 2; // Round to nearest 0.5
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
            size: 30,
          );
        }),
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
  final bool isPostingReply;
  final String? selectedCommentId;
  final String? editingCommentId;
  final String? editingReplyId;
  final TextEditingController editController;
  final TextEditingController replyController;
  final bool isExpanded;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;
  final VoidCallback onReply;
  final VoidCallback onSubmitReply;
  final VoidCallback onEditComment;
  final ValueChanged<String> onSaveEditComment;
  final VoidCallback onCancelEdit;
  final VoidCallback onToggleReplies;
  final Function(String, String) onEditReply;
  final Function(String, String) onSaveEditReply;

  const _CommentItem({
    required this.comment,
    required this.user,
    required this.hasLiked,
    required this.isOwnComment,
    required this.isTogglingLike,
    required this.isPostingReply,
    required this.selectedCommentId,
    required this.editingCommentId,
    required this.editingReplyId,
    required this.editController,
    required this.replyController,
    required this.isExpanded,
    required this.onDelete,
    required this.onToggleLike,
    required this.onReply,
    required this.onSubmitReply,
    required this.onEditComment,
    required this.onSaveEditComment,
    required this.onCancelEdit,
    required this.onToggleReplies,
    required this.onEditReply,
    required this.onSaveEditReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading avatar for user ${user.id}: $exception');
              },
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
                        user.username.isEmpty ? 'không có' : user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (isOwnComment) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                              onPressed: onEditComment,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: onDelete,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (comment.rating > 0)
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = (index + 1).toDouble();
                        return Icon(
                          starValue <= comment.rating
                              ? Icons.star
                              : starValue - 0.5 <= comment.rating
                              ? Icons.star_half
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  const SizedBox(height: 4),
                  if (editingCommentId == comment.id)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: editController,
                            decoration: const InputDecoration(
                              hintText: 'Chỉnh sửa bình luận...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => onSaveEditComment(editController.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: onCancelEdit,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment.content),
                        if (comment.images.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: comment.images.map((imageUrl) {
                              return CachedNetworkImage(
                                imageUrl: '${ApiRoutes.baseUrl.replaceAll('/api', '')}$imageUrl',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: isTogglingLike
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Icon(
                          hasLiked ? Icons.favorite : Icons.favorite_border,
                          color: hasLiked ? Colors.red : null,
                        ),
                        onPressed: onToggleLike,
                      ),
                      Text('${comment.likes.length} lượt thích'),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: onReply,
                        child: const Text('Phản hồi'),
                      ),
                    ],
                  ),
                  if (comment.replies.isNotEmpty)
                    TextButton(
                      onPressed: onToggleReplies,
                      child: Text(
                        isExpanded ? 'Ẩn phản hồi' : 'Xem tất cả phản hồi (${comment.replies.length})',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comment.replies.map((reply) {
                final replyUser = reply.userId;
                final isOwnReply = replyUser.id == Provider.of<AuthViewModel>(context, listen: false).currentUser?.id;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: editingReplyId == reply.id
                            ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: editController,
                                decoration: const InputDecoration(
                                  hintText: 'Chỉnh sửa phản hồi...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => onSaveEditReply(reply.id, editController.text),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: onCancelEdit,
                            ),
                          ],
                        )
                            : Row(
                          children: [
                            Text('${replyUser.username.isEmpty ? 'không có' : replyUser.username}: ${reply.content}'),
                            Text(
                              ' - ${DateFormat('dd/MM/yyyy HH:mm').format(reply.createdAt)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            if (isOwnReply) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                onPressed: () => onEditReply(reply.id, reply.content),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        if (selectedCommentId == comment.id)
          Padding(
            padding: const EdgeInsets.only(left: 48.0),
            child: _CommentInputField(
              controller: replyController,
              isPosting: isPostingReply,
              onSubmit: onSubmitReply,
              rating: 0.0,
              onRatingChanged: (_) {},
              selectedImages: const [],
              onPickImages: () {},
              onRemoveImage: (_) {},
            ),
          ),
        const Divider(),
      ],
    );
  }
}