import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:flutter_rentalhouse/services/chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatViewModel extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  final List<Message> _messages = [];
  bool _isNotifying = false;
  bool _isLoading = false;
  bool _hasMoreMessages = true;
  String? _errorMessage;
  io.Socket? _socket;
  String? _currentConversationId;
  String? _token;
  String? _searchQuery;
  final Set<String> _highlightedMessageIds = {};
  List<Message> _lastSearchResults = [];
  String? _lastSearchQuery;
  static const int _messageLimit = 50;
  static const int _maxMessagesInMemory = 200;
  final ChatService _chatService = ChatService();

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentConversationId => _currentConversationId;
  String? get searchQuery => _searchQuery;
  Set<String> get highlightedMessageIds => _highlightedMessageIds;
  int get totalUnreadCount =>
      _conversations.fold(0, (sum, conv) => sum + conv.unreadCount);

  ChatViewModel() {
    _initializeSocket();
  }

  void setToken(String token) {
    if (token.isEmpty) {
      print('ChatViewModel: Attempted to set empty token, ignoring');
      _setError('Invalid token provided');
      return;
    }
    print('ChatViewModel: Setting token: ${token.substring(0, 10)}...');
    _token = token;
    _chatService.setToken(token, onTokenExpired: _handleTokenExpired);
    _initializeSocket();
  }

  void _handleTokenExpired(String oldToken) async {
    print('ChatViewModel: Token expired, refreshing...');
    final newToken =
    await _chatService.refreshGoogleToken(forceInteractive: true);
    if (newToken != null) {
      setToken(newToken);
      if (_currentConversationId != null) {
        await fetchConversations(newToken);
      }
    } else {
      _setError('Failed to refresh token. Please sign in again.');
    }
  }

  void _initializeSocket() {
    if (_socket != null) {
      _socket?.disconnect();
      _socket = null;
    }

    if (_token == null || _token!.isEmpty) {
      print('ChatViewModel: Cannot initialize socket: No token');
      return;
    }

    _socket = io.io(ApiRoutes.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'auth': {'token': 'Bearer $_token'},
    });

    _socket?.onConnect((_) {
      print('ChatViewModel: Socket connected');
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket?.onDisconnect((_) {
      print('ChatViewModel: Socket disconnected');
    });

    _socket?.onConnectError((data) {
      _setError('Failed to connect to server: $data');
    });

    _socket?.onError((data) {
      _setError('Socket error: $data');
    });

    _socket?.on('joinedConversation', (_) {
      print('ChatViewModel: Joined conversation');
    });

    _socket?.on('receiveMessage', (data) {
      try {
        final message = Message.fromJson(data);
        if (_currentConversationId == message.conversationId) {
          _addOrUpdateMessage(message);
          _updateSearchIfNeeded();
        }
        _updateConversationUnreadCount(
            message.conversationId, message.senderId);
      } catch (e) {
        print('ChatViewModel: Error processing receiveMessage: $e');
      }
    });

    _socket?.on('deleteMessage', (data) {
      try {
        final messageId = data['messageId']?.toString();
        if (messageId != null) {
          _messages.removeWhere((msg) => msg.id == messageId);
          _highlightedMessageIds.remove(messageId);
          _updateSearchIfNeeded();
          _notify();
        }
      } catch (e) {
        print('ChatViewModel: Error processing deleteMessage: $e');
      }
    });

    _socket?.on('updateMessage', (data) {
      try {
        final updatedMessage = Message.fromJson(data);
        if (_currentConversationId == updatedMessage.conversationId) {
          _addOrUpdateMessage(updatedMessage);
          _updateSearchIfNeeded();
        }
      } catch (e) {
        print('ChatViewModel: Error processing updateMessage: $e');
      }
    });

    _socket?.on('updateConversation', (data) {
      try {
        final updatedConversation = Conversation.fromJson(data);
        final index = _conversations
            .indexWhere((conv) => conv.id == updatedConversation.id);
        if (index != -1) {
          _conversations[index] = updatedConversation;
        } else {
          _conversations.add(updatedConversation);
        }
        _sortConversations();
        _notify();
      } catch (e) {
        print('ChatViewModel: Error processing updateConversation: $e');
      }
    });

    _socket?.on('deleteConversation', (data) {
      try {
        final conversationId = data['conversationId']?.toString();
        if (conversationId != null) {
          _conversations.removeWhere((conv) => conv.id == conversationId);
          if (_currentConversationId == conversationId) {
            _currentConversationId = null;
            _messages.clear();
            _highlightedMessageIds.clear();
            _lastSearchResults.clear();
            _lastSearchQuery = null;
          }
          _notify();
        }
      } catch (e) {
        print('ChatViewModel: Error processing deleteConversation: $e');
      }
    });

    _socket?.on('reconnect', (_) {
      print('ChatViewModel: Socket reconnected');
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket?.on('reconnect_error', (_) {
      _setError('Failed to reconnect to server');
    });

    _socket?.connect();
  }

  void _addOrUpdateMessage(Message message, {bool isTemp = false}) {
    final index = _messages.indexWhere((msg) => msg.id == message.id);
    if (index != -1) {
      _messages[index] = message;
    } else {
      final tempIndex = isTemp
          ? -1
          : _messages.indexWhere((msg) =>
      msg.id.startsWith('temp_') && msg.content == message.content);
      if (tempIndex != -1) {
        _messages[tempIndex] = message;
      } else {
        if (_messages.length >= _maxMessagesInMemory) {
          final removedMessageId = _messages.first.id;
          _messages.removeAt(0);
          _highlightedMessageIds.remove(removedMessageId);
        }
        _messages.add(message);
      }
    }
    _hasMoreMessages = true;
    _notify();
  }

  void _updateConversationUnreadCount(String conversationId, String senderId) {
    final index =
    _conversations.indexWhere((conv) => conv.id == conversationId);
    if (index != -1 && _conversations[index].participants.contains(senderId)) {
      final conv = _conversations[index];
      _conversations[index] = Conversation(
        id: conv.id,
        rentalId: conv.rentalId,
        participants: conv.participants,
        lastMessage: conv.lastMessage,
        isPending: conv.isPending,
        createdAt: conv.createdAt,
        updatedAt: conv.updatedAt,
        landlord: conv.landlord,
        rental: conv.rental,
        unreadCount: _currentConversationId == conversationId
            ? 0
            : (conv.unreadCount + 1),
      );
      _sortConversations();
      _notify();
    }
  }

  void setConversations(List<Conversation> conversations) {
    _conversations
      ..clear()
      ..addAll(conversations);
    _sortConversations();
    _notify();
  }

  void addConversation(Conversation conversation) {
    final index =
    _conversations.indexWhere((conv) => conv.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
    } else {
      _conversations.add(conversation);
    }
    _sortConversations();
    _notify();
  }

  Future<bool> deleteConversation(String conversationId, String token) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for deleteConversation');
      _setError('Invalid token');
      return false;
    }
    try {
      final response = await http.delete(
        Uri.parse(ApiRoutes.conversationById(conversationId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      print(
          'ChatViewModel: Delete conversation status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        _conversations.removeWhere((conv) => conv.id == conversationId);
        if (_currentConversationId == conversationId) {
          _currentConversationId = null;
          _messages.clear();
          _highlightedMessageIds.clear();
          _lastSearchResults.clear();
          _lastSearchQuery = null;
        }
        _notify();
        return true;
      } else {
        _setError('Failed to delete conversation: ${response.body}');
        return false;
      }
    } catch (e) {
      print('ChatViewModel: Error deleting conversation: $e');
      _setError('Error deleting conversation: $e');
      return false;
    }
  }

  void setMessages(List<Message> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    if (_messages.length > _maxMessagesInMemory) {
      final excessCount = _messages.length - _maxMessagesInMemory;
      for (int i = 0; i < excessCount; i++) {
        _highlightedMessageIds.remove(_messages[i].id);
      }
      _messages.removeRange(0, excessCount);
    }
    _hasMoreMessages = messages.length == _messageLimit;
    _updateSearchIfNeeded();
    _notify();
  }

  Future<void> fetchConversations(String token) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for fetchConversations');
      _setError('No token available. Please sign in.');
      return;
    }

    _token = token;
    _setLoading(true);

    try {
      final conversations = await _chatService.fetchConversations(token);
      _conversations
        ..clear()
        ..addAll(conversations);
      _sortConversations();
      _setError(null);
    } catch (e) {
      print('ChatViewModel: Error fetching conversations: $e');
      _setError('Error fetching conversations: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Conversation?> fetchConversationById(
      String conversationId, String token) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for fetchConversationById');
      _setError('Invalid token');
      return null;
    }
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.conversationById(conversationId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      print(
          'ChatViewModel: Fetch conversation byId status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Conversation.fromJson(data);
      }
    } catch (e) {
      print('ChatViewModel: Error fetching conversation by ID: $e');
      _setError('Error fetching conversation: $e');
    }
    return null;
  }

  Future<bool> fetchMessages(String conversationId, String token,
      {String? cursor, int limit = _messageLimit}) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for messages');
      _setError('Invalid token');
      return false;
    }
    if (_isLoading) return _hasMoreMessages;
    _setLoading(true);
    _currentConversationId = conversationId;
    try {
      final result = await _chatService.fetchMessages(
        conversationId: conversationId,
        token: token,
        cursor: cursor,
        limit: limit,
      );
      final newMessages = result['messages'] as List<Message>;
      final nextCursor = result['nextCursor'] as String?;

      final existingIds = _messages.map((m) => m.id).toSet();
      final filteredMessages = newMessages
          .where((newMsg) => !existingIds.contains(newMsg.id))
          .toList();

      if (cursor != null) {
        _messages.addAll(filteredMessages);
      } else {
        _messages
          ..clear()
          ..addAll(filteredMessages);
      }

      if (_messages.length > _maxMessagesInMemory) {
        final excessCount = _messages.length - _maxMessagesInMemory;
        for (int i = 0; i < excessCount; i++) {
          _highlightedMessageIds.remove(_messages[i].id);
        }
        _messages.removeRange(0, excessCount);
      }
      _setError(null);
      _hasMoreMessages = newMessages.length == limit;

      final index =
      _conversations.indexWhere((conv) => conv.id == conversationId);
      if (index != -1) {
        _conversations[index] = Conversation(
          id: _conversations[index].id,
          rentalId: _conversations[index].rentalId,
          participants: _conversations[index].participants,
          lastMessage: _conversations[index].lastMessage,
          isPending: _conversations[index].isPending,
          createdAt: _conversations[index].createdAt,
          updatedAt: _conversations[index].updatedAt,
          landlord: _conversations[index].landlord,
          rental: _conversations[index].rental,
          unreadCount: 0,
        );
        _notify();
      }

      _updateSearchIfNeeded();
      return _hasMoreMessages;
    } catch (e) {
      print('ChatViewModel: Error fetching messages: $e');
      _setError('Error fetching messages: $e');
      return _hasMoreMessages;
    } finally {
      _setLoading(false);
    }
  }

  Future<Conversation?> getOrCreateConversation({
    required String rentalId,
    required String landlordId,
    required String token,
  }) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for getOrCreateConversation');
      _setError('Invalid token');
      return null;
    }
    try {
      final conversation = await _chatService.getOrCreateConversation(
        rentalId: rentalId,
        landlordId: landlordId,
        token: token,
      );
      final index =
      _conversations.indexWhere((conv) => conv.id == conversation.id);
      if (index != -1) {
        _conversations[index] = conversation;
      } else {
        _conversations.add(conversation);
      }
      _sortConversations();
      _notify();
      return conversation;
    } catch (e) {
      print('ChatViewModel: Error creating conversation: $e');
      _setError('Error creating conversation: $e');
      return null;
    }
  }

