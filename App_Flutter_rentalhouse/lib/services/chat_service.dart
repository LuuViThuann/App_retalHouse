import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_routes.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  io.Socket? _socket;

  // Initialize Socket.IO connection
  void connect(String token, Function(Message) onMessageReceived) {
    if (_socket != null && _socket!.connected) {
      print('Socket already connected');
      return;
    }

    _socket = io.io(ApiRoutes.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'},
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket?.connect();

    _socket?.on('receiveMessage', (data) {
      print('Received message via socket: $data');
      final message = Message.fromJson(data as Map<String, dynamic>);
      onMessageReceived(message);
    });

    _socket?.on('error', (error) {
      print('Socket.IO Error: $error');
    });

    _socket?.onConnect((_) {
      print('Connected to socket server');
    });

    _socket?.onDisconnect((_) {
      print('Disconnected from socket server');
    });

    _socket?.onConnectError((data) {
      print('Socket connection error: $data');
    });
  }

  void joinConversation(String conversationId) {
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected, cannot join conversation: $conversationId');
      return;
    }
    print('Joining conversation: $conversationId');
    _socket?.emit('joinConversation', conversationId);
  }

  void sendMessage(String conversationId, String senderId, String content) {
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected, cannot send message');
      return;
    }
    print('Sending message via socket: conversationId=$conversationId, senderId=$senderId, content=$content');
    _socket?.emit('sendMessage', {
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
    });
  }

  void disconnect() {
    print('Disconnecting socket');
    _socket?.disconnect();
    _socket = null;
  }

  // Get or create a conversation
  Future<Conversation> getOrCreateConversation({
    required String rentalId,
    required String landlordId,
    required String token,
  }) async {
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

    print('Response status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create conversation: ${response.body}');
    }
  }

  // Fetch messages with cursor-based pagination
  Future<Map<String, dynamic>> fetchMessages({
    required String conversationId,
    required String token,
    String? cursor,
    int limit = 10,
  }) async {
    final query = cursor != null ? {'cursor': cursor, 'limit': limit.toString()} : {'limit': limit.toString()};
    final uri = Uri.parse(ApiRoutes.messagesByConversation(conversationId)).replace(queryParameters: query);

    print('Fetching messages for conversationId: $conversationId, uri: $uri');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Fetch messages status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = (data['messages'] as List).map((msg) => Message.fromJson(msg)).toList();
      final nextCursor = data['nextCursor'] as String?;
      return {'messages': messages, 'nextCursor': nextCursor};
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  // Fetch all conversations
  Future<List<Conversation>> fetchConversations(String token) async {
    print('Fetching conversations');
    final response = await http.get(
      Uri.parse(ApiRoutes.conversations),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Fetch conversations status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }
  }

  // Fetch pending conversations
  Future<List<Conversation>> fetchPendingConversations(String token) async {
    print('Fetching pending conversations');
    final response = await http.get(
      Uri.parse(ApiRoutes.pendingConversations),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Fetch pending conversations status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch pending conversations: ${response.body}');
    }
  }
}