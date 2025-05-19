import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/views/chat_user.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../viewmodels/vm_auth.dart';
import '../viewmodels/vm_chat.dart';


class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    // Fetch conversations when screen initializes
    chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
    chatViewModel.fetchPendingConversations(authViewModel.currentUser!.token!);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuộc Trò Chuyện'),
        backgroundColor: Colors.blue,
        actions: [
          if (authViewModel.currentUser!.id == authViewModel.currentUser!.id) // For landlords
            IconButton(
              icon: const Icon(Icons.warning, color: Colors.yellow),
              onPressed: () {
                // Navigate to pending conversations (can be a filter or new screen)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Xem các cuộc trò chuyện đang chờ trả lời')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Pending Conversations Indicator for Landlord
          if (authViewModel.currentUser!.id == authViewModel.currentUser!.id && chatViewModel.pendingConversations.isNotEmpty)
            Container(
              color: Colors.yellow[100],
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bạn có ${chatViewModel.pendingConversations.length} cuộc trò chuyện đang chờ trả lời',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Filter or navigate to pending conversations
                      setState(() {
                        chatViewModel.pendingConversations;
                      });
                    },
                    child: const Text('Xem tất cả', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
          // Conversations List
          Expanded(
            child: chatViewModel.isLoading && chatViewModel.conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chatViewModel.errorMessage != null
                ? Center(child: Text(chatViewModel.errorMessage!))
                : ListView.builder(
              itemCount: chatViewModel.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatViewModel.conversations[index];
                final otherParticipant = conversation.participants.firstWhere(
                      (id) => id != authViewModel.currentUser!.id,
                  orElse: () => '',
                );
                final lastMessage = conversation.lastMessage;
                final isPending = conversation.isPending;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  title: Text(otherParticipant.isNotEmpty ? 'Người dùng $otherParticipant' : 'Người dùng ẩn'),
                  subtitle: lastMessage != null
                      ? Text(
                    lastMessage.content.length > 30
                        ? '${lastMessage.content.substring(0, 30)}...'
                        : lastMessage.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      : const Text('Chưa có tin nhắn'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastMessage != null
                            ? DateFormat('HH:mm').format(lastMessage.createdAt)
                            : DateFormat('HH:mm').format(conversation.updatedAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (isPending && authViewModel.currentUser!.id != otherParticipant)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Chờ trả lời',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          rentalId: conversation.rentalId,
                          landlordId: otherParticipant,
                          conversationId: conversation.id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}