import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/chat_service.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String rentalId;
  final String recipientId;

  const ChatScreen({
    super.key,
    required this.rentalId,
    required this.recipientId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  List<ChatMessage> _messages = [];
  String? _nextCursor;
  bool _isLoading = false;
  Conversation? _conversation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _scrollController.addListener(_onScroll);
  }

  void _initializeChat() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (authViewModel.currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      // Create or get conversation
      _conversation = await _chatService.createConversation(
        rentalId: widget.rentalId,
        recipientId: widget.recipientId,
        token: authViewModel.currentUser!.token!,
      );

      // Join the conversation room
      _chatService.joinConversation(_conversation!.id);

      // Fetch initial messages
      await _fetchMessages();

      // Listen for new messages
      _chatService.onReceiveMessage((message) {
        setState(() {
          _messages.insert(0, message);
        });
        _scrollToBottom();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    try {
      final result = await _chatService.fetchMessages(
        conversationId: _conversation!.id,
        token: authViewModel.currentUser!.token!,
        cursor: _nextCursor,
      );
      setState(() {
        _messages.addAll(result['messages'] as List<ChatMessage>);
        _nextCursor = result['nextCursor'] as String?;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching messages: $e')),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _nextCursor != null) {
      _fetchMessages();
    }
  }

  void _sendMessage() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_messageController.text.isEmpty || _conversation == null) return;

    _chatService.sendMessage(
      _conversation!.id,
      authViewModel.currentUser!.id,
      _messageController.text,
    );
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final currentUserId = authViewModel.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversation?.participants.firstWhere((p) => p.id != currentUserId).username ?? 'Chat',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              // Show rental info or conversation details
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == currentUserId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}