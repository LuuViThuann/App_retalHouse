import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ManagePostsScreen extends StatelessWidget {
  const ManagePostsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Quản lý bài đăng')),
      body: const Center(child: Text('Danh sách bài đăng + Bộ lọc + Gỡ bài')));
}