//
  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    required String token,
    List<String> imagePaths = const [], // ✅ Không giới hạn
    required String senderId,
  }) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for sendMessage');
      _setError('Invalid token');
      return false;
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    try {
      // Add temp message to UI
      if (content.isNotEmpty || imagePaths.isNotEmpty) {
        final tempMessage = Message(
          id: tempId,
          conversationId: conversationId,
          senderId: senderId,
          content: content,
          images: imagePaths,
          createdAt: DateTime.now(),
          updatedAt: null,
          sender: {'id': senderId, 'username': 'You', 'avatarUrl': ''},
        );
        if (_currentConversationId == conversationId) {
          _addOrUpdateMessage(tempMessage, isTemp: true);
        }
      }

      // Build multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiRoutes.messages),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['conversationId'] = conversationId;
      request.fields['content'] = content;

      print('ChatViewModel: Preparing to send ${imagePaths.length} images...');

      for (final path in imagePaths) {
        try {
          final file = await http.MultipartFile.fromPath('images', path);
          request.files.add(file);
          print('ChatViewModel: Added image to request: $path');
        } catch (e) {
          print('ChatViewModel: Error adding image file: $e');
          _messages.removeWhere((msg) => msg.id == tempId);
          _highlightedMessageIds.remove(tempId);
          _setError('Failed to read image file: $e');
          _notify();
          return false;
        }
      }

      // Send request with timeout
      print('ChatViewModel: Sending message request...');
      final streamResponse = await request.send().timeout(
        const Duration(seconds: 60), // ✅ Tăng timeout để upload nhiều ảnh
        onTimeout: () {
          throw TimeoutException('Message send request timed out');
        },
      );

      final responseBody = await streamResponse.stream.bytesToString();

      print('ChatViewModel: Send message response: ${streamResponse.statusCode}');
      print('ChatViewModel: Response body: $responseBody');

      final responseData = jsonDecode(responseBody);

      if (streamResponse.statusCode == 201) {
        final message = Message.fromJson(responseData);
        if (_currentConversationId == conversationId) {
          _addOrUpdateMessage(message);
          _clearHighlightsMessages();
        }

        final index = _conversations.indexWhere((conv) => conv.id == conversationId);
        if (index != -1) {
          _conversations[index] = Conversation(
            id: _conversations[index].id,
            rentalId: _conversations[index].rentalId,
            participants: _conversations[index].participants,
            lastMessage: message,
            isPending: false,
            createdAt: _conversations[index].createdAt,
            updatedAt: DateTime.now(),
            landlord: _conversations[index].landlord,
            rental: _conversations[index].rental,
            unreadCount: 0,
          );
          _sortConversations();
          _notify();
        }
        _updateSearchIfNeeded();
        _setError(null);
        print('ChatViewModel: Message sent successfully with ${imagePaths.length} images');
        return true;
      }
      else if (streamResponse.statusCode == 400) {
        _messages.removeWhere((msg) => msg.id == tempId);
        _highlightedMessageIds.remove(tempId);
        final errorMsg = responseData['message'] ?? 'Invalid request';
        _setError('Lỗi: $errorMsg');
        _notify();
        print('ChatViewModel: Bad request error: $errorMsg');
        return false;
      }
      else if (streamResponse.statusCode == 413) {
        _messages.removeWhere((msg) => msg.id == tempId);
        _highlightedMessageIds.remove(tempId);
        _setError('File quá lớn hoặc vượt quá dung lượng cho phép');
        _notify();
        return false;
      }
      else {
        _messages.removeWhere((msg) => msg.id == tempId);
        _highlightedMessageIds.remove(tempId);
        final errorMsg = responseData['message'] ?? 'Unknown error';
        _setError('Failed to send message: $errorMsg');
        _notify();
        print('ChatViewModel: Server error: $errorMsg');
        return false;
      }
    } on TimeoutException catch (e) {
      _messages.removeWhere((msg) => msg.id == tempId);
      _highlightedMessageIds.remove(tempId);
      _setError('Request timeout - vui lòng thử lại');
      _notify();
      print('ChatViewModel: Timeout error: $e');
      return false;
    } catch (e) {
      _messages.removeWhere((msg) => msg.id == tempId);
      _highlightedMessageIds.remove(tempId);
      print('ChatViewModel: Error sending message: $e');
      _setError('Error sending message: $e');
      _notify();
      return false;
    }
  }

  // ==================== EDIT MESSAGE ====================

  Future<bool> editMessage({
    required String messageId,
    required String content,
    required String token,
    List<String> imagePaths = const [],
    List<String> removeImages = const [],
  }) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for editMessage');
      _setError('Invalid token');
      return false;
    }

    // ✅ Find message and create backup
    int index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) {
      _setError('Message not found');
      return false;
    }

    Message backupMessage = _messages[index];
    print('💾 ========== BACKUP MESSAGE ==========');
    print('💾 ID: ${backupMessage.id}');
    print('💾 Content: ${backupMessage.content}');
    print('💾 Images count: ${backupMessage.images.length}');
    for (int i = 0; i < backupMessage.images.length; i++) {
      print('   [$i] ${backupMessage.images[i]}');
    }

    try {
      print('🔧 ========== SENDING EDIT REQUEST ==========');
      print('🔧 MessageId: $messageId');
      print('📝 Content: $content');
      print('🗑️ RemoveImages: $removeImages');
      print('📸 NewImagePaths: $imagePaths');

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.messages}/$messageId'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;

      // ✅ CRITICAL FIX: Ensure removeImages is properly encoded
      request.fields['removeImages'] = jsonEncode(removeImages);

      print('   - Encoded removeImages: ${request.fields['removeImages']}');

      // ✅ Add new images to request
      if (imagePaths.isNotEmpty) {
        print('📸 Adding ${imagePaths.length} new images to request...');
        for (int i = 0; i < imagePaths.length; i++) {
          final path = imagePaths[i];
          try {
            final file = await http.MultipartFile.fromPath('images', path);
            request.files.add(file);
            print('   ✅ [$i] Added: $path');
          } catch (e) {
            print('❌ Error adding image $i: $e');
            // Restore backup on error
            _messages[index] = backupMessage;
            _notify();
            _setError('Failed to read image file: $e');
            return false;
          }
        }
      }

      print('🚀 Sending PATCH request...');
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Edit message request timed out');
        },
      );

      final responseBody = await response.stream.bytesToString();

      print('📥 ========== SERVER RESPONSE ==========');
      print('📥 Status: ${response.statusCode}');
      print('📥 Body length: ${responseBody.length} chars');
      print('📥 First 500 chars: ${responseBody.substring(0, math.min(500, responseBody.length))}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(responseBody);

          print('✅ Response parsed successfully');
          print('📥 Response _id: ${responseData['_id']}');
          print('📥 Response content: ${responseData['content']}');
          print('📥 Response images: ${responseData['images']}');
          print('📥 Response images type: ${responseData['images'].runtimeType}');
          print('📥 Response images is List: ${responseData['images'] is List}');

          // ✅ CRITICAL: Parse message from server response
          final updatedMessage = Message.fromJson(responseData);

          print('✅ ========== MESSAGE PARSED ==========');
          print('   - ID: ${updatedMessage.id}');
          print('   - Content: ${updatedMessage.content}');
          print('   - Images count: ${updatedMessage.images.length}');
          for (int i = 0; i < updatedMessage.images.length; i++) {
            print('      [$i] ${updatedMessage.images[i]}');
          }

          // ✅ Validate images make sense
          final expectedImageCount =
              backupMessage.images.length - removeImages.length + imagePaths.length;

          if (updatedMessage.images.length != expectedImageCount) {
            print('⚠️ Image count mismatch:');
            print('   Expected: $expectedImageCount');
            print('   Got: ${updatedMessage.images.length}');
            print('   (This might be OK if server validation removed some)');
          }

          // ✅ Update message in local list
          final currentIndex = _messages.indexWhere((msg) => msg.id == messageId);
          if (currentIndex != -1) {
            print('🔄 Updating message at index $currentIndex...');
            _messages[currentIndex] = updatedMessage;
            _notify();

            // ✅ Additional UI refresh after short delay
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_currentConversationId != null) {
                _notify();
                print('🔄 Additional UI refresh triggered');
              }
            });

            print('✅ Local message updated in UI');
          } else {
            print('⚠️ Could not find message in local list for update');
          }

          _updateSearchIfNeeded();
          _setError(null);
          print('✅ ========== EDIT COMPLETED SUCCESSFULLY ==========');
          return true;

        } catch (parseError) {
          print('❌ ========== PARSE ERROR ==========');
          print('❌ Error: $parseError');
          print('❌ Raw response body:');
          print(responseBody);

          // Restore backup
          _messages[index] = backupMessage;
          _notify();
          _setError('Failed to parse server response: $parseError');
          return false;
        }
      } else {
        // ❌ Handle error responses
        print('❌ Error status: ${response.statusCode}');
        print('❌ Response body: $responseBody');

        // Restore backup
        _messages[index] = backupMessage;
        _notify();

        try {
          final responseData = jsonDecode(responseBody);
          final errorMsg = responseData['message'] ?? 'Unknown error';
          _setError('Failed to edit message: $errorMsg');
        } catch (e) {
          _setError('Failed to edit message: ${response.statusCode}');
        }
        return false;
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout: $e');
      _messages[index] = backupMessage;
      _notify();
      _setError('Request timeout - vui lòng thử lại');
      return false;
    } catch (e) {
      print('❌ ========== UNEXPECTED ERROR ==========');
      print('❌ Error: $e');
      print('❌ Stack: ${StackTrace.current}');
      _messages[index] = backupMessage;
      _notify();
      _setError('Error editing message: $e');
      return false;
    }
  }




