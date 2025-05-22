import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatViewModel extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _hasMoreMessages = true;
  String? _errorMessage;
  io.Socket? _socket;
  String? _currentConversationId;
  String? _token;
  static const int _messageLimit = 50; // Default limit for initial messages
  static const int _maxMessagesInMemory = 200; // Cap to prevent memory issues

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get currentConversationId => _currentConversationId;

  ChatViewModel() {
    _initializeSocket();
  }

  void setToken(String token) {
    _token = token;
    _initializeSocket();
  }

  void _initializeSocket() {
    if (_socket != null) {
      _socket?.disconnect();
      _socket = null;
    }

    if (_token == null) return;

    _socket = io.io(ApiRoutes.serverBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'auth': {'token': 'Bearer $_token'},
    });

    _socket?.onConnect((_) {
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket?.onDisconnect((_) {});

    _socket?.onConnectError((data) {
      _setError('Failed to connect to server');
    });

    _socket?.onError((data) {
      _setError('Socket error: $data');
    });

    _socket?.on('joinedConversation', (_) {});

    _socket?.on('receiveMessage', (data) {
      try {
        final message = Message.fromJson(data);
        if (_currentConversationId == message.conversationId) {
          _addOrUpdateMessage(message);
        }
      } catch (_) {}
    });

    _socket?.on('deleteMessage', (data) {
      try {
        final messageId = data['messageId']?.toString();
        if (messageId != null) {
          _messages.removeWhere((msg) => msg.id == messageId);
          _notify();
        }
      } catch (_) {}
    });

    _socket?.on('updateMessage', (data) {
      try {
        final updatedMessage = Message.fromJson(data);
        if (_currentConversationId == updatedMessage.conversationId) {
          _addOrUpdateMessage(updatedMessage);
        }
      } catch (_) {}
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
      } catch (_) {}
    });

    _socket?.on('reconnect', (_) {
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
          _messages.removeAt(_messages.length - 1); // Remove oldest (end)
        }
        _messages.insert(0, message); // Prepend new message
      }
    }
    _hasMoreMessages = true; // New messages imply more may exist
    _notify();
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

  void setMessages(List<Message> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    if (_messages.length > _maxMessagesInMemory) {
      _messages.removeRange(_maxMessagesInMemory, _messages.length);
    }
    _hasMoreMessages = messages.length == _messageLimit;
    _notify();
  }

  Future<void> fetchConversations(String token) async {
    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _conversations
          ..clear()
          ..addAll(data.map((json) => Conversation.fromJson(json)));
        _sortConversations();
        _setError(null);
      } else {
        _setError('Failed to load conversations: ${response.body}');
      }
    } catch (e) {
      _setError('Error fetching conversations: $e');
    }
    _setLoading(false);
  }

  Future<Conversation?> fetchConversationById(
      String conversationId, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiRoutes.serverBaseUrl}/api/conversations/$conversationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Conversation.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> fetchMessages(String conversationId, String token,
      {String? cursor, int limit = _messageLimit}) async {
    if (_isLoading) return _hasMoreMessages; // Prevent concurrent fetches
    _setLoading(true);
    _currentConversationId = conversationId;
    try {
      final queryParameters = {
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor,
        'sort': 'desc', // Request newest messages first
      };
      final uri =
          Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$conversationId')
              .replace(queryParameters: queryParameters);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messageData = data['messages'];
        final newMessages =
            messageData.map((json) => Message.fromJson(json)).toList();
        final existingIds = _messages.map((m) => m.id).toSet();
        final filteredMessages = newMessages
            .where((newMsg) => !existingIds.contains(newMsg.id))
            .toList();

        if (cursor != null) {
          _messages.addAll(filteredMessages); // Append older messages
        } else {
          _messages
            ..clear()
            ..addAll(filteredMessages.reversed); // Newer messages first
        }

        if (_messages.length > _maxMessagesInMemory) {
          _messages.removeRange(_maxMessagesInMemory, _messages.length);
        }
        _setError(null);
        _hasMoreMessages = newMessages.length == limit;
        _notify();
        return _hasMoreMessages;
      } else {
        _setError('Failed to load messages: ${response.body}');
        return _hasMoreMessages;
      }
    } catch (e) {
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
    try {
      final response = await http.post(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rentalId': rentalId,
          'landlordId': landlordId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newConversation = Conversation.fromJson(data);
        final index =
            _conversations.indexWhere((conv) => conv.id == newConversation.id);
        if (index != -1) {
          _conversations[index] = newConversation;
        } else {
          _conversations.add(newConversation);
        }
        _sortConversations();
        _notify();
        return newConversation;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    required String token,
    List<String> imagePaths = const [],
    required String senderId,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    try {
      if (content.isNotEmpty || imagePaths.isNotEmpty) {
        final tempMessage = Message(
          id: tempId,
          conversationId: conversationId,
          senderId: senderId,
          content: content,
          images: imagePaths,
          createdAt: DateTime.now(),
          updatedAt: null,
          sender: {'id': senderId, 'username': 'You', 'avatarBase64': ''},     
        );
        if (_currentConversationId == conversationId) {
          _addOrUpdateMessage(tempMessage, isTemp: true);
        }
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['conversationId'] = conversationId;
      request.fields['content'] = content;

      for (final path in imagePaths) {
        request.files.add(await http.MultipartFile.fromPath('images', path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        final message = Message.fromJson(responseData);
        if (_currentConversationId == conversationId) {
          _addOrUpdateMessage(message);
        }
        return true;
      } else {
        _messages.removeWhere((msg) => msg.id == tempId);
        _setError('Failed to send message: $responseBody');
        _notify();
        return false;
      }
    } catch (e) {
      _messages.removeWhere((msg) => msg.id == tempId);
      _setError('Error sending message: $e');
      _notify();
      return false;
    }
  }

  Future<bool> deleteMessage({
    required String messageId,
    required String token,
  }) async {
    Message? backupMessage;
    int index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      backupMessage = _messages[index];
      _messages.removeAt(index);
      _notify();
    }
    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

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
      _setError('Error deleting message: $e');
      return false;
    }
  }

  Future<bool> editMessage({
    required String messageId,
    required String content,
    required String token,
    List<String> imagePaths = const [],
    List<String> removeImages = const [],
  }) async {
    Message? backupMessage;
    int index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1 && _currentConversationId != null) {
      backupMessage = _messages[index];
      final oldMessage = _messages[index];
      _messages[index] = Message(
        id: messageId,
        conversationId: oldMessage.conversationId,
        senderId: oldMessage.senderId,
        content: content,
        images: [
          ...oldMessage.images.where((img) => !removeImages.contains(img)),
          ...imagePaths
        ],
        createdAt: oldMessage.createdAt,
        updatedAt: DateTime.now(),
        sender: oldMessage.sender,      
      );
      _notify();
    }
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$messageId'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;
      request.fields['removeImages'] = jsonEncode(removeImages);

      for (final path in imagePaths) {
        request.files.add(await http.MultipartFile.fromPath('images', path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        final updatedMessage = Message.fromJson(responseData);
        if (index != -1 && _currentConversationId != null) {
          _addOrUpdateMessage(updatedMessage);
        }
        return true;
      } else {
        if (index != -1 &&
            backupMessage != null &&
            _currentConversationId != null) {
          _addOrUpdateMessage(backupMessage);
        }
        _setError('Failed to edit message: $responseBody');
        return false;
      }
    } catch (e) {
      if (index != -1 &&
          backupMessage != null &&
          _currentConversationId != null) {
        _addOrUpdateMessage(backupMessage);
      }
      _setError('Error editing message: $e');
      return false;
    }
  }

  void clearMessages() {
    _messages.clear();
    _currentConversationId = null;
    _errorMessage = null;
    _hasMoreMessages = true;
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

  void _notify() {
    if (hasListeners) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}
