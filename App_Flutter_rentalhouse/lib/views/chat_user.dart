import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_chat.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String rentalId;
  final String landlordId;
  final String conversationId;

  const ChatScreen({
    Key? key,
    required this.rentalId,
    required this.landlordId,
    required this.conversationId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    // Initialize Socket.IO
    chatViewModel.initializeSocket(authViewModel.currentUser!.token!);
    chatViewModel.joinConversation(widget.conversationId);

    // Fetch initial messages
    chatViewModel.fetchMessages(
      conversationId: widget.conversationId,
      token: authViewModel.currentUser!.token!,
    );

    // Load more messages when scrolling to the top
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        chatViewModel.loadMoreMessages(widget.conversationId, authViewModel.currentUser!.token!);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Provider.of<ChatViewModel>(context, listen: false).disconnectSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat với chủ nhà'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Display pending conversations indicator for landlord
          if (authViewModel.currentUser!.id == widget.landlordId)
            Consumer<ChatViewModel>(
              builder: (context, vm, child) {
                return vm.pendingConversations.isNotEmpty
                    ? Container(
                  color: Colors.yellow[100],
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Bạn có ${vm.pendingConversations.length} cuộc trò chuyện đang chờ trả lời.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                )
                    : const SizedBox.shrink();
              },
            ),
          // Message List
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, vm, child) {
                if (vm.isLoading && vm.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (vm.errorMessage != null) {
                  return Center(child: Text(vm.errorMessage!));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: vm.messages.length + (vm.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == vm.messages.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final message = vm.messages[index];
                    final isMe = message.senderId == authViewModel.currentUser!.id;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          // Message Input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      chatViewModel.sendMessage(
                        widget.conversationId,
                        authViewModel.currentUser!.id,
                        _messageController.text.trim(),
                      );
                      _messageController.clear();
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}