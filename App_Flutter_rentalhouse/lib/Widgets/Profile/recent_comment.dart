import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
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
              content: Text('Không tìm thấy bài đăng hoặc lỗi tải dữ liệu.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải chi tiết bài đăng: $e')),
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
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa bình luận này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loadingCommentId = comment.id);
    await CommentService().deleteComment(
      authViewModel: authViewModel,
      commentId: comment.id,
      onCommentDeleted: (total, totalPages) async {
        // Sau khi xóa, reload lại danh sách bình luận gần đây
        await authViewModel.fetchRecentComments(page: 1);
        setState(() {
          _loadingCommentId = null;
          if (_selectedCommentId == comment.id) _selectedCommentId = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đã xóa bình luận.')));
      },
      onError: (err) {
        setState(() => _loadingCommentId = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xóa thất bại: $err')));
      },
      setLoading: (loading) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text('Bình luận gần đây',
                style: TextStyle(color: Colors.black)),
          ),
          body: Column(
            children: [
              if (authViewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    authViewModel.errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: authViewModel.isLoading &&
                        authViewModel.recentComments.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: authViewModel.recentComments.isEmpty
                            ? Center(
                                child:
                                    Text('Chưa có bình luận hoặc phản hồi nào'))
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
                                        Card(
                                          margin:
                                              EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            side: isSelected
                                                ? BorderSide(
                                                    color: Colors.blue,
                                                    width: 2)
                                                : BorderSide.none,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          color: isSelected
                                              ? Colors.blue[50]
                                              : Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
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
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            comment.userId
                                                                .username,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          Text(
                                                            isReply
                                                                ? 'Phản hồi trên ${comment.rentalTitle}'
                                                                : comment
                                                                        .rentalTitle ??
                                                                    'Unknown Rental',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Icon delete
                                                    IconButton(
                                                      icon: Icon(Icons.delete,
                                                          color: Colors.red),
                                                      tooltip: 'Xóa bình luận',
                                                      onPressed: isLoading
                                                          ? null
                                                          : () => _deleteComment(
                                                              context,
                                                              comment,
                                                              authViewModel),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  comment.content,
                                                  style:
                                                      TextStyle(fontSize: 14),
                                                ),
                                                SizedBox(height: 8),
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
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '${comment.createdAt.toLocal().toString().substring(0, 16)}',
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isLoading)
                                          Positioned.fill(
                                            child: Container(
                                              color:
                                                  Colors.white.withOpacity(0.7),
                                              child: Center(
                                                  child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))),
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
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: authViewModel.isLoading
                        ? null
                        : () => authViewModel.fetchRecentComments(
                            page: authViewModel.commentsPage + 1),
                    child: authViewModel.isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Tải thêm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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
