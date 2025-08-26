import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:flutter_rentalhouse/services/comment_service.dart';
import 'dart:convert';

class RecentCommentsView extends StatefulWidget {
  @override
  _RecentCommentsViewState createState() => _RecentCommentsViewState();
}

class _RecentCommentsViewState extends State<RecentCommentsView> {
  String? _selectedCommentId;
  String? _loadingCommentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false)
          .fetchRecentComments(page: 1);
    });
  }

  void _navigateToRentalDetail(
      BuildContext context, Comment comment, String? token) async {
    setState(() => _loadingCommentId = comment.id);
    try {
      final rental = await RentalService().fetchRentalById(
        rentalId: comment.rentalId,
        token: token,
      );
      if (rental != null) {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RentalDetailScreen(
              rental: rental,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
        setState(() => _selectedCommentId = comment.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy bài đăng hoặc lỗi tải dữ liệu.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải chi tiết bài đăng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loadingCommentId = null);
    }
  }

  void _deleteComment(BuildContext context, Comment comment,
      AuthViewModel authViewModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loadingCommentId = comment.id);
    await CommentService().deleteCommentOrReply(
      authViewModel: authViewModel,
      id: comment.id,
      type: comment.type ?? 'Comment',
      onCommentDeleted: (total, totalPages) async {
        await authViewModel.fetchRecentComments(page: 1);
        setState(() {
          _loadingCommentId = null;
          if (_selectedCommentId == comment.id) _selectedCommentId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa bình luận!'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onError: (err) {
        setState(() => _loadingCommentId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xóa thất bại: $err'),
            backgroundColor: Colors.red,
          ),
        );
      },
      setLoading: (loading) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.blueAccent,
            elevation: 0,
            title: const Text(
              'Bình luận gần đây của bạn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: authViewModel.isLoading &&
                        authViewModel.recentComments.isEmpty
                    ? Center(
                        child: Lottie.asset(
                          AssetsConfig.loadingLottie,
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: authViewModel.recentComments.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Chưa có bình luận hoặc phản hồi nào!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: authViewModel.recentComments.length,
                                itemBuilder: (context, index) {
                                  final Comment comment =
                                      authViewModel.recentComments[index];
                                  final isReply = comment.type == 'Reply';
                                  final isSelected =
                                      comment.id == _selectedCommentId;
                                  final isLoading =
                                      comment.id == _loadingCommentId;
                                  return GestureDetector(
                                    onTap: isLoading
                                        ? null
                                        : () => _navigateToRentalDetail(
                                              context,
                                              comment,
                                              authViewModel.currentUser?.token,
                                            ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white,
                                                Colors.blue[50]!
                                                    .withOpacity(0.5),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.grey
                                                      .withOpacity(0.2),
                                              width: isSelected ? 2 : 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors
                                                              .blueAccent
                                                              .withOpacity(0.3),
                                                          width: 2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.grey
                                                                .withOpacity(
                                                                    0.2),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                    0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: CircleAvatar(
                                                        radius: 20,
                                                        backgroundImage: comment
                                                                    .userId
                                                                    .avatarBytes !=
                                                                null
                                                            ? MemoryImage(comment
                                                                .userId
                                                                .avatarBytes!)
                                                            : const AssetImage(
                                                                    'assets/img/imageuser.png')
                                                                as ImageProvider,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            comment.userId
                                                                .username,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF424242),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            isReply
                                                                ? 'Phản hồi trên ${comment.rentalTitle}'
                                                                : comment
                                                                        .rentalTitle ??
                                                                    'Unknown Rental',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              color: Color(
                                                                  0xFF757575),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                        size: 24,
                                                      ),
                                                      tooltip: 'Xóa bình luận',
                                                      onPressed: isLoading
                                                          ? null
                                                          : () =>
                                                              _deleteComment(
                                                                context,
                                                                comment,
                                                                authViewModel,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  comment.content,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF424242),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                if (!isReply &&
                                                    comment.rating > 0)
                                                  Row(
                                                    children: List.generate(
                                                      5,
                                                      (i) => Icon(
                                                        i < comment.rating
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        color:
                                                            Colors.yellow[700],
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${comment.createdAt.toLocal().toString().substring(0, 16)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF757575),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isLoading)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Center(
                                                child: Lottie.asset(
                                                  AssetsConfig.loadingLottie,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.contain,
                                                ),
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
              if (authViewModel.commentsPage < authViewModel.commentsTotalPages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent,
                          Colors.blueAccent.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: authViewModel.isLoading
                          ? null
                          : () => authViewModel.fetchRecentComments(
                              page: authViewModel.commentsPage + 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: authViewModel.isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              'Tải thêm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
