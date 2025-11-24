import 'package:flutter/material.dart';

class Newsave extends StatelessWidget {
  const Newsave({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Tin tức đã lưu')),
      body: const Center(child: Text('Danh sách tin tức đã lưu ! ')));
}
