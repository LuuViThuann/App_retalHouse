import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ManageNewsScreen extends StatelessWidget {
  const ManageNewsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Quản lý Tin tức')),
      body: const Center(child: Text('Tạo, sửa, xóa tin tức')));
}
