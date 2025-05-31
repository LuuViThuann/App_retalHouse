import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

class NotificationsView extends StatefulWidget {
  @override
  _NotificationsViewState createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).fetchNotifications();
    });
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
            child: authViewModel.isLoading &&
                    authViewModel.notifications.isEmpty
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
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: authViewModel.notifications.length,
                              itemBuilder: (context, index) {
                                final NotificationModel notification =
                                    authViewModel.notifications[index];
                                return FadeInUp(
                                  delay: Duration(milliseconds: index * 100),
                                  child: Padding(
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
                                      onTap: () {
                                        // Hành động khi nhấn vào thông báo
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (authViewModel.notificationsPage <
                              authViewModel.notificationsTotalPages)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: ZoomIn(
                                child: ElevatedButton(
                                  onPressed: authViewModel.isLoading
                                      ? null
                                      : () => authViewModel.fetchNotifications(
                                            page: authViewModel
                                                    .notificationsPage +
                                                1,
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: authViewModel.isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Tải thêm',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Roboto',
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
