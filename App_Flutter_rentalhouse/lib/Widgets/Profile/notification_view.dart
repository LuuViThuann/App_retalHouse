import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_rentalhouse/services/rental_service.dart';
import 'package:flutter_rentalhouse/views/rental_detail_view.dart';

class NotificationsView extends StatefulWidget {
  @override
  _NotificationsViewState createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool _isInitialLoading = true;
  String? _loadingNotificationId;
  List<NotificationModel> _notifications = [];
  NotificationModel? _removedNotification;
  int? _removedIndex;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).fetchNotifications();
      setState(() => _isInitialLoading = false);
    });
  }

  void _handleNotificationTap(
      NotificationModel notification, BuildContext context) async {
    if (_loadingNotificationId == notification.id) return;

    setState(() {
      _loadingNotificationId = notification.id;
    });

    try {
      if (notification.type == 'Comment' && notification.rentalId.isNotEmpty) {
        final rental = await RentalService().fetchRentalById(
          rentalId: notification.rentalId,
          token: Provider.of<AuthViewModel>(context, listen: false)
              .currentUser
              ?.token,
        );

        if (rental != null) {
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RentalDetailScreen(rental: rental),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Không tìm thấy bài đăng hoặc lỗi tải dữ liệu.')),
          );
        }
      } else if (notification.postId != null) {
        await Navigator.pushNamed(
          context,
          '/post-detail',
          arguments: notification.postId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải chi tiết bài đăng: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingNotificationId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: const Text(
              'Thông báo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'Roboto',
              ),
            ),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isInitialLoading && authViewModel.notifications.isEmpty
                ? Center(
                    child: Lottie.asset(
                      AssetsConfig.loadingLottie,
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  )
                : authViewModel.notifications.isEmpty
                    ? Center(
                        child: FadeInUp(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Chưa có thông báo nào',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: _listKey,
                        itemCount: authViewModel.notifications.length,
                        itemBuilder: (context, index) {
                          final notification =
                              authViewModel.notifications[index];
                          final isLoading =
                              _loadingNotificationId == notification.id;

                          return FadeInUp(
                            delay: Duration(milliseconds: index * 100),
                            child: Dismissible(
                              key: ValueKey(notification.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                try {
                                  await authViewModel
                                      .removeNotification(notification.id);
                                  return true;
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Lỗi khi xóa thông báo: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return false;
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (direction) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã xóa thông báo'),
                                      duration: Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'Hoàn tác',
                                        onPressed: () async {
                                          try {
                                            await authViewModel
                                                .restoreNotification(
                                                    notification);
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Lỗi khi khôi phục thông báo: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () => _handleNotificationTap(
                                        notification, context),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.notifications_active,
                                          color: Colors.blue.shade600,
                                          size: 28,
                                        ),
                                        title: Text(
                                          notification.message,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            '${notification.content}\nNgày: ${notification.createdAt.toLocal().toString().substring(0, 16)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isLoading)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.white.withOpacity(0.7),
                                          child: Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
