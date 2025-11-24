import 'package:flutter/material.dart';

class NotificationUser extends StatelessWidget {
  const NotificationUser({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Thông báo gần đây')),
      body: const Center(child: Text('Danh sách thông báo !  ')));
}
