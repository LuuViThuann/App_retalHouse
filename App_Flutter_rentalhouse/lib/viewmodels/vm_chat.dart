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

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatViewModel() {
    _initializeSocket();
  }

  void _initializeSocket() {
    _socket = io.io(ApiRoutes.serverBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.onConnect((_) {
      print('Socket connected');
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.on('receiveMessage', (data) {
      print('Received message: $data');
      final message = Message.fromJson(data);
      if (message.conversationId == _messages.firstOrNull?.conversationId) {
        _messages.insert(0, message);
        notifyListeners();
      } else {
        print('Ignoring message for conversation ${message.conversationId}');
      }
    });

    _socket?.on('deleteMessage', (data) {
      print('Received deleteMessage: $data');
      final messageId = data['messageId']?.toString();
      if (messageId != null) {
        _messages.removeWhere((msg) => msg.id == messageId);
        notifyListeners();
      }
    });

    _socket?.on('updateMessage', (data) {
      print('Received updateMessage: $data');
      final updatedMessage = Message.fromJson(data);
      final index = _messages.indexWhere((msg) => msg.id == updatedMessage.id);
      if (index != -1 && updatedMessage.conversationId == _messages.firstOrNull?.conversationId) {
        _messages[index] = updatedMessage;
        notifyListeners();
      } else {
        print('Message ${updatedMessage.id} not found or wrong conversation');
      }
    });

    _socket?.connect();
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
        _conversations = data.map((json) => Conversation.fromJson(json)).toList();
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

  Future<Conversation?> fetchConversationById(String conversationId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/conversations/$conversationId'),
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

  Future<void> fetchMessages(String conversationId, String token, {String? cursor, int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParameters = {
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor,
      };
      final uri = Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$conversationId')
          .replace(queryParameters: queryParameters);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messageData = data['messages'];
        final newMessages = messageData.map((json) => Message.fromJson(json)).toList();
        _messages.addAll(newMessages);
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
        return Conversation.fromJson(data);
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
  }) async {
    try {
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

      if (response.statusCode == 201) {
        return true;
      } else {
        _errorMessage = 'Failed to send message: $responseBody';
        notifyListeners();
        return false;
      }
    } catch (e) {
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
      final response = await http.delete(
        Uri.parse('${ApiRoutes.serverBaseUrl}/api/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _errorMessage = 'Failed to delete message: ${response.body}';
        notifyListeners();
        return false;
      }
    } catch (e) {
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

      if (response.statusCode == 200) {
        return true;
      } else {
        _errorMessage = 'Failed to edit message: $responseBody';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error editing message: $e';
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _messages = [];
    _errorMessage = null;
    notifyListeners();
  }

  void joinConversation(String conversationId) {
    _socket?.emit('joinConversation', conversationId);
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}