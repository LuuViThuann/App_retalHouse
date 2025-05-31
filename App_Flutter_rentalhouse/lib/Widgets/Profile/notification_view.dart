import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/notification.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:provider/provider.dart';

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
            title: Text('Thông báo', style: TextStyle(color: Colors.white)),
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
          body: authViewModel.isLoading && authViewModel.notifications.isEmpty
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: authViewModel.notifications.isEmpty
                            ? Center(child: Text('Chưa có thông báo nào'))
                            : ListView.builder(
                                itemCount: authViewModel.notifications.length,
                                itemBuilder: (context, index) {
                                  final NotificationModel notification =
                                      authViewModel.notifications[index];
                                  return Card(
                                    elevation: 2,
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    child: ListTile(
                                      leading: Icon(Icons.notifications_active,
                                          color: Colors.blue),
                                      title: Text(
                                        notification.message,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${notification.content}\nNgày: ${notification.createdAt.toLocal().toString().substring(0, 16)}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (authViewModel.notificationsPage <
                          authViewModel.notificationsTotalPages)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: ElevatedButton(
                            onPressed: authViewModel.isLoading
                                ? null
                                : () => authViewModel.fetchNotifications(
                                    page: authViewModel.notificationsPage + 1),
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
                ),
        );
      },
    );
  }
}
