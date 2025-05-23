import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/conversation/conversation_list.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/utils/snackbar_conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:provider/provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
    } else {
      SnackbarUtils.showError(
          context, 'Vui lòng đăng nhập để xem cuộc trò chuyện');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.chat, color: AppStyles.whiteColor),
            SizedBox(width: 8),
            Text('Cuộc Trò Chuyện', style: AppStyles.appBarTitle),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppStyles.primaryColor, AppStyles.primaryDarkColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shadowColor: AppStyles.shadowColor,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: AppStyles.searchInputDecoration,
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppStyles.backgroundLight, AppStyles.whiteColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Consumer2<AuthViewModel, ChatViewModel>(
                builder: (context, authViewModel, chatViewModel, child) {
                  return ConversationList(
                    authViewModel: authViewModel,
                    chatViewModel: chatViewModel,
                    onRetry: _loadConversations,
                    searchQuery: _searchController.text,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
