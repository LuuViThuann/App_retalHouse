import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/conversation/conversation_bottom.dart';
import 'package:flutter_rentalhouse/Widgets/conversation/conversation_list.dart';
import 'package:flutter_rentalhouse/constants/app_style.dart';
import 'package:flutter_rentalhouse/utils/snackbar_conversation.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  final ValueNotifier<List<Conversation>> _filteredConversations =
      ValueNotifier<List<Conversation>>([]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _filteredConversations.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
      _filteredConversations.value = chatViewModel.conversations;
    } else {
      SnackbarUtils.showError(
          context, 'Vui lòng đăng nhập để xem cuộc trò chuyện');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
      _filteredConversations.value = value.isEmpty
          ? chatViewModel.conversations
          : chatViewModel.conversations.where((conversation) {
              final username =
                  conversation.landlord['username']?.toLowerCase() ?? '';
              return username.contains(value.toLowerCase());
            }).toList();
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
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppStyles.whiteColor),
            onPressed: () {
              showSearchBottomSheet(
                context: context,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                filteredConversations: _filteredConversations,
                onSearchChanged: _onSearchChanged,
                vsync: this,
              );
            },
          ),
        ],
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
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
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
                searchQuery: '', // No longer needed in the main UI
              );
            },
          ),
        ),
      ),
    );
  }
}
