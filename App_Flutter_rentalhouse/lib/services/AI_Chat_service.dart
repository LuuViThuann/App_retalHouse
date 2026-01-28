import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';

class ChatAIService {
  /// Lấy auth token từ AuthService
  static Future<String?> _getAuthToken() async {
    try {
      final authService = AuthService();
      final token = await authService.getIdToken();
      return token;
    } catch (e) {
      print('❌ Error getting auth token: $e');
      return null;
    }
  }

  /// 💬 Chat với AI assistant
  static Future<ChatResponse> chat({
    required String message,
    List<ChatMessage>? conversationHistory,
    String? conversationId,
    bool includeRecommendations = true,
    Map<String, dynamic>? userContext,
    // 🔥 NEW: Add location parameters
    double? latitude,
    double? longitude,
  }) async {
    try {
      print('═════════════════════════════════════════════');
      print('💬 CHAT AI REQUEST');
      print('📝 Message: "$message"');
      print('📚 History: ${conversationHistory?.length ?? 0} messages');
      print('🆔 Conversation ID: ${conversationId ?? "new"}');

      // 🔥 NEW: Log location if provided
      if (latitude != null && longitude != null) {
        print('📍 User Location: ($latitude, $longitude)');
      }

      print('═════════════════════════════════════════════');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 🔥 NEW: Add location to userContext
      Map<String, dynamic> enhancedContext = userContext ?? {};
      if (latitude != null && longitude != null) {
        enhancedContext['currentLocation'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
      }

      final body = jsonEncode({
        'message': message,
        'conversationHistory': conversationHistory?.map((msg) => msg.toJson()).toList() ?? [],
        'conversationId': conversationId,
        'includeRecommendations': includeRecommendations,
        'userContext': enhancedContext,  // 🔥 Use enhanced context
      });

      print('🔗 URL: ${ApiRoutes.aiChat}');

      final response = await http.post(
        Uri.parse(ApiRoutes.aiChat),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ Chat response received');
        print('🏠 Recommendations: ${data['recommendations']?.length ?? 0}');

        // 🔥 NEW: Log filter metadata
        if (data['metadata'] != null) {
          print('📍 Location filter: ${data['metadata']['hasLocationFilter']}');
          print('🏢 POI filter: ${data['metadata']['hasPOIFilter']}');
        }

        return ChatResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Chat failed');
      }
    } catch (e) {
      print('❌ Exception in chat: $e');
      rethrow;
    }
  }

  /// 🎯 Lấy gợi ý chi tiết từ ML model + MongoDB
  static Future<RecommendationsWithDetailsResponse> getRecommendationsWithDetails({
    required String userId,
    int n_recommendations = 5,
    Map<String, dynamic>? userPreferences,
    double radius_km = 20,
    bool useLocation = true,
    Map<String, dynamic>? context,
  }) async {
    try {
      print('🎯 [RECOMMENDATIONS] Getting from ML model...');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Auth required');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'n_recommendations': n_recommendations,
        'userPreferences': userPreferences,
        'radius_km': radius_km,
        'useLocation': useLocation,
        'context': context,
      });

      final response = await http.post(
        Uri.parse(ApiRoutes.aiChatRecommendationsWithDetails),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ Got ${data['recommendations']?.length ?? 0} recommendations');
        return RecommendationsWithDetailsResponse.fromJson(data);
      } else {
        throw Exception('Failed to get recommendations');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  /// 🆕 Bắt đầu cuộc hội thoại mới
  static Future<ConversationStartResponse> startConversation({
    Map<String, dynamic>? initialContext,
  }) async {
    try {
      print('🆕 Starting new conversation...');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'initialContext': initialContext});

      final response = await http.post(
        Uri.parse(ApiRoutes.aiChatConversationStart),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      print('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ Conversation started: ${data['conversationId']}');
        return ConversationStartResponse.fromJson(data);
      } else {
        throw Exception('Failed to start conversation');
      }
    } catch (e) {
      print('❌ Error starting conversation: $e');
      rethrow;
    }
  }

