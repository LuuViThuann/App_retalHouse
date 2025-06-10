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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.profile'
    ],
    clientId:
        '616377322079-eb0grhlmn2lbnifatbduclltcur9t3g4.apps.googleusercontent.com',
  );

  void setToken(String token, {Function(String)? onTokenExpired}) {
    if (token.isEmpty) {
      print('ChatService: Attempted to set empty token, ignoring');
      throw Exception('Cannot set empty token');
    }
    print('ChatService: Setting token: ${token.substring(0, 10)}...');
    _token = token;
    _onTokenExpired = onTokenExpired;
    _initializeSocket();
  }

  Future<String> _ensureValidToken({bool forceInteractive = false}) async {
    if (_token != null && _token!.isNotEmpty) {
      print(
          'ChatService: Using existing token: ${_token!.substring(0, 10)}...');
      return _token!;
    }
    print('ChatService: No valid token, attempting to refresh');
    final newToken =
        await refreshGoogleToken(forceInteractive: forceInteractive);
    if (newToken == null || newToken.isEmpty) {
      throw Exception('Failed to obtain a valid token');
    }
    return newToken;
  }

  Future<String?> refreshGoogleToken({bool forceInteractive = false}) async {
    try {
      GoogleSignInAccount? account;
      if (!forceInteractive) {
        account = await _googleSignIn.signInSilently();
      }
      if (account == null) {
        print(
            'ChatService: Silent sign-in failed, attempting interactive sign-in');
        account = await _googleSignIn.signIn();
      }
      if (account == null) {
        print('ChatService: No Google account found');
        return null;
      }
      final auth = await account.authentication;
      if (auth.idToken == null) {
        print('ChatService: No ID token returned from Google Sign-In');
        return null;
      }
      print(
          'ChatService: Refreshed Google token: ${auth.idToken!.substring(0, 10)}...');
      _token = auth.idToken;
      setToken(auth.idToken!);
      return auth.idToken;
    } catch (e) {
      print('ChatService: Error refreshing Google token: $e');
      return null;
    }
  }

  void _initializeSocket() {
    if (_token == null || _token!.isEmpty) {
      print('ChatService: Cannot initialize socket: No token provided');
      return;
    }
    if (_socket != null && _socket!.connected) {
      print('ChatService: Socket already connected');
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
      print('ChatService: Received message via socket: $data');
      final message = Message.fromJson(data as Map<String, dynamic>);
      onMessageReceived?.call(message);
    });

    _socket?.on('error', (error) {
      print('ChatService: Socket.IO Error: $error');
      if (error.toString().contains('Invalid or expired token') &&
          _onTokenExpired != null) {
        _onTokenExpired!(_token!);
      }
    });

    _socket?.onConnect((_) {
      print('ChatService: Connected to socket server');
    });

    _socket?.onDisconnect((_) {
      print('ChatService: Disconnected from socket server');
    });

    _socket?.onConnectError((data) {
      print('ChatService: Socket connection error: $data');
      if (data.toString().contains('401') && _onTokenExpired != null) {
        _onTokenExpired!(_token!);
      }
    });
  }

  Function(Message)? onMessageReceived;

  void joinConversation(String conversationId) {
    if (_token == null || _token!.isEmpty) {
      print('ChatService: Cannot join conversation: No token provided');
      return;
    }
    if (_socket == null || !_socket!.connected) {
      print(
          'ChatService: Socket not connected, attempting to initialize: $conversationId');
      _initializeSocket();
      return;
    }
    print('ChatService: Joining conversation: $conversationId');
    _socket?.emit('joinConversation', conversationId);
  }

  void sendMessage(String conversationId, String senderId, String content) {
    if (_token == null || _token!.isEmpty) {
      print('ChatService: Cannot send message: No token provided');
      return;
    }
    if (_socket == null || !_socket!.connected) {
      print('ChatService: Socket not connected, attempting to initialize');
      _initializeSocket();
      return;
    }
    print(
        'ChatService: Sending message via socket: conversationId=$conversationId, senderId=$senderId, content=$content');
    _socket?.emit('sendMessage', {
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
    });
  }

  void disconnect() {
    print('ChatService: Disconnecting socket');
    _socket?.disconnect();
    _socket = null;
  }

  Future<Conversation> getOrCreateConversation({
    required String rentalId,
    required String landlordId,
    required String token,
  }) async {
    if (token.isEmpty) {
      print('ChatService: Invalid token for getOrCreateConversation');
      throw Exception('Invalid token');
    }
    final validToken = await _ensureValidToken();
    print(
        'ChatService: Creating conversation with rentalId: $rentalId, landlordId: $landlordId, token: ${validToken.substring(0, 10)}...');
    final response = await http.post(
      Uri.parse(ApiRoutes.conversations),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $validToken',
      },
      body: jsonEncode({
        'rentalId': rentalId,
        'landlordId': landlordId,
      }),
    );

    print(
        'ChatService: Response status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      final newToken = await refreshGoogleToken(forceInteractive: true);
      if (newToken != null) {
        return await getOrCreateConversation(
          rentalId: rentalId,
          landlordId: landlordId,
          token: newToken,
        );
      }
      throw Exception('Authentication failed: Invalid or expired token');
    } else {
      throw Exception('Failed to create conversation: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchMessages({
    required String conversationId,
    required String token,
    String? cursor,
    int limit = 10,
  }) async {
    if (token.isEmpty) {
      print('ChatService: Invalid token for fetchMessages');
      throw Exception('Invalid token');
    }
    final validToken = await _ensureValidToken();
    final query = cursor != null
        ? {'cursor': cursor, 'limit': limit.toString()}
        : {'limit': limit.toString()};
    final uri = Uri.parse(ApiRoutes.messagesByConversation(conversationId))
        .replace(queryParameters: query);

    print(
        'ChatService: Fetching messages for conversationId: $conversationId, uri: $uri, token: ${validToken.substring(0, 10)}...');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $validToken'},
    );

    print(
        'ChatService: Fetch messages status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = (data['messages'] as List)
          .map((msg) => Message.fromJson(msg))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return {'messages': messages, 'nextCursor': nextCursor};
    } else if (response.statusCode == 401) {
      final newToken = await refreshGoogleToken(forceInteractive: true);
      if (newToken != null) {
        return await fetchMessages(
          conversationId: conversationId,
          token: newToken,
          cursor: cursor,
          limit: limit,
        );
      }
      throw Exception('Authentication failed: Invalid or expired token');
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  Future<List<Conversation>> fetchConversations(String token) async {
    if (token.isEmpty) {
      print('ChatService: Invalid token for fetchConversations');
      throw Exception('Invalid token');
    }
    final validToken = await _ensureValidToken();
    print(
        'ChatService: Fetching conversations with token: ${validToken.substring(0, 10)}...');
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(ApiRoutes.conversations),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        print(
            'ChatService: Fetch conversations status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => Conversation.fromJson(json)).toList();
        } else if (response.statusCode == 401) {
          final newToken = await refreshGoogleToken(forceInteractive: true);
          if (newToken != null) {
            return await fetchConversations(newToken);
          }
          throw Exception('Authentication failed: Invalid or expired token');
        } else {
          throw Exception('Failed to fetch conversations: ${response.body}');
        }
      } catch (e) {
        print('ChatService: Attempt $attempt failed: $e');
        if (attempt == 3) {
          throw Exception(
              'Failed to fetch conversations after $attempt attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Failed to fetch conversations: Max retries reached');
  }

  Future<List<Conversation>> fetchPendingConversations(String token) async {
    if (token.isEmpty) {
      print('ChatService: Invalid token for fetchPendingConversations');
      throw Exception('Invalid token');
    }
    final validToken = await _ensureValidToken();
    print(
        'ChatService: Fetching pending conversations with token: ${validToken.substring(0, 10)}...');
    final response = await http.get(
      Uri.parse(ApiRoutes.pendingConversations),
      headers: {'Authorization': 'Bearer $validToken'},
    );

    print(
        'ChatService: Fetch pending conversations status: ${response.statusCode}, body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      final newToken = await refreshGoogleToken(forceInteractive: true);
      if (newToken != null) {
        return await fetchPendingConversations(newToken);
      }
      throw Exception('Authentication failed: Invalid or expired token');
    } else {
      throw Exception('Failed to load conversations: ${response.body}');
    }
  }
}
