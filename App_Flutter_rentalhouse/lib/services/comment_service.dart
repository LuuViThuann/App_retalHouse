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
        throw Exception(
            'Failed to load comments: ${response.statusCode} - ${response.body}');
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      var request =
          http.MultipartRequest('POST', Uri.parse(ApiRoutes.comments));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['rentalId'] = rentalId;
      request.fields['content'] = content;
      request.fields['rating'] = rating.round().toString();
      for (var image in selectedImages) {
        request.files
            .add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(
            jsonDecode(responseBody)['message'] ?? 'Đăng bình luận thất bại');
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      var request = http.MultipartRequest(
          'PUT', Uri.parse('${ApiRoutes.comments}/$commentId'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(editImagesToRemove);
      for (var image in editSelectedImages) {
        request.files
            .add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ??
            'Chỉnh sửa bình luận thất bại');
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      final response = await http.delete(
        Uri.parse('${ApiRoutes.comments}/$commentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(
            jsonDecode(response.body)['message'] ?? 'Xóa bình luận thất bại');
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
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
        request.files
            .add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 201) {
        throw Exception(
            jsonDecode(responseBody)['message'] ?? 'Đăng phản hồi thất bại');
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

  // Edit a reply - Optimized version
  Future<void> editReply({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required String newContent,
    required List<XFile> editSelectedImages,
    required List<String> editImagesToRemove,
    required Function(Reply)
        onReplyEdited, // Changed to return only the updated reply
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiRoutes.reply(commentId, replyId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = newContent;
      request.fields['imagesToRemove'] = jsonEncode(editImagesToRemove);
      for (var image in editSelectedImages) {
        request.files
            .add(await http.MultipartFile.fromPath('images', image.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(responseBody)['message'] ??
            'Chỉnh sửa phản hồi thất bại');
      }
      final responseData = jsonDecode(responseBody);
      // Return only the updated reply instead of full comment
      final updatedReply = Reply.fromJson(responseData['reply']);
      onReplyEdited(updatedReply);
    } catch (e) {
      onError('Lỗi khi chỉnh sửa phản hồi: $e');
    } finally {
      setLoading(false);
    }
  }

  // Delete a reply - Optimized version
  Future<void> deleteReply({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required Function(String) onReplyDeleted, // Changed to return only replyId
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      final response = await http.delete(
        Uri.parse('${ApiRoutes.reply(commentId, replyId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(
            jsonDecode(response.body)['message'] ?? 'Xóa phản hồi thất bại');
      }
      // Return only the replyId instead of full comment
      onReplyDeleted(replyId);
    } catch (e) {
      onError('Lỗi khi xóa phản hồi: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteCommentOrReply({
    required AuthViewModel authViewModel,
    required String id,
    required String type, // 'Comment' hoặc 'Reply'
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      late final http.Response response;
      if (type == 'Reply') {
        // Gọi API xóa reply
        final url = ApiRoutes.deleteReply(id);
        response = await http.delete(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        // Gọi API xóa comment
        final url = '${ApiRoutes.comments}/$id';
        response = await http.delete(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
      if (response.statusCode == 200) {
        onCommentDeleted(1, 0);
      } else {
        final error = json.decode(response.body)['message'] ?? 'Unknown error';
        onError(error);
      }
    } catch (e) {
      onError('Lỗi khi xóa bình luận: $e');
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
      final comment = comments.firstWhere((c) => c.id == commentId);
      final hasLiked = comment.likes
          .any((like) => like.userId == authViewModel.currentUser!.id);
      final method = hasLiked ? http.delete : http.post;
      final url = hasLiked
          ? ApiRoutes.unlikeComment(commentId)
          : ApiRoutes.likeComment(commentId);
      final response = await method(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(
            jsonDecode(response.body)['message'] ?? 'Thao tác like thất bại');
      }
      final updatedComment =
          Comment.fromJson(jsonDecode(response.body)['comment']);
      onLikeToggled(updatedComment);
    } catch (e) {
      onError('Lỗi khi thao tác like: $e');
    } finally {
      setTogglingLike(false);
    }
  }

  // Toggle like for a reply - Optimized version
  Future<void> toggleReplyLike({
    required AuthViewModel authViewModel,
    required String commentId,
    required String replyId,
    required List<Comment> comments,
    required Function(Reply)
        onReplyLikeToggled, // Changed to return only the updated reply
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
      if (token == null || token.isEmpty)
        throw Exception('No valid token found');
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
      final hasLiked = reply.likes
          .any((like) => like.userId == authViewModel.currentUser!.id);
      final method = hasLiked ? http.delete : http.post;
      final url = hasLiked
          ? ApiRoutes.unlikeReply(commentId, replyId)
          : ApiRoutes.likeReply(commentId, replyId);
      final response = await method(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ??
            'Thao tác like phản hồi thất bại');
      }
      final responseData = jsonDecode(response.body);
      // Return only the updated reply instead of full comment
      final updatedReply = Reply.fromJson(responseData['reply']);
      onReplyLikeToggled(updatedReply);
    } catch (e) {
      onError('Lỗi khi thao tác like phản hồi: $e');
    } finally {
      setTogglingReplyLike(false);
    }
  }

  // Helper method to update a specific reply in a comment
  static Comment updateReplyInComment(
      Comment comment, String replyId, Reply updatedReply) {
    List<Reply> updatedReplies =
        _updateReplyInList(comment.replies, replyId, updatedReply);
    return Comment(
      id: comment.id,
      rentalId: comment.rentalId,
      userId: comment.userId,
      content: comment.content,
      rating: comment.rating,
      images: comment.images,
      isHidden: comment.isHidden,
      createdAt: comment.createdAt,
      replies: updatedReplies,
      likes: comment.likes,
      rentalTitle: comment.rentalTitle,
      type: comment.type,
    );
  }

  // Helper method to remove a specific reply from a comment
  static Comment removeReplyFromComment(Comment comment, String replyId) {
    List<Reply> updatedReplies = _removeReplyFromList(comment.replies, replyId);
    return Comment(
      id: comment.id,
      rentalId: comment.rentalId,
      userId: comment.userId,
      content: comment.content,
      rating: comment.rating,
      images: comment.images,
      isHidden: comment.isHidden,
      createdAt: comment.createdAt,
      replies: updatedReplies,
      likes: comment.likes,
      rentalTitle: comment.rentalTitle,
      type: comment.type,
    );
  }

  // Recursive helper to update reply in nested structure
  static List<Reply> _updateReplyInList(
      List<Reply> replies, String replyId, Reply updatedReply) {
    return replies.map((reply) {
      if (reply.id == replyId) {
        return updatedReply;
      } else {
        List<Reply> updatedNestedReplies =
            _updateReplyInList(reply.replies, replyId, updatedReply);
        return Reply(
          id: reply.id,
          commentId: reply.commentId,
          parentReplyId: reply.parentReplyId,
          userId: reply.userId,
          content: reply.content,
          images: reply.images,
          icon: reply.icon,
          createdAt: reply.createdAt,
          likes: reply.likes,
          replies: updatedNestedReplies,
        );
      }
    }).toList();
  }

  // Recursive helper to remove reply from nested structure
  static List<Reply> _removeReplyFromList(List<Reply> replies, String replyId) {
    return replies.where((reply) {
      if (reply.id == replyId) {
        return false; // Remove this reply
      } else {
        // Recursively check nested replies
        List<Reply> updatedNestedReplies =
            _removeReplyFromList(reply.replies, replyId);
        if (updatedNestedReplies.length != reply.replies.length) {
          // A nested reply was removed, update this reply
          reply = Reply(
            id: reply.id,
            commentId: reply.commentId,
            parentReplyId: reply.parentReplyId,
            userId: reply.userId,
            content: reply.content,
            images: reply.images,
            icon: reply.icon,
            createdAt: reply.createdAt,
            likes: reply.likes,
            replies: updatedNestedReplies,
          );
        }
        return true; // Keep this reply
      }
    }).toList();
  }

  // Helper method to find a reply by ID in nested structure
  static Reply? findReplyById(List<Reply> replies, String replyId) {
    for (var reply in replies) {
      if (reply.id == replyId) {
        return reply;
      }
      final nestedReply = findReplyById(reply.replies, replyId);
      if (nestedReply != null) {
        return nestedReply;
      }
    }
    return null;
  }
}

// Comment State Manager for efficient state updates
class CommentStateManager {
  static List<Comment> updateCommentInList(
      List<Comment> comments, String commentId, Comment updatedComment) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return updatedComment;
      }
      return comment;
    }).toList();
  }

  static List<Comment> removeCommentFromList(
      List<Comment> comments, String commentId) {
    return comments.where((comment) => comment.id != commentId).toList();
  }

  static List<Comment> addCommentToList(
      List<Comment> comments, Comment newComment) {
    return [newComment, ...comments];
  }

  static List<Comment> updateReplyInCommentList(List<Comment> comments,
      String commentId, String replyId, Reply updatedReply) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return CommentService.updateReplyInComment(
            comment, replyId, updatedReply);
      }
      return comment;
    }).toList();
  }

  static List<Comment> removeReplyFromCommentList(
      List<Comment> comments, String commentId, String replyId) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return CommentService.removeReplyFromComment(comment, replyId);
      }
      return comment;
    }).toList();
  }

  static Comment? findCommentById(List<Comment> comments, String commentId) {
    try {
      return comments.firstWhere((comment) => comment.id == commentId);
    } catch (e) {
      return null;
    }
  }

  static Reply? findReplyInComments(List<Comment> comments, String replyId) {
    for (var comment in comments) {
      final reply = CommentService.findReplyById(comment.replies, replyId);
      if (reply != null) {
        return reply;
      }
    }
    return null;
  }
}