  /// 🤔 Giải thích chi tiết 1 bài đăng
  static Future<ExplanationResponse> explainRental({
    required String rentalId,
    String conversationContext = '',
  }) async {
    try {
      print('🤔 Explaining rental: $rentalId');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'rentalId': rentalId,
        'conversationContext': conversationContext,
      });

      final response = await http.post(
        Uri.parse(ApiRoutes.aiChatExplainRental),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ Explanation received');
        return ExplanationResponse.fromJson(data);
      } else {
        throw Exception('Failed to get explanation');
      }
    } catch (e) {
      print('❌ Error explaining rental: $e');
      rethrow;
    }
  }

  /// 💡 Lấy gợi ý câu hỏi tiếp theo
  static Future<List<String>> getSuggestions(String userId) async {
    try {
      print('💡 Getting suggestions for user: $userId');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {'Authorization': 'Bearer $token'};

      final response = await http.get(
        Uri.parse(ApiRoutes.aiChatSuggestions(userId)),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['suggestions'] != null) {
          final suggestions = List<String>.from(data['suggestions']);
          print('✅ Got ${suggestions.length} suggestions');
          return suggestions;
        }
      }

      // Fallback suggestions
      return [
        '🏠 Bạn muốn thuê nhà ở khu vực nào?',
        '💰 Tầm giá bao nhiêu là phù hợp?',
        '🛏️ Bạn cần bao nhiêu phòng ngủ?',
        '✨ Có tiện ích nào quan trọng với bạn không?',
        '📐 Diện tích cần bao nhiêu m²?'
      ];
    } catch (e) {
      print('❌ Error getting suggestions: $e');
      return [
        '🏠 Bạn muốn thuê nhà ở khu vực nào?',
        '💰 Tầm giá bao nhiêu là phù hợp?',
      ];
    }
  }

  /// 📚 Lấy lịch sử cuộc hội thoại
  static Future<Conversation?> getConversation(String conversationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {'Authorization': 'Bearer $token'};

      final response = await http.get(
        Uri.parse(ApiRoutes.aiChatConversation(conversationId)),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['conversation'] != null) {
          return Conversation.fromJson(data['conversation']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting conversation: $e');
      return null;
    }
  }

  /// 📋 Lấy danh sách conversations
  static Future<ConversationListResponse> getConversationList(
      String userId, {
        int limit = 10,
        int skip = 0,
        String? status,
      }) async {
    try {
      print('📋 Getting conversation list for user: $userId');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {'Authorization': 'Bearer $token'};

      var url = Uri.parse(ApiRoutes.aiChatConversationList(userId, limit: limit, skip: skip));
      if (status != null) {
        url = url.replace(queryParameters: {...url.queryParameters, 'status': status});
      }

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ConversationListResponse.fromJson(data);
      } else {
        throw Exception('Failed to get conversation list');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  /// ⭐ Rating recommendation
  static Future<void> rateRecommendation({
    required String conversationId,
    required String rentalId,
    required int rating,
    String comment = '',
  }) async {
    try {
      print('⭐ Rating recommendation: $rating stars');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'conversationId': conversationId,
        'rentalId': rentalId,
        'rating': rating,
        'comment': comment,
      });

      final response = await http.post(
        Uri.parse(ApiRoutes.aiChatRating),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Rating saved');
      }
    } catch (e) {
      print('❌ Error rating: $e');
    }
  }

  /// 📊 Get chat stats
  static Future<ChatStatsResponse?> getChatStats() async {
    try {
      print('📊 Getting chat stats...');

      final token = await _getAuthToken();
      if (token == null) throw Exception('Authentication required');

      final headers = {'Authorization': 'Bearer $token'};

      final response = await http.get(
        Uri.parse(ApiRoutes.aiChatStats),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ChatStatsResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }

  /// 💚 Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.aiChatHealth),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ==================== MODELS ====================

class ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }
}

class ChatResponse {
  final bool success;
  final String message;
  final String intent;
  final Map<String, dynamic>? extractedPreferences;
  final bool shouldRecommend;
  final List<Rental>? recommendations;
  final String? explanation;
  final Map<String, int>? usage;
  final String? conversationId;

  ChatResponse({
    required this.success,
    required this.message,
    required this.intent,
    this.extractedPreferences,
    required this.shouldRecommend,
    this.recommendations,
    this.explanation,
    this.usage,
    this.conversationId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    List<Rental>? parsedRecommendations;

    try {
      if (json['recommendations'] != null && json['recommendations'] is List) {
        parsedRecommendations = (json['recommendations'] as List).map((r) {
          // 🔥 FIX: Safely parse each recommendation
          try {
            // Ensure r is a Map
            if (r is! Map<String, dynamic>) {
              print('⚠️ Skipping non-map recommendation: $r');
              return null;
            }

            return Rental.fromJson(r);
          } catch (e) {
            print('❌ Error parsing rental: $e');
            print('📦 Problematic data: $r');
            return null;
          }
        })
            .where((rental) => rental != null)
            .cast<Rental>()
            .toList();
      }
    } catch (e) {
      print('❌ Error parsing recommendations list: $e');
      parsedRecommendations = null;
    }

    return ChatResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      intent: json['intent'] as String,
      extractedPreferences: json['extractedPreferences'] as Map<String, dynamic>?,
      shouldRecommend: json['shouldRecommend'] as bool? ?? false,
      recommendations: parsedRecommendations,
      explanation: json['explanation'] as String?,
      usage: json['usage'] != null ? Map<String, int>.from(json['usage']) : null,
      conversationId: json['conversationId'] as String?,
    );
  }
}

class ConversationStartResponse {
  final bool success;
  final String conversationId;
  final String greeting;
  final Map<String, dynamic>? userContext;

  ConversationStartResponse({
    required this.success,
    required this.conversationId,
    required this.greeting,
    this.userContext,
  });

  factory ConversationStartResponse.fromJson(Map<String, dynamic> json) {
    return ConversationStartResponse(
      success: json['success'] as bool,
      conversationId: json['conversationId'] as String,
      greeting: json['greeting'] as String,
      userContext: json['userContext'] as Map<String, dynamic>?,
    );
  }
}

class ExplanationResponse {
  final bool success;
  final Map<String, dynamic> rental;
  final String explanation;
  final Map<String, dynamic>? userPreferences;

  ExplanationResponse({
    required this.success,
    required this.rental,
    required this.explanation,
    this.userPreferences,
  });

  factory ExplanationResponse.fromJson(Map<String, dynamic> json) {
    return ExplanationResponse(
      success: json['success'] as bool,
      rental: json['rental'] as Map<String, dynamic>,
      explanation: json['explanation'] as String,
      userPreferences: json['userPreferences'] as Map<String, dynamic>?,
    );
  }
}

class Conversation {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? extractedPreferences;
  final String status;
  final DateTime startedAt;
  final DateTime lastMessageAt;

  Conversation({
    required this.id,
    required this.userId,
    required this.messages,
    this.extractedPreferences,
    required this.status,
    required this.startedAt,
    required this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
      extractedPreferences: json['extractedPreferences'] as Map<String, dynamic>?,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['startedAt']),
      lastMessageAt: DateTime.parse(json['lastMessageAt']),
    );
  }
}

