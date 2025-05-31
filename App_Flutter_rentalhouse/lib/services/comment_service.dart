import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/Reply.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../config/api_routes.dart';
import '../models/comments.dart';
import '../viewmodels/vm_auth.dart';

class CommentService {
  // Load current user info
  Future<void> loadCurrentUserInfo({
    required AuthViewModel authViewModel,
    required Function(String?, String?) onUserInfoLoaded,
  }) async {
    final user = authViewModel.currentUser;
    if (user != null) {
      final username = user.username.isEmpty ? 'không có' : user.username;
      final avatar = user.avatarBase64 != null && user.avatarBase64!.isNotEmpty
          ? 'data:image/jpeg;base64,${user.avatarBase64}'
          : null;
      onUserInfoLoaded(username, avatar);
    }
  }

  // Fetch comments
  Future<void> fetchComments({
    required String rentalId,
    required int page,
    required Function(List<Comment>, int, int, int) onCommentsLoaded,
    required Function(String) onError,
    required Function(bool) setLoading,
    required Function(bool) setLoadingMore,
  }) async {
    if (page == 1) {
      setLoading(true);
    } else {
      setLoadingMore(true);
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.comments}/$rentalId?page=$page&limit=5'),
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
      final totalComments = data['totalComments'] ?? 0;
      final currentPage = data['currentPage'] ?? 1;
      final totalPages = data['totalPages'] ?? 1;
      onCommentsLoaded(comments, totalComments, currentPage, totalPages);
    } catch (e) {
      onError('Lỗi khi tải bình luận: $e');
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }

