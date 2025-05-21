import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/conversation.dart';
import 'package:flutter_rentalhouse/models/message.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatViewModel extends ChangeNotifier {
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  io.Socket? _socket;
  String? _currentConversationId;
  String? _token;

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

    _socket = io.io(ApiRoutes.serverBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'auth': {'token': _token != null ? 'Bearer $_token' : null},
    });

    _socket?.onConnect((_) {
      print('Socket connected');
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.onConnectError((data) {
      print('Socket connect error: $data');
      _errorMessage = 'Failed to connect to server';
      notifyListeners();
    });

    _socket?.onError((data) {
      print('Socket error: $data');
      _errorMessage = 'Socket error: $data';
      notifyListeners();
    });

    _socket?.on('joinedConversation', (data) {
      print('Joined conversation: ${jsonEncode(data)}');
    });

    _socket?.on('receiveMessage', (data) {
      print('Received message: ${jsonEncode(data)}');
      try {
        final message = Message.fromJson(data);
        if (_currentConversationId != null &&
            message.conversationId == _currentConversationId) {
          final tempIndex = _messages.indexWhere((msg) =>
              msg.id.startsWith('temp_') && msg.content == message.content);
          if (tempIndex != -1) {
            _messages[tempIndex] = message;
            print('Replaced temp message with ${message.id}');
          } else if (!_messages.any((msg) => msg.id == message.id)) {
            _messages.add(message);
            print(
                'Added message ${message.id} to conversation $_currentConversationId');
          } else {
            print('Duplicate message ${message.id} ignored');
            return;
          }
          notifyListeners();
        } else {
          print(
              'Ignoring message for conversation ${message.conversationId}, current: $_currentConversationId');
        }
      } catch (e) {
        print('Error parsing receiveMessage: $e');
      }
    });

    _socket?.on('deleteMessage', (data) {
      print('Received deleteMessage: ${jsonEncode(data)}');
      try {
        final messageId = data['messageId']?.toString();
        if (messageId != null) {
          _messages.removeWhere((msg) => msg.id == messageId);
          print('Deleted message $messageId');
          notifyListeners();
        } else {
          print('Invalid messageId in deleteMessage');
        }
      } catch (e) {
        print('Error handling deleteMessage: $e');
      }
    });

    _socket?.on('updateMessage', (data) {
      print('Received updateMessage: ${jsonEncode(data)}');
      try {
        final updatedMessage = Message.fromJson(data);
        final index =
            _messages.indexWhere((msg) => msg.id == updatedMessage.id);
        if (index != -1 &&
            _currentConversationId != null &&
            updatedMessage.conversationId == _currentConversationId) {
          _messages[index] = updatedMessage;
          print('Updated message ${updatedMessage.id} at index $index');
          notifyListeners();
        } else {
          print(
              'Message ${updatedMessage.id} not found or wrong conversation ${updatedMessage.conversationId}, current: $_currentConversationId');
        }
      } catch (e) {
        print('Error handling updateMessage: $e');
      }
    });

    _socket?.on('updateConversation', (data) {
      print('Received updateConversation: ${jsonEncode(data)}');
      try {
        final updatedConversation = Conversation.fromJson(data);
        final index = _conversations
            .indexWhere((conv) => conv.id == updatedConversation.id);
        if (index != -1) {
          _conversations[index] = updatedConversation;
        } else {
          _conversations.add(updatedConversation);
        }
        _conversations.sort((a, b) {
          final aDate = a.lastMessage?.createdAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.lastMessage?.createdAt ?? b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
        print(
            'Updated conversation list with conversation ${updatedConversation.id}');
        notifyListeners();
      } catch (e) {
        print('Error handling updateConversation: $e');
      }
    });

    _socket?.on('reconnect', (attempt) {
      print('Socket reconnected after $attempt attempts');
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket?.on('reconnect_error', (data) {
      print('Socket reconnect error: $data');
      _errorMessage = 'Failed to reconnect to server';
      notifyListeners();
    });

    if (_token != null) {
      _socket?.connect();
    }
  }

  Future<void> fetchConversations(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _conversations =
            data.map((json) => Conversation.fromJson(json)).toList();
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to load conversations: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching conversations: $e';
    }

    _isLoading = false;
    notifyListeners();
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
      } else {
        print('Failed to fetch conversation: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching conversation: $e');
      return null;
    }
  }

  Future<void> fetchMessages(String conversationId, String token,
      {String? cursor, int limit = 10}) async {
    _isLoading = true;
    _currentConversationId = conversationId;
    notifyListeners();

    try {
      final queryParameters = {
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor,
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
        _messages = [
          ..._messages,
          ...newMessages
              .where((newMsg) => !_messages.any((msg) => msg.id == newMsg.id)),
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to load messages: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching messages: $e';
    }

    _isLoading = false;
    notifyListeners();
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
        _conversations.sort((a, b) {
          final aDate = a.lastMessage?.createdAt ?? a.updatedAt ?? a.createdAt;
          final bDate = b.lastMessage?.createdAt ?? b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
        notifyListeners();
        return newConversation;
      } else {
        print('Failed to create/get conversation: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating/getting conversation: $e');
      return null;
    }
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
      // Optimistic update: Add temporary message
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
          _messages.add(tempMessage);
          notifyListeners();
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
        final tempIndex = _messages.indexWhere((msg) => msg.id == tempId);
        if (tempIndex != -1 && _currentConversationId == conversationId) {
          _messages[tempIndex] = message;
          print('Replaced temp message $tempId with ${message.id}');
        } else if (!_messages.any((msg) => msg.id == message.id) &&
            _currentConversationId == conversationId) {
          _messages.add(message);
          print(
              'Added sent message ${message.id} to conversation $conversationId');
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
        return true;
      } else {
        _messages.removeWhere((msg) => msg.id == tempId);
        _errorMessage = 'Failed to send message: $responseBody';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _messages.removeWhere((msg) => msg.id == tempId);
      _errorMessage = 'Error sending message: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMessage({
    required String messageId,
    required String token,
  }) async {
    try {
      // Optimistic update
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      Message? backupMessage;
      if (index != -1) {
        backupMessage = _messages[index];
        _messages.removeAt(index);
        notifyListeners();
      }

      final response = await http.delete(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        if (backupMessage != null && _currentConversationId != null) {
          _messages.add(backupMessage);
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
        _errorMessage = 'Failed to delete message: ${response.body}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index == -1) {
        _messages.add(_messages[index]);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
      }
      _errorMessage = 'Error deleting message: $e';
      notifyListeners();
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
    try {
      // Optimistic update
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      Message? backupMessage;
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
        notifyListeners();
      }

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
          _messages[index] = updatedMessage;
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
        return true;
      } else {
        if (index != -1 &&
            backupMessage != null &&
            _currentConversationId != null) {
          _messages[index] = backupMessage;
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
        _errorMessage = 'Failed to edit message: $responseBody';
        notifyListeners();
        return false;
      }
    } catch (e) {
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1 && _currentConversationId != null) {
        _messages[index] = _messages[index];
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
      }
      _errorMessage = 'Error editing message: $e';
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _messages = [];
    _currentConversationId = null;
    _errorMessage = null;
    notifyListeners();
  }

  void joinConversation(String conversationId) {
    if (_socket?.connected == true) {
      _currentConversationId = conversationId;
      print('Joining conversation: $conversationId');
      _socket?.emit('joinConversation', conversationId);
    } else {
      print(
          'Socket not connected, queuing join for conversation: $conversationId');
      _currentConversationId = conversationId;
      _socket?.connect();
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}