class RecommendationsWithDetailsResponse {
  final bool success;
  final List<RentalRecommendationDetail> recommendations;
  final int total;
  final bool isFromML;
  final Map<String, dynamic>? userPreferences;
  final String? message;

  RecommendationsWithDetailsResponse({
    required this.success,
    required this.recommendations,
    required this.total,
    required this.isFromML,
    this.userPreferences,
    this.message,
  });

  factory RecommendationsWithDetailsResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationsWithDetailsResponse(
      success: json['success'] as bool,
      recommendations: (json['recommendations'] as List?)
          ?.map((r) => RentalRecommendationDetail.fromJson(r))
          .toList() ?? [],
      total: json['total'] as int? ?? 0,
      isFromML: json['isFromML'] as bool? ?? false,
      userPreferences: json['userPreferences'] as Map<String, dynamic>?,
      message: json['message'] as String?,
    );
  }
}

class RentalRecommendationDetail {
  final String id;
  final String title;
  final double price;
  final String propertyType;
  final Map<String, dynamic>? area;
  final List<String>? images;
  final List<String>? amenities;
  final String? locationShort;
  final String? locationFull;
  final double confidence;
  final double finalScore;
  final String explanation;
  final double? distanceKm;
  final String method;

  RentalRecommendationDetail({
    required this.id,
    required this.title,
    required this.price,
    required this.propertyType,
    this.area,
    this.images,
    this.amenities,
    this.locationShort,
    this.locationFull,
    required this.confidence,
    required this.finalScore,
    required this.explanation,
    this.distanceKm,
    required this.method,
  });

