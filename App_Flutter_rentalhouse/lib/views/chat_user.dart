import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/models/message.dart';
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

    if (authViewModel.currentUser == null) {
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
        _scrollToBottom();
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<Map<String, dynamic>> _fetchLandlordInfo(BuildContext context) async {
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    try {
      final conversation = chatViewModel.conversations.firstWhere(
            (c) => c.id == widget.conversationId,
        orElse: () => Conversation(
          id: '',
          rentalId: widget.rentalId,
          participants: [widget.landlordId],
          isPending: true,
          createdAt: DateTime.now(),
          landlord: {
            'id': widget.landlordId,
            'username': 'Chủ nhà',
            'avatarBase64': ''
          },
          rental: null,
        ),
      );
      if (conversation.id.isEmpty) {
        throw Exception('Không tìm thấy cuộc trò chuyện');
      }
      return conversation.landlord;
    } catch (_) {
      return {
        'id': widget.landlordId,
        'username': 'Chủ nhà',
        'avatarBase64': ''
      };
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

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) return 'Hôm nay';
    if (difference == 1) return 'Hôm qua';
    if (difference <= 7) return '$difference ngày trước';
    return DateFormat('dd/MM/yyyy').format(messageDate);
  }

  bool _checkAuthentication(AuthViewModel authViewModel) {
    if (authViewModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi tin nhắn'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateSendInput(String content) {
    if (content.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung hoặc chọn hình ảnh'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateEditInput(String content) {
    if (content.isEmpty &&
        _selectedImages.isEmpty &&
        _existingImagesToRemove.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Vui lòng cung cấp nội dung hoặc hình ảnh để chỉnh sửa'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _sendMessage(
      ChatViewModel chatViewModel, AuthViewModel authViewModel, String content) async {
    setState(() {
      _isLoading = true;
    });
    final success = await chatViewModel.sendMessage(
      conversationId: widget.conversationId,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: _selectedImages.map((x) => x.path).toList(),
      senderId: authViewModel.currentUser!.id,
    );
    setState(() {
      _isLoading = false;
      if (success) {
        _messageController.clear();
        _selectedImages.clear();
      }
    });
    _scrollToBottom();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatViewModel.errorMessage ?? 'Lỗi khi gửi tin nhắn'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _editMessage(
      ChatViewModel chatViewModel, AuthViewModel authViewModel, String content) async {
    setState(() {
      _isLoading = true;
    });
    final success = await chatViewModel.editMessage(
      messageId: _editingMessageId!,
      content: content,
      token: authViewModel.currentUser!.token!,
      imagePaths: _selectedImages.map((x) => x.path).toList(),
      removeImages: _existingImagesToRemove,
    );
    setState(() {
      _isLoading = false;
      if (success) {
        _cancelEditing();
      }
    });
    _scrollToBottom();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn đã được chỉnh sửa'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text(chatViewModel.errorMessage ?? 'Lỗi khi chỉnh sửa tin nhắn'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _fetchLandlordInfo(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            final landlord =
                snapshot.data ?? {'username': 'Chủ nhà', 'avatarBase64': ''};
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(
                      base64Decode(landlord['avatarBase64'] as String))
                      : null,
                  child: landlord['avatarBase64']?.isEmpty == true
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(landlord['username'] ?? 'Chủ nhà'),
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
                if (chatViewModel.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Hãy bắt đầu nhắn tin bây giờ!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final items = <dynamic>[];
                String? lastHeader;

                for (var message in chatViewModel.messages) {
                  final header = _getDateHeader(message.createdAt);
                  if (header != lastHeader) {
                    items.add(header);
                    lastHeader = header;
                  }
                  items.add(message);
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[800]),
                                ),
                              ),
                            ),
                          );
                        }
                        final message = item as Message;
                        final isMe =
                            message.senderId == authViewModel.currentUser?.id;
                        return GestureDetector(
                          key: ValueKey(message.id),
                          onLongPress: isMe
                              ? () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('Chỉnh sửa'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _startEditing(message);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete),
                                      title: const Text('Xóa'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final success =
                                        await chatViewModel
                                            .deleteMessage(
                                          messageId: message.id,
                                          token: authViewModel
                                              .currentUser!.token!,
                                        );
                                        if (success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Tin nhắn đã được xóa'),
                                              backgroundColor:
                                              Colors.green,
                                            ),
                                          );
                                          _scrollToBottom();
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(chatViewModel
                                                  .errorMessage ??
                                                  'Lỗi khi xóa tin nhắn'),
                                              backgroundColor:
                                              Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                              : null,
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: message
                                      .sender['avatarBase64']
                                      ?.isNotEmpty ==
                                      true
                                      ? MemoryImage(base64Decode(
                                      message.sender['avatarBase64']))
                                      : null,
                                  child:
                                  message.sender['avatarBase64']?.isEmpty ==
                                      true
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.blue[100]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (message.images.isNotEmpty)
                                        Wrap(
                                          spacing: 5,
                                          children: message.images
                                              .map((img) => ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                              '${ApiRoutes.serverBaseUrl}$img',
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              memCacheHeight: 200,
                                              memCacheWidth: 200,
                                              placeholder: (context,
                                                  url) =>
                                              const CircularProgressIndicator(),
                                              errorWidget: (context,
                                                  url, error) =>
                                              const Icon(
                                                  Icons.error),
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
                                        message.updatedAt != null
                                            ? 'Đã chỉnh sửa - ${DateFormat('HH:mm, dd/MM').format(message.updatedAt!)}'
                                            : DateFormat('HH:mm, dd/MM')
                                            .format(message.createdAt),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: message
                                      .sender['avatarBase64']
                                      ?.isNotEmpty ==
                                      true
                                      ? MemoryImage(base64Decode(
                                      message.sender['avatarBase64']))
                                      : null,
                                  child:
                                  message.sender['avatarBase64']?.isEmpty ==
                                      true
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    if (_isFetchingOlderMessages)
                      const Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (_editingMessageId != null &&
                    chatViewModel.messages
                        .any((msg) => msg.id == _editingMessageId))
                  Container(
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: chatViewModel.messages
                          .firstWhere((msg) => msg.id == _editingMessageId)
                          .images
                          .length,
                      itemBuilder: (context, index) {
                        final imageUrl = chatViewModel.messages
                            .firstWhere((msg) => msg.id == _editingMessageId)
                            .images[index];
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl:
                                  '${ApiRoutes.serverBaseUrl}$imageUrl',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                                ),
                              ),
                            ),
                            if (!_existingImagesToRemove.contains(imageUrl))
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _existingImagesToRemove.add(imageUrl);
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _pickImages,
                      color: Colors.blue,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _editingMessageId == null
                              ? 'Nhập tin nhắn...'
                              : 'Chỉnh sửa tin nhắn...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    if (_editingMessageId != null)
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: _cancelEditing,
                        color: Colors.red,
                      ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final authViewModel =
                        Provider.of<AuthViewModel>(context, listen: false);
                        final chatViewModel =
                        Provider.of<ChatViewModel>(context, listen: false);
                        final content = _messageController.text.trim();

                        if (!_checkAuthentication(authViewModel)) return;

                        if (_editingMessageId != null) {
                          if (!_validateEditInput(content)) return;
                          await _editMessage(
                              chatViewModel, authViewModel, content);
                        } else {
                          if (!_validateSendInput(content)) return;
                          await _sendMessage(
                              chatViewModel, authViewModel, content);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
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