// ============================================================
  Future<bool> deleteMessage(
      {required String messageId, required String token}) async {
    if (token.isEmpty) {
      print('ChatViewModel: Invalid token for deleteMessage');
      _setError('Invalid token');
      return false;
    }
    Message? backupMessage;
    int index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      backupMessage = _messages[index];
      _messages.removeAt(index);
      _highlightedMessageIds.remove(messageId);
      _notify();
    }
    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.messages}/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print(
          'ChatViewModel: Delete message status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        if (backupMessage != null && _currentConversationId != null) {
          _addOrUpdateMessage(backupMessage);
        }
        _setError('Failed to delete message: ${response.body}');
        return false;
      }
    } catch (e) {
      if (backupMessage != null && _currentConversationId != null) {
        _addOrUpdateMessage(backupMessage);
      }
      print('ChatViewModel: Error deleting message: $e');
      _setError('Error deleting message: $e');
      return false;
    }
  }



  void clearMessages() {
    _messages.clear();
    _currentConversationId = null;
    _errorMessage = null;
    _hasMoreMessages = true;
    _highlightedMessageIds.clear();
    _lastSearchResults.clear();
    _lastSearchQuery = null;
    _notify();
  }

  void exitConversation() {
    if (_socket?.connected == true) {
      _socket?.emit('leaveConversation', _currentConversationId);
    }
    _highlightedMessageIds.clear();
    _lastSearchResults.clear();
    _lastSearchQuery = null;
    _notify();
  }

  void joinConversation(String conversationId) {
    if (_socket?.connected == true) {
      _currentConversationId = conversationId;
      _socket?.emit('joinConversation', conversationId);
    } else {
      _currentConversationId = conversationId;
      _socket?.connect();
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      final aDate = a.lastMessage?.createdAt ?? a.updatedAt ?? a.createdAt;
      final bDate = b.lastMessage?.createdAt ?? b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      _notify();
    }
  }

  void _setError(String? message) {
    if (_errorMessage != message) {
      _errorMessage = message;
      _notify();
    }
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    _updateHighlightedMessages();
    _notify();
  }

  List<Message> searchMessages(String conversationId, String query) {
    if (query.isEmpty) {
      _highlightedMessageIds.clear();
      _lastSearchResults.clear();
      _lastSearchQuery = null;
      _notify();
      return [];
    }

    if (_lastSearchQuery == query) {
      _updateHighlightedMessages(_lastSearchResults.map((m) => m.id).toSet());
      return _lastSearchResults;
    }

    final results = _messages.where((message) {
      return message.conversationId == conversationId &&
          message.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    _lastSearchQuery = query;
    _lastSearchResults = results;
    _updateHighlightedMessages(results.map((m) => m.id).toSet());
    _notify();
    return results;
  }

  void clearSearchResults() {
    _searchQuery = null;
    _lastSearchResults.clear();
    _lastSearchQuery = null;
    _notify();
  }

  void _updateHighlightedMessages([Set<String>? ids]) {
    _highlightedMessageIds.clear();
    if (ids != null) {
      _highlightedMessageIds.addAll(ids);
    } else if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final results =
      searchMessages(_currentConversationId ?? '', _searchQuery!);
      _highlightedMessageIds.addAll(results.map((m) => m.id));
    }
  }

  void _updateSearchIfNeeded() {
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final results =
      searchMessages(_currentConversationId ?? '', _searchQuery!);
      _updateHighlightedMessages(results.map((m) => m.id).toSet());
      _notify();
    }
  }

  void _clearHighlightsMessages() {
    _highlightedMessageIds.clear();
    _lastSearchResults.clear();
    _lastSearchQuery = null;
    _searchQuery = null;
    _notify();
  }

  void _notify() {
    if (!_isNotifying && hasListeners) {
      _isNotifying = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
        _isNotifying = false;
      });
    }
  }

  void updateMessageById(String messageId, Message updatedMessage) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      _messages[index] = updatedMessage;
      _notify();
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}