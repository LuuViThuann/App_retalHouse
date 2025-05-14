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
        _currentUserAvatar = user.avatarBase64 != null
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final comments = (data['comments'] as List)
            .map((json) => Comment.fromJson(json))
            .toList();
        setState(() => _comments = comments);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bình luận: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.comments),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Provider.of<AuthViewModel>(context, listen: false).currentUser?.token}',
        },
        body: jsonEncode({
          'rentalId': widget.rentalId,
          'content': _commentController.text,
        }),
      );
      if (response.statusCode == 201) {
        _commentController.clear();
        _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng bình luận thất bại')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postReply(String commentId) async {
    if (_replyController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.commentReplies(commentId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Provider.of<AuthViewModel>(context, listen: false).currentUser?.token}',
        },
        body: jsonEncode({'content': _replyController.text}),
      );
      if (response.statusCode == 201) {
        _replyController.clear();
        setState(() => _selectedCommentId = null);
        _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng phản hồi thất bại')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.currentUser?.id;
    final comment = _comments.firstWhere((c) => c.id == commentId);
    final hasLiked = comment.likes.any((like) => like.userId == userId);

    setState(() => _isLoading = true);
    try {
      final url = hasLiked
          ? ApiRoutes.unlikeComment(commentId)
          : ApiRoutes.likeComment(commentId);
      final response = hasLiked
          ? await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authViewModel.currentUser?.token}',
        },
      )
          : await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authViewModel.currentUser?.token}',
        },
      );
      if (response.statusCode == 200) {
        _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thao tác like thất bại')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Bình luận'),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        if (!_isLoading)
          Column(
            children: [
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Viết bình luận...',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _postComment,
                  ),
                ),
                onSubmitted: (_) => _postComment(),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final user = comment.userId;
                  final hasLiked = comment.likes.any((like) => like.userId == Provider.of<AuthViewModel>(context, listen: false).currentUser?.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: user.avatarBase64 != null
                                ? MemoryImage(base64Decode(user.avatarBase64!.split(',')[1]))
                                : const AssetImage('assets/img/imageuser.png') as ImageProvider,
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
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
            ],
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