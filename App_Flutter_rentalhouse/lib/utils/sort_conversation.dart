import 'package:flutter_rentalhouse/models/conversation.dart';

class ConversationSorter {
  static List<Conversation> sortConversations(List<Conversation> conversations) {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      // Prioritize conversations with unread messages
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;

      // Within unread conversations, sort by updatedAt (newest first)
      if (a.unreadCount > 0 && b.unreadCount > 0) {
        final aTime = a.lastMessage?.createdAt ?? a.updatedAt;
        final bTime = b.lastMessage?.createdAt ?? b.updatedAt;
        if (bTime == null && aTime == null) return 0;
        if (bTime == null) return 1;
        if (aTime == null) return -1;
        return bTime.compareTo(aTime);
      }

      // For read conversations, check if they have messages
      final aHasMessages = a.lastMessage != null;
      final bHasMessages = b.lastMessage != null;

      // Prioritize conversations with messages over those without
      if (aHasMessages && !bHasMessages) return -1;
      if (!aHasMessages && bHasMessages) return 1;

      // Within conversations with messages, sort by last message time
      if (aHasMessages && bHasMessages) {
        return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
      }

      // For conversations without messages, sort by createdAt
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}