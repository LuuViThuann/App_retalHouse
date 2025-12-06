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
          backgroundColor: Colors.green.shade700,
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
          backgroundColor: Colors.red.shade700,
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

    const Color messagingThemeColor = Colors.lightBlue;
    const Color onMessagingThemeColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
           color: Colors.blue[700],
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        title: const Text(
          'Thông tin cuộc trò chuyện',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                      appTheme: Theme.of(context),
                      isDeleting: _isDeleting,
                      onDelete: _deleteConversation,
                    ),
                    const SizedBox(height: 20), // Ensure bottom padding
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
