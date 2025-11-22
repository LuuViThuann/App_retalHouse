import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      body: const Center(child: Text('Danh sách người dùng + Khóa tài khoản')));
}
