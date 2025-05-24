import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/DentailMessage/action.dart';
import 'package:flutter_rentalhouse/Widgets/DentailMessage/section_title.dart';
import 'package:flutter_rentalhouse/Widgets/DentailMessage/share_image.dart';
import 'package:flutter_rentalhouse/Widgets/Message/chat_image_full_screen.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:provider/provider.dart';

class ConversationInfoPage extends StatefulWidget {
  final String conversationId;

  const ConversationInfoPage({super.key, required this.conversationId});

  @override
  _ConversationInfoPageState createState() => _ConversationInfoPageState();
}

class _ConversationInfoPageState extends State<ConversationInfoPage> {
  bool _isDeleting = false;

  void _deleteConversation() async {
    setState(() => _isDeleting = true);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await chatViewModel.deleteConversation(
        widget.conversationId, authViewModel.currentUser!.token!);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cuộc trò chuyện đã được xóa'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(10),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(chatViewModel.errorMessage ?? 'Lỗi khi xóa cuộc trò chuyện'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final messages = chatViewModel.messages
        .where((msg) => msg.conversationId == widget.conversationId)
        .toList();
    final imageUrls = messages.expand((message) => message.images).toList();

    const Color messagingThemeColor = Color(0xFF007AFF);
    const Color onMessagingThemeColor = Colors.white;

    final ThemeData currentTheme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Thông tin hội thoại',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: onMessagingThemeColor,
          ),
        ),
        backgroundColor: messagingThemeColor,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: onMessagingThemeColor),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'Ảnh đã chia sẻ',
              icon: Icons.image_outlined,
              color: messagingThemeColor,
            ),
            const SizedBox(height: 12),
            SharedImages(
              imageUrls: imageUrls,
              themeColor: messagingThemeColor,
            ),
            const SizedBox(height: 24),
            SectionTitle(
              title: 'Quản lý',
              icon: Icons.settings_outlined,
              color: messagingThemeColor,
            ),
            const SizedBox(height: 12),
            ActionsCard(
              appTheme: currentTheme,
              isDeleting: _isDeleting,
              onDelete: _deleteConversation,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
