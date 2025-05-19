import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  List<Conversation> _pendingConversations = [];
  List<Message> _messages = [];
  String? _nextCursor;
  bool _isLoading = false;
  String? _errorMessage;

  List<Conversation> get conversations => _conversations;
  List<Conversation> get pendingConversations => _pendingConversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize Socket.IO connection
  void initializeSocket(String token) {
    _chatService.connect(token, (message) {
      _messages.insert(0, message);
      notifyListeners();
    });
  }

  // Join a conversation room
  void joinConversation(String conversationId) {
    _chatService.joinConversation(conversationId);
  }

  // Send a message
  void sendMessage(String conversationId, String senderId, String content) {
    _chatService.sendMessage(conversationId, senderId, content);
  }

  // Disconnect Socket.IO
  void disconnectSocket() {
    _chatService.disconnect();
  }

  // Get or create a conversation
  Future<void> getOrCreateConversation({
    required String rentalId,
    required String landlordId,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final conversation = await _chatService.getOrCreateConversation(
        rentalId: rentalId,
        landlordId: landlordId,
        token: token,
      );
      _conversations.add(conversation);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch messages for a conversation
  Future<void> fetchMessages({
    required String conversationId,
    required String token,
    String? cursor,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _chatService.fetchMessages(
        conversationId: conversationId,
        token: token,
        cursor: cursor,
      );
      if (cursor == null) {
        _messages = result['messages'] as List<Message>;
      } else {
        _messages.addAll(result['messages'] as List<Message>);
      }
      _nextCursor = result['nextCursor'] as String?;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all conversations
  Future<void> fetchConversations(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _chatService.fetchConversations(token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch pending conversations
  Future<void> fetchPendingConversations(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingConversations = await _chatService.fetchPendingConversations(token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load more messages
  Future<void> loadMoreMessages(String conversationId, String token) async {
    if (_nextCursor == null || _isLoading) return;
    await fetchMessages(
      conversationId: conversationId,
      token: token,
      cursor: _nextCursor,
    );
  }
}