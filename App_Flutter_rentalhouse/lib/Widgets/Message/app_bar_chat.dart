import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Message/info_conversation.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_chat.dart';
import 'package:provider/provider.dart';

class ChatAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String conversationId;
  final String landlordId;
  final String rentalId;

  const ChatAppBar({
    super.key,
    required this.conversationId,
    required this.landlordId,
    required this.rentalId,
  });

  @override
  _ChatAppBarState createState() => _ChatAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ChatAppBarState extends State<ChatAppBar> with TickerProviderStateMixin {
  AnimationController? _animationController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchLandlordInfo(BuildContext context) async {
    if (!mounted) {
      return {
        'id': widget.landlordId,
        'username': 'Chủ nhà',
        'avatarBase64': ''
      };
    }
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
          unreadCount: 0,
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

  void _showSearchSheet(BuildContext context) {
    if (!mounted || _animationController == null) return;
    final chatViewModel = Provider.of<ChatViewModel>(context, listen: false);
    final searchController = TextEditingController();
    final focusNode = FocusNode();
    int resultCount = 0;

    _animationController!.forward();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white.withOpacity(0.95),
      transitionAnimationController: _animationController,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm tin nhắn...',
                            prefixIcon:
                                Icon(Icons.search, color: Colors.blue[700]),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close, color: Colors.blue[700]),
                              onPressed: () {
                                searchController.clear();
                                chatViewModel.setSearchQuery('');
                                Navigator.pop(context);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.blue[700]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.blue[50],
                          ),
                          onChanged: (value) {
                            if (_debounce?.isActive ?? false)
                              _debounce?.cancel();
                            _debounce =
                                Timer(const Duration(milliseconds: 300), () {
                              chatViewModel.setSearchQuery(value);
                              final results = chatViewModel.searchMessages(
                                  widget.conversationId, value);
                              setState(() {
                                resultCount = results.length;
                              });
                            });
                          },
                          onTap: () => focusNode.requestFocus(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (resultCount > 0)
                        Text(
                          '$resultCount kết quả',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      searchController.dispose();
      focusNode.dispose();
      if (mounted && _animationController != null) {
        _animationController!.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
         color: Colors.blue[700],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      title: FutureBuilder<Map<String, dynamic>>(
        future: _fetchLandlordInfo(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Roboto',
              ),
            );
          }
          final landlord =
              snapshot.data ?? {'username': 'Chủ nhà', 'avatarBase64': ''};
          return Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: landlord['avatarBase64']?.isNotEmpty == true
                      ? MemoryImage(
                          base64Decode(landlord['avatarBase64'] as String))
                      : null,
                  child: landlord['avatarBase64']?.isEmpty == true
                      ? Icon(Icons.person, size: 22, color: Colors.grey[600])
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                landlord['username'] ?? 'Chủ nhà',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          );
        },
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ConversationInfoPage(conversationId: widget.conversationId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;

                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _showSearchSheet(context),
        ),
      ],
    );
  }
}
