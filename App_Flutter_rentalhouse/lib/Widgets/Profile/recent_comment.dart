import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/comments.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:provider/provider.dart';

class RecentCommentsView extends StatefulWidget {
  @override
  _RecentCommentsViewState createState() => _RecentCommentsViewState();
}

class _RecentCommentsViewState extends State<RecentCommentsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false)
          .fetchRecentComments(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text('Bình luận gần đây',
                style: TextStyle(color: Colors.white)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 4,
            shadowColor: Colors.black26,
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
                            ? Center(child: Text('Chưa có bình luận nào'))
                            : ListView.builder(
                                itemCount: authViewModel.recentComments.length,
                                itemBuilder: (context, index) {
                                  final Comment comment =
                                      authViewModel.recentComments[index];
                                  final isReply = comment.type == 'Reply';
                                  return Card(
                                    elevation: 2,
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundImage: comment.userId
                                                            .avatarBytes !=
                                                        null
                                                    ? MemoryImage(comment
                                                        .userId.avatarBytes!)
                                                    : AssetImage(
                                                        'assets/images/default_avatar.jpg'),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      comment.userId.username,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    Text(
                                                      isReply
                                                          ? 'Reply on ${comment.rentalTitle}'
                                                          : comment
                                                                  .rentalTitle ??
                                                              'Unknown Rental',
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            comment.content,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(height: 8),
                                          if (!isReply && comment.rating > 0)
                                            Row(
                                              children: List.generate(
                                                5,
                                                (i) => Icon(
                                                  i < comment.rating
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.yellow[700],
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          SizedBox(height: 8),
                                          Text(
                                            '${comment.createdAt.toLocal()}',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
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