  // Pick images
  Future<void> pickImages({
    required bool forReply,
    required bool forEdit,
    required List<XFile> selectedImages,
    required List<XFile> selectedReplyImages,
    required List<XFile> editSelectedImages,
    required Function(List<XFile>) updateImages,
  }) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      if (forReply) {
        updateImages(selectedReplyImages..addAll(pickedFiles));
      } else if (forEdit) {
        updateImages(editSelectedImages..addAll(pickedFiles));
      } else {
        updateImages(selectedImages..addAll(pickedFiles));
      }
    }
  }

  // Post a new comment
  Future<void> postComment({
    required AuthViewModel authViewModel,
    required String rentalId,
    required String content,
    required double rating,
    required List<XFile> selectedImages,
    required TextEditingController commentController,
    required Function(Comment, int, int) onCommentPosted,
    required Function(String) onError,
    required Function(bool, String?) setPosting,
  }) async {
    if (content.isEmpty || authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập và nhập nội dung bình luận');
      return;
    }
    if (rating < 1 || rating > 5) {
      setPosting(false, 'Điểm đánh giá phải từ 1 đến 5 sao');
      return;
    }
    setPosting(true, null);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.comments));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['rentalId'] = rentalId;
      request.fields['content'] = content;
      request.fields['rating'] = rating.round().toString();
      for (var image in selectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Đăng bình luận thất bại');
      }
      final data = jsonDecode(responseBody);
      final newComment = Comment.fromJson(data);
      onCommentPosted(newComment, 1, (selectedImages.length / 5).ceil());
      commentController.clear();
    } catch (e) {
      onError('Lỗi khi đăng bình luận: $e');
    } finally {
      setPosting(false, null);
    }
  }

  // Edit a comment
  Future<void> editComment({
    required AuthViewModel authViewModel,
    required String commentId,
    required String newContent,
    required List<XFile> editSelectedImages,
    required List<String> editImagesToRemove,
    required Function(Comment) onCommentEdited,
    required Function(String) onError,
    required Function(bool) setLoading,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để chỉnh sửa bình luận');
      return;
    }
    setLoading(true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest('PUT', Uri.parse('${ApiRoutes.comments}/$commentId'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(editImagesToRemove);
      for (var image in editSelectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Chỉnh sửa bình luận thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      onCommentEdited(updatedComment);
    } catch (e) {
      onError('Lỗi khi chỉnh sửa bình luận: $e');
    } finally {
      setLoading(false);
    }
  }

  // Delete a comment
  Future<void> deleteComment({
    required AuthViewModel authViewModel,
    required String commentId,
    required Function(int, int) onCommentDeleted,
    required Function(String) onError,
    required Function(bool) setLoading,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để xóa bình luận');
      return;
    }
    setLoading(true);
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
      onCommentDeleted(1, 0); // Adjust totalComments and totalPages
    } catch (e) {
      onError('Lỗi khi xóa bình luận: $e');
    } finally {
      setLoading(false);
    }
  }

  // Post a reply
  Future<void> postReply({
    required AuthViewModel authViewModel,
    required String commentId,
    required String content,
    required List<XFile> selectedReplyImages,
    required TextEditingController replyController,
    required String? parentReplyId,
    required Function(Comment) onReplyPosted,
    required Function(String) onError,
    required Function(bool) setPostingReply,
  }) async {
    if (content.isEmpty) {
      onError('Vui lòng nhập nội dung phản hồi');
      return;
    }
    setPostingReply(true);
    try {
      final token = authViewModel.currentUser?.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.commentReplies(commentId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;
      if (parentReplyId != null) {
        request.fields['parentReplyId'] = parentReplyId;
      }
      for (var image in selectedReplyImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Đăng phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      onReplyPosted(updatedComment);
      replyController.clear();
    } catch (e) {
      onError('Lỗi khi đăng phản hồi: $e');
    } finally {
      setPostingReply(false);
    }
  }

  // Edit a reply
  Future<void> editReply({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required String newContent,
    required List<XFile> editSelectedImages,
    required List<String> editImagesToRemove,
    required Function(Comment) onReplyEdited,
    required Function(String) onError,
    required Function(bool) setLoading,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để chỉnh sửa phản hồi');
      return;
    }
    setLoading(true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiRoutes.reply(commentId, replyId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(editImagesToRemove);
      for (var image in editSelectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ?? 'Chỉnh sửa phản hồi thất bại');
      }
      final updatedComment = Comment.fromJson(jsonDecode(responseBody));
      onReplyEdited(updatedComment);
    } catch (e) {
      onError('Lỗi khi chỉnh sửa phản hồi: $e');
    } finally {
      setLoading(false);
    }
  }

  // Delete a reply
  Future<void> deleteReply({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required Function(Comment) onReplyDeleted,
    required Function(String) onError,
    required Function(bool) setLoading,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để xóa phản hồi');
      return;
    }
    setLoading(true);
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
      onReplyDeleted(updatedComment);
    } catch (e) {
      onError('Lỗi khi xóa phản hồi: $e');
    } finally {
      setLoading(false);
    }
  }

  // Toggle like for a comment
  Future<void> toggleLike({
    required AuthViewModel authViewModel,
    required String commentId,
    required List<Comment> comments,
    required Function(Comment) onLikeToggled,
    required Function(String) onError,
    required Function(bool) setTogglingLike,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để thích bình luận');
      return;
    }
    setTogglingLike(true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final comment = comments.firstWhere((c) => c.id == commentId);
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
      onLikeToggled(updatedComment);
    } catch (e) {
      onError('Lỗi khi thao tác like: $e');
    } finally {
      setTogglingLike(false);
    }
  }

  // Toggle like for a reply
  Future<void> toggleReplyLike({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required List<Comment> comments,
    required Function(Comment) onReplyLikeToggled,
    required Function(String) onError,
    required Function(bool) setTogglingReplyLike,
  }) async {
    if (authViewModel.currentUser == null) {
      onError('Vui lòng đăng nhập để thích phản hồi');
      return;
    }
    setTogglingReplyLike(true);
    try {
      final token = authViewModel.currentUser!.token;
      if (token == null || token.isEmpty) throw Exception('No valid token found');
      final comment = comments.firstWhere((c) => c.id == commentId);
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
      onReplyLikeToggled(updatedComment);
    } catch (e) {
      onError('Lỗi khi thao tác like phản hồi: $e');
    } finally {
      setTogglingReplyLike(false);
    }
  }
}