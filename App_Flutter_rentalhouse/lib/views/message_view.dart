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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // ✅ FIX 1: Unfocus sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();

      // ✅ FIX 2: Load conversations SAU KHI build xong
      if (!_isInitialized) {
        _isInitialized = true;
        _loadConversations();
      }
    });
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
    if (!mounted) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      final token = authViewModel.currentUser!.token;
      if (token != null && token.isNotEmpty) {
        await chatViewModel.fetchConversations(token);
        if (mounted) {
          _filteredConversations.value = chatViewModel.conversations;
        }
      } else {
        if (mounted) {
          SnackbarUtils.showError(context, 'Token không hợp lệ');
        }
      }
    } else {
      if (mounted) {
        SnackbarUtils.showError(
            context, 'Vui lòng đăng nhập để xem cuộc trò chuyện');
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

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
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
           color: Colors.blue[700],
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: const Text(
          'Danh sách cuộc trò chuyện',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chat, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.search, color: AppStyles.whiteColor, size: 26),
            ),
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
      ),
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
        child: Container(
          decoration: BoxDecoration(
           color: Colors.white
          ),
          child: Consumer2<AuthViewModel, ChatViewModel>(
            builder: (context, authViewModel, chatViewModel, child) {
              return ConversationList(
                authViewModel: authViewModel,
                chatViewModel: chatViewModel,
                onRetry: _loadConversations,
                searchQuery: '',
              );
            },
          ),
        ),
      ),
    );
  }
}
