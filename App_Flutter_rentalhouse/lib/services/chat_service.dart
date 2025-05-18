import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/api_routes.dart';
import '../models/message.dart';


class ChatService {
  socket_io.Socket? _socket;

  ChatService() {
    _socket = socket_io.io(ApiRoutes.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    _socket?.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });

    _socket?.connect();
  }

  void joinConversation(String conversationId) {
    _socket?.emit('joinConversation', conversationId);
  }

  void sendMessage(String conversationId, String senderId, String content) {
    _socket?.emit('sendMessage', {
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
    });
  }

  void onReceiveMessage(Function(ChatMessage) callback) {
    _socket?.on('receiveMessage', (data) {
      final message = ChatMessage.fromJson(data as Map<String, dynamic>);
      callback(message);
    });
  }

  Future<Conversation> createConversation({
    required String rentalId,
    required String recipientId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse(ApiRoutes.conversations),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rentalId': rentalId,
        'recipientId': recipientId,
      }),
    );

    if (response.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create conversation: ${response.body}');
    }
  }

  Future<List<Conversation>> fetchConversations(String token) async {
    final response = await http.get(
      Uri.parse(ApiRoutes.conversations),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }
  }

  Future<List<Conversation>> fetchPendingConversations(String token) async {
    final response = await http.get(
      Uri.parse(ApiRoutes.pendingConversations),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch pending conversations: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchMessages({
    required String conversationId,
    required String token,
    String? cursor,
    int limit = 10,
  }) async {
    final uri = Uri.parse('${ApiRoutes.messages}/$conversationId')
        .replace(queryParameters: {
      if (cursor != null) 'cursor': cursor,
      'limit': limit.toString(),
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = (data['messages'] as List<dynamic>)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return {'messages': messages, 'nextCursor': nextCursor};
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  void disconnect() {
    _socket?.disconnect();
  }
}