import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_routes.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  io.Socket? _socket;
  String? _token;
  Function(String)? _onTokenExpired;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Set token and callback for token refresh
  void setToken(String token, {Function(String)? onTokenExpired}) {
    print(
        'Setting token: ${token.substring(0, 10)}...'); // Log partial token for debugging
    _token = token;
    _onTokenExpired = onTokenExpired;
    _initializeSocket();
  }

  // Refresh Google OAuth token
  Future<String?> refreshGoogleToken() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        print('No Google account found for silent sign-in');
        return null;
      }
      final auth = await account.authentication;
      if (auth.idToken == null) {
        print('No ID token returned from Google Sign-In');
        return null;
      }
      print('Refreshed Google token: ${auth.idToken!.substring(0, 10)}...');
      _token = auth.idToken;
      setToken(auth.idToken!);
      return auth.idToken;
    } catch (e) {
      print('Error refreshing Google token: $e');
      return null;
    }
  }

  // Initialize Socket.IO connection
  void _initializeSocket() {
    if (_token == null) {
      print('Cannot initialize socket: No token provided');
      return;
    }
    if (_socket != null && _socket!.connected) {
      print('Socket already connected');
      return;
    }

    _socket = io.io(ApiRoutes.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $_token'},
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket?.connect();

    _socket?.on('receiveMessage', (data) {
      print('Received message via socket: $data');
      final message = Message.fromJson(data as Map<String, dynamic>);
      onMessageReceived?.call(message);
    });

    _socket?.on('error', (error) {
      print('Socket.IO Error: $error');
      if (error.toString().contains('Invalid or expired token') &&
          _onTokenExpired != null) {
        _onTokenExpired!(_token!);
      }
    });

    _socket?.onConnect((_) {
      print('Connected to socket server');
    });

    _socket?.onDisconnect((_) {
      print('Disconnected from socket server');
    });

    _socket?.onConnectError((data) {
      print('Socket connection error: $data');
      if (data.toString().contains('401') && _onTokenExpired != null) {
        _onTokenExpired!(_token!);
      }
    });
  }

  Function(Message)? onMessageReceived;

  void joinConversation(String conversationId) {
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected, attempting to initialize: $conversationId');
      _initializeSocket();
      return;
    }
    print('Joining conversation: $conversationId');
    _socket?.emit('joinConversation', conversationId);
  }

  void sendMessage(String conversationId, String senderId, String content) {
    if (_token == null) {
      print('Cannot send message: No token provided');
      return;
    }
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected, attempting to initialize');
      _initializeSocket();
      return;
    }
    print(
        'Sending message via socket: conversationId=$conversationId, senderId=$senderId, content=$content');
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
    if (token.isEmpty) {
      throw Exception('No token provided');
    }
    print(
        'Creating conversation with rentalId: $rentalId, landlordId: $landlordId, token: ${token.substring(0, 10)}...');
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
    } else if (response.statusCode == 401) {
      if (_onTokenExpired != null) {
        _onTokenExpired!(token);
      }
      throw Exception('Authentication failed: Invalid or expired token');
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
    if (token.isEmpty) {
      throw Exception('No token provided');
    }
    final query = cursor != null
        ? {'cursor': cursor, 'limit': limit.toString()}
        : {'limit': limit.toString()};
    final uri = Uri.parse(ApiRoutes.messagesByConversation(conversationId))
        .replace(queryParameters: query);

    print(
        'Fetching messages for conversationId: $conversationId, uri: $uri, token: ${token.substring(0, 10)}...');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    print(
        'Fetch messages status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = (data['messages'] as List)
          .map((msg) => Message.fromJson(msg))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return {'messages': messages, 'nextCursor': nextCursor};
    } else if (response.statusCode == 401) {
      if (_onTokenExpired != null) {
        _onTokenExpired!(token);
      }
      throw Exception('Authentication failed: Invalid or expired token');
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  // Fetch all conversations with retry logic
  Future<List<Conversation>> fetchConversations(String token) async {
    if (token.isEmpty) {
      throw Exception('No token provided');
    }
    print('Fetching conversations with token: ${token.substring(0, 10)}...');
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(ApiRoutes.conversations),
          headers: {'Authorization': 'Bearer $token'},
        );

        print(
            'Fetch conversations status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => Conversation.fromJson(json)).toList();
        } else if (response.statusCode == 401) {
          if (_onTokenExpired != null) {
            _onTokenExpired!(token);
          }
          throw Exception('Authentication failed: Invalid or expired token');
        } else {
          throw Exception('Failed to fetch conversations: ${response.body}');
        }
      } catch (e) {
        print('Attempt $attempt failed: $e');
        if (attempt == 3) {
          throw Exception(
              'Failed to fetch conversations after $attempt attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Failed to fetch conversations: Max retries reached');
  }

  // Fetch pending conversations
  Future<List<Conversation>> fetchPendingConversations(String token) async {
    if (token.isEmpty) {
      throw Exception('No token provided');
    }
    print(
        'Fetching pending conversations with token: ${token.substring(0, 10)}...');
    final response = await http.get(
      Uri.parse(ApiRoutes.pendingConversations),
      headers: {'Authorization': 'Bearer $token'},
    );

    print(
        'Fetch pending conversations status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      if (_onTokenExpired != null) {
        _onTokenExpired!(token);
      }
      throw Exception('Authentication failed: Invalid or expired token');
    } else {
      throw Exception(
          'Failed to fetch pending conversations: ${response.body}');
    }
  }
}
