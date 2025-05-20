import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String? _errorMessage;
  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);

    if (authViewModel.currentUser == null) {
      setState(() {
        _errorMessage = 'Vui lòng đăng nhập để xem tin nhắn';
        _isLoading = false;
      });
      return;
    }

    try {
      print('Loading data for conversationId: ${widget.conversationId}');
      if (chatViewModel.conversations.isEmpty ||
          !chatViewModel.conversations.any((c) => c.id == widget.conversationId)) {
        print('Conversations empty or missing conversation, fetching...');
        await chatViewModel.fetchConversations(authViewModel.currentUser!.token!);
        if (!chatViewModel.conversations.any((c) => c.id == widget.conversationId)) {
          print('Conversation ${widget.conversationId} not found in conversations, fetching by ID');
          final conversation = await chatViewModel.fetchConversationById(
            widget.conversationId,
            authViewModel.currentUser!.token!,
          );
          if (conversation == null) {
            throw Exception('Cuộc trò chuyện không tồn tại hoặc không thể tải');
          }
        }
      }
      await chatViewModel.fetchMessages(widget.conversationId, authViewModel.currentUser!.token!);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải tin nhắn: $e';
        _isLoading = false;
      });
      print('Error in _loadData: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchLandlordInfo(BuildContext context) async {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    try {
      print('Fetching landlord info for conversationId: ${widget.conversationId}');
      final conversation = chatViewModel.conversations.firstWhere(
            (c) => c.id == widget.conversationId,
        orElse: () {
          print('Conversation ${widget.conversationId} not found in conversations');
          return Conversation(
            id: '',
            rentalId: widget.rentalId,
            participants: [widget.landlordId],
            isPending: true,
            createdAt: DateTime.now(),
            landlord: {'id': widget.landlordId, 'username': 'Unknown', 'avatarBase64': ''},
            rental: null,
          );
        },
      );
      if (conversation.id.isEmpty) {
        throw Exception('Không tìm thấy cuộc trò chuyện');
      }
      print('Landlord info: ${conversation.landlord}');
      return conversation.landlord;
    } catch (e) {
      print('Error in _fetchLandlordInfo: $e');
      return {'id': widget.landlordId, 'username': 'Unknown', 'avatarBase64': ''};
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final chatViewModel = Provider.of<ChatViewModel>(context);
    final TextEditingController messageController = TextEditingController();

    if (_isLoading) {
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
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _fetchLandlordInfo(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Unknown');
            }
            final landlord = snapshot.data!;
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(base64Decode(landlord['avatarBase64'] as String))
                      : null,
                  child: landlord['avatarBase64']?.isEmpty == true ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Text(landlord['username'] ?? 'Unknown'),
              ],
            );
          },
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, chatViewModel, child) {
                if (chatViewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (chatViewModel.errorMessage != null) {
                  return Center(child: Text(chatViewModel.errorMessage!));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: chatViewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatViewModel.messages[chatViewModel.messages.length - 1 - index];
                    final isMe = message.senderId == authViewModel.currentUser?.id;
                    return Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: message.sender['avatarBase64']?.isNotEmpty == true
                                ? MemoryImage(base64Decode(message.sender['avatarBase64']))
                                : null,
                            child: message.sender['avatarBase64']?.isEmpty == true
                                ? const Icon(Icons.person, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (message.images.isNotEmpty)
                                  Wrap(
                                    spacing: 5,
                                    children: message.images
                                        .map((img) => ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: '${ApiRoutes.serverBaseUrl}$img',
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        memCacheHeight: 200,
                                        memCacheWidth: 200,
                                        placeholder: (context, url) => const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ))
                                        .toList(),
                                  ),
                                if (message.content.isNotEmpty)
                                  Text(
                                    message.content,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                const SizedBox(height: 5),
                                Text(
                                  DateFormat('HH:mm, dd/MM').format(message.createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: message.sender['avatarBase64']?.isNotEmpty == true
                                ? MemoryImage(base64Decode(message.sender['avatarBase64']))
                                : null,
                            child: message.sender['avatarBase64']?.isEmpty == true
                                ? const Icon(Icons.person, size: 16)
                                : null,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImages,
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (_selectedImages.isNotEmpty)
                        Container(
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Image.file(
                                      File(_selectedImages[index].path),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if ((messageController.text.isNotEmpty || _selectedImages.isNotEmpty) &&
                        authViewModel.currentUser != null) {
                      await chatViewModel.sendMessage(
                        conversationId: widget.conversationId,
                        content: messageController.text,
                        token: authViewModel.currentUser!.token!,
                        imagePaths: _selectedImages.map((x) => x.path).toList(),
                      );
                      messageController.clear();
                      setState(() {
                        _selectedImages.clear();
                      });
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
}