  factory RentalRecommendationDetail.fromJson(Map<String, dynamic> json) {
    return RentalRecommendationDetail(
      id: json['_id'] as String,
      title: json['title'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      propertyType: json['propertyType'] as String? ?? 'Unknown',
      area: json['area'] as Map<String, dynamic>?,
      images: (json['images'] as List?)?.cast<String>(),
      amenities: (json['amenities'] as List?)?.cast<String>(),
      locationShort: json['location']?['short'] as String?,
      locationFull: json['location']?['full'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      finalScore: (json['finalScore'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      method: json['method'] as String? ?? 'unknown',
    );
  }
}

class ConversationListResponse {
  final bool success;
  final List<ConversationItem> conversations;
  final int total;
  final int limit;
  final int skip;
  final bool hasMore;

  ConversationListResponse({
    required this.success,
    required this.conversations,
    required this.total,
    required this.limit,
    required this.skip,
    required this.hasMore,
  });

  factory ConversationListResponse.fromJson(Map<String, dynamic> json) {
    return ConversationListResponse(
      success: json['success'] as bool,
      conversations: (json['conversations'] as List?)
          ?.map((c) => ConversationItem.fromJson(c))
          .toList() ?? [],
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 10,
      skip: json['skip'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class ConversationItem {
  final String id;
  final String status;
  final int messageCount;
  final int recommendationCount;
  final DateTime startedAt;
  final DateTime lastMessageAt;
  final String preview;

  ConversationItem({
    required this.id,
    required this.status,
    required this.messageCount,
    required this.recommendationCount,
    required this.startedAt,
    required this.lastMessageAt,
    required this.preview,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['_id'] as String,
      status: json['status'] as String? ?? 'active',
      messageCount: json['messageCount'] as int? ?? 0,
      recommendationCount: json['recommendationCount'] as int? ?? 0,
      startedAt: DateTime.parse(json['startedAt'] ?? DateTime.now().toIso8601String()),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] ?? DateTime.now().toIso8601String()),
      preview: json['preview'] as String? ?? 'Trống',
    );
  }
}

class ChatStatsResponse {
  final bool success;
  final String userId;
  final ChatStats stats;

  ChatStatsResponse({
    required this.success,
    required this.userId,
    required this.stats,
  });

  factory ChatStatsResponse.fromJson(Map<String, dynamic> json) {
    return ChatStatsResponse(
      success: json['success'] as bool,
      userId: json['userId'] as String,
      stats: ChatStats.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }
}

class ChatStats {
  final int totalConversations;
  final int activeConversations;
  final int completedConversations;
  final int totalMessages;
  final int totalRecommendations;
  final double avgMessagesPerConversation;

  ChatStats({
    required this.totalConversations,
    required this.activeConversations,
    required this.completedConversations,
    required this.totalMessages,
    required this.totalRecommendations,
    required this.avgMessagesPerConversation,
  });

  factory ChatStats.fromJson(Map<String, dynamic> json) {
    return ChatStats(
      totalConversations: json['totalConversations'] as int? ?? 0,
      activeConversations: json['activeConversations'] as int? ?? 0,
      completedConversations: json['completedConversations'] as int? ?? 0,
      totalMessages: json['totalMessages'] as int? ?? 0,
      totalRecommendations: json['totalRecommendations'] as int? ?? 0,
      avgMessagesPerConversation: double.tryParse(json['avgMessagesPerConversation'].toString()) ?? 0.0,
    );
  }
}