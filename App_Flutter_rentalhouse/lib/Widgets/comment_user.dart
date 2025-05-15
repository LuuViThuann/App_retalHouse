import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_routes.dart';
import '../viewmodels/vm_auth.dart';

class CommentSection extends StatefulWidget {
  final String rentalId;

  const CommentSection({super.key, required this.rentalId});

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  String? _currentUserAvatar;
  String? _currentUsername;
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _selectedCommentId;

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
      final response = await http.get(
        Uri.parse('${ApiRoutes.rentals}/${widget.rentalId}'),
      );
      print('Fetch comments response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final commentsData = data['comments'] as List<dynamic>? ?? [];
        final comments = commentsData
            .map((json) => Comment.fromJson(json))
            .where((comment) => comment.userId.id.isNotEmpty)
            .toList();
        print('Fetched comments count: ${comments.length}, comments: $comments');
        setState(() => _comments = comments);
      } else {
        throw Exception('Failed to load comments: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching comments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bình luận: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_commentController.text.isEmpty || authViewModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập và nhập nội dung bình luận')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }
      print('Sending comment with token: $token');
      print('Request body: ${jsonEncode({'rentalId': widget.rentalId, 'content': _commentController.text})}');

      final response = await http.post(
        Uri.parse(ApiRoutes.comments),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rentalId': widget.rentalId,
          'content': _commentController.text,
        }),
      );

      print('Post comment response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('_id')) {
          try {
            final newComment = Comment.fromJson(data);
            print('Parsed new comment: $newComment');
            setState(() {
              _comments.insert(0, newComment);
              _commentController.clear();
            });
          } catch (parseError) {
            print('Error parsing comment: $parseError');
            throw Exception('Failed to parse comment response: $parseError');
          }
        } else {
          throw Exception('Invalid response structure: $data');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['message'] ?? 'Đăng bình luận thất bại';
        print('Error details: $errorBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        throw Exception('Failed to post comment: $errorMsg');
      }
    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đăng bình luận: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xóa bình luận')),
      );
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

      print('Delete comment response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _comments.removeWhere((comment) => comment.id == commentId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa bình luận thành công')),
        );
      } else {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Xóa bình luận thất bại';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa bình luận: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postReply(String commentId) async {
    if (_replyController.text.isEmpty) return;
    setState(() => _isLoading = true);
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
      print('Post reply response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201) {
        _replyController.clear();
        setState(() => _selectedCommentId = null);
        await _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng phản hồi thất bại: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error posting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đăng phản hồi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.currentUser?.id;
    final comment = _comments.firstWhere((c) => c.id == commentId,
        orElse: () => Comment(id: '', rentalId: '', userId: User(id: '', username: null, avatarBase64: null), content: '', createdAt: DateTime.now(), replies: [], likes: []));
    final hasLiked = comment.likes.any((like) => like.userId == userId);

    setState(() => _isLoading = true);
    try {
      final token = authViewModel.currentUser?.token;
      if (token == null || token.isEmpty) {
        throw Exception('No valid token found');
      }

      final url = hasLiked
          ? ApiRoutes.unlikeComment(commentId)
          : ApiRoutes.likeComment(commentId);
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
      print('Toggle like response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        await _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thao tác like thất bại: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thao tác like: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUserId = authViewModel.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Bình luận'),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            hintText: 'Viết bình luận...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: _postComment,
            ),
          ),
          onSubmitted: (_) => _postComment(),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: user.processedAvatarBase64 != null && user.processedAvatarBase64!.isNotEmpty
                            ? MemoryImage(base64Decode(user.processedAvatarBase64!))
                            : const AssetImage('assets/img/imageuser.png') as ImageProvider,
                        onBackgroundImageError: (exception, stackTrace) {
                          print('Error decoding avatarBase64: $exception');
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
                                Text(user.username ?? 'không có', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    if (isOwnComment) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deleteComment(comment.id),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(comment.content),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    hasLiked ? Icons.favorite : Icons.favorite_border,
                                    color: hasLiked ? Colors.red : null,
                                  ),
                                  onPressed: () => _toggleLike(comment.id),
                                ),
                                Text('${comment.likes.length} lượt thích'),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _selectedCommentId = comment.id);
                                  },
                                  child: const Text('Phản hồi'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCommentId == comment.id)
                    Padding(
                      padding: const EdgeInsets.only(left: 48.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: 'Viết phản hồi...',
                              border: OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: () => _postReply(comment.id),
                              ),
                            ),
                            onSubmitted: (_) => _postReply(comment.id),
                          ),
                          const SizedBox(height: 8),
                          ...comment.replies.map((reply) {
                            final replyUser = reply.userId;
                            return Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(width: 8),
                                  Text('${replyUser.username ?? 'không có'}: ${reply.content}'),
                                  Text(
                                    ' - ${DateFormat('dd/MM/yyyy HH:mm').format(reply.createdAt)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  const Divider(),
                ],
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