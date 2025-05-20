import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_routes.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatViewModel extends ChangeNotifier {
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _messageLimit = 20;
  bool _hasMoreMessages = true;
  String? _currentConversationId; // Track current conversation

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  IO.Socket? _socket;

  ChatViewModel() {
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io(ApiRoutes.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket?.connect();

    _socket?.onConnect((_) {
      print('Connected to socket server');
    });

    _socket?.on('receiveMessage', (data) {
      print('Received message: $data');
      final message = Message.fromJson(data);
      if (message.conversationId == _currentConversationId) { // Filter by conversationId
        _messages.add(message);
        notifyListeners();
      } else {
        print('Ignoring message for conversation ${message.conversationId}, current: $_currentConversationId');
      }
    });

    _socket?.onDisconnect((_) {
      print('Disconnected from socket server');
    });

    _socket?.onConnectError((data) {
      _errorMessage = 'Socket connection error: $data';
      print('Socket connection error: $data');
      notifyListeners();
    });
  }

  Future<Conversation?> getOrCreateConversation({
    required String rentalId,
    required String landlordId,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('Creating conversation with rentalId: $rentalId, landlordId: $landlordId');
      final response = await http.post(
        Uri.parse(ApiRoutes.conversations),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rentalId': rentalId,
          'landlordId': landlordId,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final conversation = Conversation.fromJson(data);
        _conversations = [conversation, ..._conversations.where((c) => c.id != conversation.id)];
        print('Joining conversation room: ${conversation.id}');
        _socket?.emit('joinConversation', conversation.id);
        notifyListeners();
        return conversation;
      } else {
        _errorMessage = 'Không thể tạo cuộc trò chuyện: ${response.body}';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi tạo cuộc trò chuyện: $e';
      print('Error in getOrCreateConversation: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchConversations(String token, {int limit = 20}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('Fetching conversations with token: $token');
      final response = await http.get(
        Uri.parse('${ApiRoutes.conversations}?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Không thể kết nối đến server');
      });

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);
        List<dynamic> data;

        if (decodedData is List) {
          data = decodedData;
        } else if (decodedData is Map && decodedData['data'] is List) {
          data = decodedData['data'];
        } else {
          throw FormatException('Unexpected response format: $decodedData');
        }

        print('Parsed conversations: $data');

        _conversations = data.map((json) => Conversation.fromJson(json as Map<String, dynamic>)).toList();
        for (var conv in _conversations) {
          _socket?.emit('joinConversation', conv.id);
        }
      } else {
        _errorMessage = 'Không thể tải danh sách cuộc trò chuyện: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi tải danh sách cuộc trò chuyện: ${e.toString()}';
      print('Error in fetchConversations: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Conversation?> fetchConversationById(String conversationId, String token) async {
    try {
      print('Fetching conversation with ID: $conversationId');
      final response = await http.get(
        Uri.parse(ApiRoutes.conversationById(conversationId)),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Fetch conversation status: ${response.statusCode}');
      print('Fetch conversation body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final conversation = Conversation.fromJson(data);
        _conversations = [
          conversation,
          ..._conversations.where((c) => c.id != conversation.id),
        ];
        _socket?.emit('joinConversation', conversation.id);
        notifyListeners();
        return conversation;
      }
      return null;
    } catch (e) {
      print('Error fetching conversation $conversationId: $e');
      return null;
    }
  }

  Future<void> fetchMessages(String conversationId, String token, {String? cursor}) async {
    if (!_hasMoreMessages) return;

    _isLoading = true;
    _currentConversationId = conversationId; // Set current conversation
    _messages = []; // Clear messages for new conversation
    notifyListeners();

    try {
      final query = cursor != null ? {'cursor': cursor, 'limit': _messageLimit.toString()} : {'limit': _messageLimit.toString()};
      final uri = Uri.parse(ApiRoutes.messagesByConversation(conversationId)).replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Fetch messages status: ${response.statusCode}');
      print('Fetch messages body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messageData = data['messages'] ?? [];
        final newMessages = messageData.map((json) => Message.fromJson(json)).toList();
        _messages = [...newMessages, ..._messages];
        _hasMoreMessages = newMessages.length == _messageLimit;
      } else {
        _errorMessage = 'Không thể tải tin nhắn: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi tải tin nhắn: $e';
      print('Error in fetchMessages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    required String token,
    List<String> imagePaths = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.messages));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['conversationId'] = conversationId;
      request.fields['content'] = content;

      for (var imagePath in imagePaths) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          imagePath,
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Send message status: ${response.statusCode}');
      print('Send message body: $responseBody');

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final message = Message.fromJson(data);
        if (message.conversationId == _currentConversationId) {
          _messages.add(message);
        }
        notifyListeners();
      } else {
        _errorMessage = 'Không thể gửi tin nhắn: $responseBody';
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi gửi tin nhắn: $e';
      print('Error in sendMessage: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _messages = [];
    _hasMoreMessages = true;
    _currentConversationId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}