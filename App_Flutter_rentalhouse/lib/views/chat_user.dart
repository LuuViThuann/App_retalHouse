import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Message/app_bar_chat.dart';
import 'package:flutter_rentalhouse/Widgets/Message/message_input.dart';
import 'package:flutter_rentalhouse/Widgets/Message/message_list.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../utils/date_chat.dart';


class ChatScreen extends StatefulWidget {
  final String rentalId;
  final String landlordId;
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.rentalId,
    required this.landlordId,
    required this.conversationId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isLoading = true;
  bool _isFetchingOlderMessages = false;
  String? _errorMessage;
  final List<XFile> _selectedImages = [];
  final List<String> _existingImagesToRemove = [];
  String? _editingMessageId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  double? _lastScrollPosition;
  bool _hasMoreMessages = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (!checkAuthentication(authViewModel, context)) {
      setState(() {
        _errorMessage = 'Vui lòng đăng nhập để xem tin nhắn';
        _isLoading = false;
      });
      return;
    }

    try {
      chatViewModel.clearMessages();
      if (chatViewModel.conversations.isEmpty ||
          !chatViewModel.conversations
              .any((c) => c.id == widget.conversationId)) {
        await chatViewModel
            .fetchConversations(authViewModel.currentUser!.token!);
        if (!chatViewModel.conversations
            .any((c) => c.id == widget.conversationId)) {
          final conversation = await chatViewModel.getOrCreateConversation(
            rentalId: widget.rentalId,
            landlordId: widget.landlordId,
            token: authViewModel.currentUser!.token!,
          );
          if (conversation == null) {
            throw Exception('Không thể tạo hoặc tải cuộc trò chuyện');
          }
        }
      }
      await chatViewModel.fetchMessages(
        widget.conversationId,
        authViewModel.currentUser!.token!,
        limit: 50,
      );
      chatViewModel.joinConversation(widget.conversationId);
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom(_scrollController);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải tin nhắn: $e';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final isAtTop =
        currentPosition <= _scrollController.position.minScrollExtent + 10;
    final isScrollingUp =
        _lastScrollPosition != null && currentPosition < _lastScrollPosition!;
    _lastScrollPosition = currentPosition;

    if (isAtTop &&
        isScrollingUp &&
        !_isFetchingOlderMessages &&
        _hasMoreMessages) {
      if (_debounceTimer?.isActive ?? false) return;
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        final chatViewModel =
            Provider.of<ChatViewModel>(context, listen: false);
        final authViewModel =
            Provider.of<AuthViewModel>(context, listen: false);
        if (chatViewModel.messages.isNotEmpty) {
          setState(() {
            _isFetchingOlderMessages = true;
          });
          final previousExtent = _scrollController.position.pixels;
          chatViewModel
              .fetchMessages(
            widget.conversationId,
            authViewModel.currentUser!.token!,
            cursor: chatViewModel.messages.first.id,
            limit: 20,
          )
              .then((hasMore) {
            setState(() {
              _isFetchingOlderMessages = false;
              _hasMoreMessages = hasMore;
            });
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(previousExtent);
            }
          });
        }
      });
    }
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.content;
      _selectedImages.clear();
      _existingImagesToRemove.clear();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
      _selectedImages.clear();
      _existingImagesToRemove.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    if (_isLoading && chatViewModel.messages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: ChatAppBar(
        conversationId: widget.conversationId,
        landlordId: widget.landlordId,
        rentalId: widget.rentalId,
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatMessageList(
              scrollController: _scrollController,
              isFetchingOlderMessages: _isFetchingOlderMessages,
              onLongPress: _startEditing,
            ),
          ),
          ChatInputArea(
            messageController: _messageController,
            selectedImages: _selectedImages,
            existingImagesToRemove: _existingImagesToRemove,
            editingMessageId: _editingMessageId,
            conversationId: widget.conversationId,
            onCancelEditing: _cancelEditing,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}