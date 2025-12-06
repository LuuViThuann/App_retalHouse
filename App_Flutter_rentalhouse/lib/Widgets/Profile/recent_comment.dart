import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';
import 'package:flutter_rentalhouse/services/comment_service.dart';


class RecentCommentsView extends StatefulWidget {
  @override
  _RecentCommentsViewState createState() => _RecentCommentsViewState();
}

class _RecentCommentsViewState extends State<RecentCommentsView> {
  String? _selectedCommentId;
  String? _loadingCommentId;
  Set<String> _selectedForDeletion = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false)
          .fetchRecentComments(page: 1);
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedForDeletion.clear();
      }
    });
  }

  void _toggleCommentSelection(String commentId) {
    setState(() {
      if (_selectedForDeletion.contains(commentId)) {
        _selectedForDeletion.remove(commentId);
      } else {
        _selectedForDeletion.add(commentId);
      }
    });
  }

  void _navigateToRentalDetail(
      BuildContext context, Comment comment, String? token) async {
    if (_isSelectionMode) {
      _toggleCommentSelection(comment.id);
      return;
    }

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
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: 'Không tìm thấy bài đăng hoặc lỗi tải dữ liệu.',
          ),
        );
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: 'Lỗi khi tải chi tiết bài đăng: $e',
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
        AppSnackBar.show(
          context,
          AppSnackBar.success(message: 'Đã xóa bình luận!'),
        );
      },
      onError: (err) {
        setState(() => _loadingCommentId = null);
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Xóa thất bại: $err'),
        );
      },
      setLoading: (loading) {},
    );
  }

  void _deleteMultipleComments(
      BuildContext context, AuthViewModel authViewModel) async {
    if (_selectedForDeletion.isEmpty) return;

    final count = _selectedForDeletion.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa $count bình luận này?',
          style: const TextStyle(fontSize: 16),
        ),
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

    int deletedCount = 0;
    int failedCount = 0;

    for (final commentId in _selectedForDeletion) {
      try {
        await CommentService().deleteCommentOrReply(
          authViewModel: authViewModel,
          id: commentId,
          type: 'Comment',
          onCommentDeleted: (total, totalPages) async {
            deletedCount++;
          },
          onError: (err) {
            failedCount++;
          },
          setLoading: (loading) {},
        );
      } catch (e) {
        failedCount++;
      }
    }

    await authViewModel.fetchRecentComments(page: 1);

    setState(() {
      _selectedForDeletion.clear();
      _isSelectionMode = false;
    });

    if (failedCount == 0) {
      AppSnackBar.show(
        context,
        AppSnackBar.success(
          message: 'Đã xóa $deletedCount bình luận!',
        ),
      );
    } else {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(
          message:
          'Xóa thành công $deletedCount, thất bại $failedCount bình luận',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return WillPopScope(
          onWillPop: () async {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedForDeletion.clear();
              });
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF0F2F5),
            appBar: AppBar(
              backgroundColor: Colors.blue[700],
              elevation: 0,
              title: _isSelectionMode
                  ? Text(
                '${_selectedForDeletion.length} được chọn',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Bình luận gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              leading: _isSelectionMode
                  ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _toggleSelectionMode,
              )
                  : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: _isSelectionMode
                  ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () =>
                      _deleteMultipleComments(context, authViewModel),
                  tooltip: 'Xóa đã chọn',
                ),
              ]
                  : [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Chọn nhiều',
                ),
              ],
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
                      : authViewModel.recentComments.isEmpty
                      ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_bank_outlined,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bình luận hoặc phản hồi nào!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: authViewModel.recentComments.length,
                    itemBuilder: (context, index) {
                      final Comment comment =
                      authViewModel.recentComments[index];
                      final isReply = comment.type == 'Reply';
                      final isSelected =
                      _selectedForDeletion.contains(comment.id);
                      final isLoading =
                          comment.id == _loadingCommentId;

                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode();
                            _toggleCommentSelection(comment.id);
                          }
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleCommentSelection(comment.id);
                          } else {
                            _navigateToRentalDetail(
                              context,
                              comment,
                              authViewModel.currentUser?.token,
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue[50]
                                    : Colors.white,
                                borderRadius:
                                BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey.withOpacity(0.08),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(
                                      isSelected ? 0.15 : 0.06,
                                    ),
                                    blurRadius: isSelected ? 12 : 8,
                                    offset: const Offset(0, 2),
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
                                        if (_isSelectionMode)
                                          Padding(
                                            padding:
                                            const EdgeInsets.only(
                                              right: 12,
                                            ),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration:
                                              BoxDecoration(
                                                shape:
                                                BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.blue
                                                      : Colors.grey[300]!,
                                                  width: 2,
                                                ),
                                                color: isSelected
                                                    ? Colors.blue
                                                    : Colors.white,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .white,
                                              )
                                                  : null,
                                            ),
                                          ),
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.2),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                Colors.blueAccent
                                                    .withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 8,
                                                offset:
                                                const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                            Colors.blue[100],
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
                                                  FontWeight.w600,
                                                  color: Color(
                                                    0xFF1F1F1F,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 4,
                                              ),
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
                                                    0xFF757575,
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
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
                                        height: 1.5,
                                      ),
                                      maxLines: 3,
                                      overflow:
                                      TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        if (!isReply &&
                                            comment.rating > 0)
                                          Row(
                                            children:
                                            List.generate(
                                              5,
                                                  (i) => Icon(
                                                i <
                                                    comment
                                                        .rating
                                                    ? Icons.star
                                                    : Icons
                                                    .star_border,
                                                color: Colors
                                                    .amber[600],
                                                size: 16,
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                        Text(
                                          '${comment.createdAt.toLocal().toString().substring(0, 16)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(
                                              0xFF999999,
                                            ),
                                            fontWeight:
                                            FontWeight.w400,
                                          ),
                                        ),
                                      ],
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
                                        .withOpacity(0.8),
                                    borderRadius:
                                    BorderRadius.circular(12),
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
                if (authViewModel.commentsPage <
                    authViewModel.commentsTotalPages)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[600]!,
                            Colors.blue[400]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
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
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Tải thêm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
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