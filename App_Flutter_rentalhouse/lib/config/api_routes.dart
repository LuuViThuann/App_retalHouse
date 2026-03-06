import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiRoutes {
  static const String rootUrl =
      'http://192.168.1.226:3000'; // http://192.168.43.168:3000 - mạng dữ liệu
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;
  static const String socketUrl = serverBaseUrl;


// ==================== AI CHAT ENDPOINTS (NEW) ====================

  /// POST /api/ai/chat - Chat với AI assistant
  static const String aiChat = '$baseUrl/ai/chat';

  /// DELETE /api/ai/conversation-list/:id - Xóa một conversation
  static String aiDeleteConversation(String conversationId) {
    return '$baseUrl/ai/conversation-list/$conversationId';
  }

  /// DELETE /api/ai/conversation-list/empty/clean - Xóa tất cả conversation trống
  static const String aiCleanEmptyConversations = '$baseUrl/ai/conversation-list/empty/clean';

  /// POST /api/ai/chat/recommendations-with-details - Lấy gợi ý chi tiết
  static const String aiChatRecommendationsWithDetails =
      '$baseUrl/ai/chat/recommendations-with-details';

  static const String aiRecommendationsSimilar =
      '$baseUrl/ai/recommendations/similar';

  /// POST /api/ai/chat/explain-rental - Giải thích chi tiết 1 bài đăng
  static const String aiChatExplainRental = '$baseUrl/ai/chat/explain-rental';

  /// GET /api/ai/chat/suggestions/:userId - Lấy gợi ý câu hỏi tiếp theo
  static String aiChatSuggestions(String userId) {
    return '$baseUrl/ai/chat/suggestions/$userId';
  }

  /// POST /api/ai/chat/conversation/start - Bắt đầu cuộc hội thoại mới
  static const String aiChatConversationStart =
      '$baseUrl/ai/chat/conversation/start';

  /// GET /api/ai/chat/conversation/:conversationId - Lấy lịch sử chat
  static String aiChatConversation(String conversationId) {
    return '$baseUrl/ai/chat/conversation/$conversationId';
  }

  /// DELETE /api/ai/chat/conversation/:conversationId - Kết thúc chat
  static String aiChatConversationDelete(String conversationId) {
    return '$baseUrl/ai/chat/conversation/$conversationId';
  }

  /// GET /api/ai/chat/user-preferences/:userId - Lấy user preferences
  static String aiChatUserPreferences(String userId) {
    return '$baseUrl/ai/chat/user-preferences/$userId';
  }

  /// GET /api/ai/chat/stats - Thống kê chat service
  static const String aiChatStats = '$baseUrl/ai/chat/stats';

  /// POST /api/ai/chat/feedback - Log feedback trên gợi ý
  static const String aiChatFeedback = '$baseUrl/ai/chat/feedback';

  /// POST /api/ai/chat/search-with-ai - Tìm kiếm với AI interpretation
  static const String aiChatSearchWithAI = '$baseUrl/ai/chat/search-with-ai';

  /// POST /api/ai/chat/compare-rentals - So sánh rentals bằng AI
  static const String aiChatCompareRentals = '$baseUrl/ai/chat/compare-rentals';

  /// GET /api/ai/chat/conversation-list/:userId - Danh sách conversations
  static String aiChatConversationList(String userId, {int limit = 10, int skip = 0}) {
    return '$baseUrl/ai/conversation-list/$userId?limit=$limit&skip=$skip';
  }

  /// POST /api/ai/chat/rating - Rating gợi ý/conversation
  static const String aiChatRating = '$baseUrl/ai/chat/rating';

  /// GET /api/ai/chat/health - Health check
  static const String aiChatHealth = '$baseUrl/ai/chat/health';
  // ==================== POI ENDPOINTS ====================
  /// GET /api/poi/categories - Lấy danh sách categories
  static const String poiCategories = '$baseUrl/poi/categories';
  static const String filterRentalsByPOI = '$baseUrl/poi/filter-rentals-by-poi';
  /// POST /api/poi/ai-recommendations - AI + POI combined
  static const String aiPOIRecommendations = '$baseUrl/poi/ai-recommendations';
  /// GET /api/poi/nearby?latitude=...&longitude=...&category=EDUCATION&radius=5
  static String poiNearby({
    required double latitude,
    required double longitude,
    String? category,
    double radius = 5.0,
  }) {
    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'radius': radius.toStringAsFixed(2),
    };
    if (category != null && category != 'ALL') {
      params['category'] = category;
    }
    final uri = Uri.parse('$baseUrl/poi/nearby').replace(queryParameters: params);
    return uri.toString();
  }


  /// POST /api/poi/rentals-near-poi - Lấy rentals gần POI
  static const String rentalsNearPOI = '$baseUrl/poi/rentals-near-poi';

  // ====================  AI RECOMMENDATIONS ====================
//   /recommend/personalized/with-poi

  static String aiRecommendationsPersonalizedWithPOI({
    required double latitude,
    required double longitude,
    required List<String> selectedCategories,
    double radius = 10.0,
    double poiRadius = 3.0,
    int? limit,
    double? minPrice,
    double? maxPrice,
  }) {
    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'radius': radius.toStringAsFixed(2),
      'poiRadius': poiRadius.toStringAsFixed(2),

    };
    if (limit != null) params['limit'] = limit.toString();
    // 🔥 THÊM selectedCategories theo cách safe
    for (int i = 0; i < selectedCategories.length; i++) {
      params['selectedCategories[$i]'] = selectedCategories[i];
    }

    if (minPrice != null && minPrice > 0) {
      params['minPrice'] = minPrice.toStringAsFixed(0);
    }

    if (maxPrice != null && maxPrice > 0) {
      params['maxPrice'] = maxPrice.toStringAsFixed(0);
    }

    final uri = Uri.parse('$baseUrl/ai/recommendations/personalized/with-poi')
        .replace(queryParameters: params);

    debugPrint('🤖🏢 [AI+POI-URL] ${uri.toString()}');
    return uri.toString();
  }
  /// 🔥 NEW: GET /api/ai/recommendations/personalized/context
  /// Gợi ý cá nhân hóa với context (map center, zoom, device, impressions)
  /// 📌 Thay thế cho /api/ai/recommendations/personalized
  static String aiRecommendationsPersonalizedContext({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int zoomLevel = 15,
    String timeOfDay = 'morning',
    String deviceType = 'mobile',
    int? limit,
    String impressions = '', // Comma-separated rental IDs already shown
    double scrollDepth = 0.5,
  }) {
    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'radius': radius.toStringAsFixed(2),
      'zoom_level': zoomLevel.toString(),
      'time_of_day': timeOfDay,
      'device_type': deviceType,

      'scroll_depth': scrollDepth.toStringAsFixed(2),
    };
    if (limit != null) params['limit'] = limit.toString();
    if (impressions.isNotEmpty) {
      params['impressions'] = impressions;
    }
    final uri = Uri.parse('$baseUrl/ai/recommendations/personalized/context')
        .replace(queryParameters: params);

    debugPrint('🎯 [AI-CONTEXT] URL: ${uri.toString()}');
    return uri.toString();
  }

  // ----------------------------------

  static String aiRecommendationsPersonalized({
    int limit = 10,
    double? latitude,
    double? longitude,
    double radius = 10.0,
    double? minPrice,
    double? maxPrice,
  }) {
    final params = <String, String>{
      'limit': limit.toString(),
    };

    // GỬI THÔNG TIN XÁC NHẬN TOẠN ĐỘ VÀ KHOẢNG CÁCH
    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toStringAsFixed(6);
      params['longitude'] = longitude.toStringAsFixed(6);
      params['radius'] = radius.toStringAsFixed(2);
    } else {
      throw ArgumentError(
          'latitude and longitude are required for aiRecommendationsPersonalized'
      );
    }

    if (minPrice != null && minPrice > 0) {
      params['minPrice'] = minPrice.toStringAsFixed(0);
    }

    if (maxPrice != null && maxPrice > 0) {
      params['maxPrice'] = maxPrice.toStringAsFixed(0);
    }

    final uri = Uri.parse('$baseUrl/ai/recommendations/personalized')
        .replace(queryParameters: params);

    debugPrint('🤖 AI Personalized URL: ${uri.toString()}');
    return uri.toString();
  }

  /// GET /api/ai/recommendations/nearby/:rentalId
  /// AI gợi ý nearby kết hợp với geospatial query
  static String aiRecommendationsNearby({
    required String rentalId,
    int? limit,
    double radius = 10.0,
  }) {
    if (rentalId.isEmpty || rentalId.startsWith('current_location_')) {
      throw ArgumentError(
          'Invalid rental ID: $rentalId. Use aiRecommendationsPersonalized instead.'
      );
    }

    final params = <String, String>{

      'radius': radius.toStringAsFixed(2),
    };
    if (limit != null) params['limit'] = limit.toString();
    final uri = Uri.parse('$baseUrl/ai/recommendations/nearby/$rentalId')
        .replace(queryParameters: params);

    debugPrint('🤖 AI Nearby URL: ${uri.toString()}');
    return uri.toString();
  }

  // ==================== AI EXPLAIN - NEW ====================

  static String aiExplain({
    required String userId,
    required String rentalId,
  }) {
    if (userId.isEmpty || rentalId.isEmpty) {
      throw ArgumentError('userId and rentalId are required');
    }

    final uri = Uri.parse('$baseUrl/ai/explain/$userId/$rentalId');
    debugPrint('🤔 [AI-EXPLAIN] URL: ${uri.toString()}');
    return uri.toString();
  }

  // ==================== USER PREFERENCES - NEW ====================

  static String userPreferences({required String userId}) {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }

    final uri = Uri.parse('$baseUrl/ai/user-preferences/$userId');
    debugPrint('👤 [USER-PREFS] URL: ${uri.toString()}');
    return uri.toString();
  }

// ==================== NEARBY RENTALS (FIXED) =================================
  //Lấy bài đăng gần một bài đăng khác (dùng rental ID)

  static String nearbyRentals({
    required String rentalId,
    double radius = 10.0,
    int page = 1,
    int? limit,
    double? minPrice,
    double? maxPrice,
  }) {
    //  Validate rentalId
    if (rentalId.isEmpty || rentalId.startsWith('current_location_')) {
      throw ArgumentError('Invalid rental ID: $rentalId. Use nearbyFromLocation instead.');
    }

    final params = <String, String>{
      'radius': radius.toStringAsFixed(2),
      'page': page.toString(),

    };

    if (limit != null) params['limit'] = limit.toString();
    if (minPrice != null && minPrice > 0) {
      params['minPrice'] = minPrice.toStringAsFixed(0);
    }

    if (maxPrice != null && maxPrice > 0) {
      params['maxPrice'] = maxPrice.toStringAsFixed(0);
    }

    final uri = Uri.parse('$rentals/nearby/$rentalId')
        .replace(queryParameters: params);

    debugPrint(' Nearby rentals URL: ${uri.toString()}');
    return uri.toString();
  }

  static String nearbyFromLocation({
    required double latitude,
    required double longitude,
    double radius = 10.0,
    int page = 1,
    int? limit,
    double? minPrice,
    double? maxPrice,
  }) {

    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw ArgumentError(
          'Invalid coordinates: lat=$latitude (must be [-90,90]), lon=$longitude (must be [-180,180])'
      );
    }


    if (radius <= 0 || radius > 100) {
      throw ArgumentError('Radius must be between 0 and 100 km, got $radius');
    }

    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'radius': radius.toStringAsFixed(2),
      'page': page.toString(),

    };
    if (limit != null) params['limit'] = limit.toString();
    if (minPrice != null && minPrice > 0) {
      params['minPrice'] = minPrice.toStringAsFixed(0);
    }

    if (maxPrice != null && maxPrice > 0) {
      params['maxPrice'] = maxPrice.toStringAsFixed(0);
    }

    final uri = Uri.parse('$rentals/nearby-from-location')
        .replace(queryParameters: params);

    debugPrint('🔗 Nearby from location URL: ${uri.toString()}');
    return uri.toString();
  }

  ///  BARU: Endpoint để khắc phục geospatial index (chỉ gọi một lần)
  static const String ensureGeospatialIndex = '$baseUrl/admin/ensure-geospatial-index';
  // ==================== ANALYTICS ENDPOINTS ====================

  /// GET /api/analytics/overview - Tổng quan thống kê
  static const String analyticsOverview = '$baseUrl/analytics/overview';

  ///GET /api/analytics/price-distribution - Phân bố giá
  static const String analyticsPriceDistribution = '$baseUrl/analytics/price-distribution';

  ///  GET /api/analytics/posts-timeline?period=day|week|month
  static String analyticsPostsTimeline({String period = 'day'}) {
    return '$baseUrl/analytics/posts-timeline?period=$period';
  }

  /// GET /api/analytics/location-stats - Thống kê theo khu vực
  static const String analyticsLocationStats = '$baseUrl/analytics/location-stats';

  ///GET /api/analytics/hottest-areas?days=7 - Khu vực nóng nhất
  static String analyticsHottestAreas({int days = 7}) {
    return '$baseUrl/analytics/hottest-areas?days=$days';
  }

  ///GET /api/analytics/trending-areas?days=7 - Khu vực trending
  static String analyticsTrendingAreas({int days = 7}) {
    return '$baseUrl/analytics/trending-areas?days=$days';
  }

  ///GET /api/analytics/property-types - Thống kê loại nhà
  static const String analyticsPropertyTypes = '$baseUrl/analytics/property-types';


  static const String analyticsAreaDistribution   = '$baseUrl/analytics/area-distribution';
  static const String analyticsAmenitiesStats     = '$baseUrl/analytics/amenities-stats';
  static const String analyticsUserBehavior       = '$baseUrl/analytics/user-behavior';
  static const String analyticsGrowthStats        = '$baseUrl/analytics/growth-stats';
  // ==================== SEARCH HISTORY ====================
  /// GET /api/search-history - Lấy lịch sử tìm kiếm
  static const String searchHistory = '$baseUrl/search-history';

  /// DELETE /api/search-history/:query - Xóa một mục lịch sử
  static String deleteSearchHistoryItem(String query) {
    final encodedQuery = Uri.encodeComponent(query);
    return '$searchHistory/$encodedQuery';
  }

  /// DELETE /api/search-history - Xóa toàn bộ lịch sử
  static const String clearSearchHistory = searchHistory;

  // ==================== RENTALS SEARCH ====================

  /// GET /api/rentals/search - Tìm kiếm tối ưu
  static String rentalsSearch({
    String? search,
    double? minPrice,
    double? maxPrice,
    List<String>? propertyTypes,
    String? status,
    int page = 1,
    int limit = 10,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    if (minPrice != null) {
      params['minPrice'] = minPrice.toString();
    }

    if (maxPrice != null) {
      params['maxPrice'] = maxPrice.toString();
    }

    if (propertyTypes != null && propertyTypes.isNotEmpty) {
      // Gửi nhiều propertyType
      for (final type in propertyTypes) {
        params['propertyType'] = type;
      }
    }

    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final uri = Uri.parse('$rentals/search').replace(queryParameters: params);
    return uri.toString();
  }

  // ==================== VNPAY PAYMENT ====================
  /// POST /api/vnpay/create-payment
  static const String vnpayCreatePayment = '$baseUrl/vnpay/create-payment';

  /// GET /api/vnpay/check-payment/:transactionCode
  static String vnpayCheckPayment(String transactionCode) {
    return '$baseUrl/vnpay/check-payment/$transactionCode';
  }

  /// GET /api/vnpay/payment-history?page=1&limit=10&status=completed
  static String vnpayPaymentHistory({
    int page = 1,
    int limit = 10,
    String? status,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final uri = Uri.parse('$baseUrl/vnpay/payment-history')
        .replace(queryParameters: params);
    return uri.toString();
  }

  /// POST /api/vnpay/verify-and-publish
  static const String vnpayVerifyAndPublish =
      '$baseUrl/vnpay/verify-and-publish';

  /// GET /api/rentals/:id/payment-status
  static String rentalPaymentStatus(String rentalId) {
    return '$rentals/$rentalId/payment-status';
  }

  /// GET /api/vnpay/return (VNPay callback URL)
  static const String vnpayReturn = '$baseUrl/vnpay/return';

  /// POST /api/vnpay/ipn (VNPay IPN URL)
  static const String vnpayIPN = '$baseUrl/vnpay/ipn';

  // ================== ABOUT US  ==================
  static const String aboutUs = '$baseUrl/aboutus';
  static const String adminAboutUs = '$baseUrl/admin/aboutus';

  static String adminAboutUsDetail(String id) => '$adminAboutUs/$id';
  static String adminAboutUsDeleteImage(String id) => '$adminAboutUs/$id/image';
  static String adminAboutUsDelete(String id) => '$adminAboutUs/$id';

  // ================== FEEDBACK  ==================
  static const String feedback = '$baseUrl/feedback';
  static const String myFeedback = '$feedback/my-feedback';
  static const String adminFeedback = '$baseUrl/admin/feedback';
  static const String adminFeedbackStats = '$adminFeedback/stats';

  static String adminFeedbackDetail(String id) => '$adminFeedback/$id';
  static String adminFeedbackStatus(String id) => '$adminFeedback/$id/status';
  static String adminFeedbackDelete(String id) => '$adminFeedback/$id';
  static String deleteMyFeedback(String feedbackId) => '$feedback/$feedbackId';


  // Hoàn tác feedback (Admin)
  static String adminFeedbackRestore(String id) => '$adminFeedback/$id/restore';

  // Xóa vĩnh viễn feedback (Admin)
  static String adminFeedbackPermanentDelete(String id) => '$adminFeedback/$id/permanent';

  //  Hoàn tác feedback của user
  static String restoreMyFeedback(String feedbackId) => '$feedback/$feedbackId/restore';

  //  Xóa vĩnh viễn feedback của user
  static String permanentDeleteMyFeedback(String feedbackId) => '$feedback/$feedbackId/permanent';
  // ================== FEEDBACK - DELETED/UNDO (NEW) ==================
  /// GET /api/feedback/deleted/list - Lấy danh sách feedback đã xóa
  static const String deletedFeedbackList = '$feedback/deleted/list';

  /// POST /api/feedback/{id}/restore - Hoàn tác feedback đã xóa
  static String restoreFeedback(String feedbackId) =>
      '$feedback/$feedbackId/restore';

  /// DELETE /api/feedback/{id}/permanent - Xóa vĩnh viễn feedback
  static String permanentDeleteFeedback(String feedbackId) =>
      '$feedback/$feedbackId/permanent';

  // ================== FEEDBACK - ADMIN UNDO (NEW) ==================
  /// GET /api/admin/feedback/deleted/list - Admin lấy danh sách feedback đã xóa
  static const String adminDeletedFeedbackList = '$adminFeedback/deleted/list';

  /// POST /api/admin/feedback/{id}/restore - Admin hoàn tác feedback
  static String adminRestoreFeedback(String feedbackId) =>
      '$adminFeedback/$feedbackId/restore';

  /// DELETE /api/admin/feedback/{id}/permanent - Admin xóa vĩnh viễn
  static String adminPermanentDeleteFeedback(String feedbackId) =>
      '$adminFeedback/$feedbackId/permanent';
  static String adminFeedbackFiltered({
    String? status,
    String? feedbackType,
    int page = 1,
    int limit = 20,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;
    if (feedbackType != null) params['feedbackType'] = feedbackType;
    final uri = Uri.parse(adminFeedback).replace(queryParameters: params);
    return uri.toString();
  }

  // ================== NOTIFICATIONS  ==================
  static const String notifications = '$baseUrl/notifications';

  static String notificationsList({int page = 1, int limit = 20}) {
    return '$notifications?page=$page&limit=$limit';
  }

  static String notificationDetail(String notificationId) =>
      '$notifications/$notificationId';

  static String markNotificationAsRead(String notificationId) =>
      '$notifications/$notificationId/read';

  static const String markAllNotificationsAsRead = '$notifications/read-all';

  static String deleteNotification(String notificationId) =>
      '$notifications/$notificationId';

  static const String deleteAllNotifications = notifications;

  static const String unreadNotificationCount = '$notifications/unread/count';

  static const String notificationStats = '$notifications/stats/overview';

  // Lấy danh sách thông báo đã xóa (Thùng rác)
  static const String deletedNotificationsList = '$notifications/deleted/list';

  // Hoàn tác xóa thông báo RIÊNG LẺ
  static String restoreNotification(String notificationId) =>
      '$notifications/$notificationId/restore';

  // Hoàn tác xóa tất cả thông báo
  static const String restoreAllNotifications = '$notifications/restore';

  //  Xóa vĩnh viễn thông báo khỏi undo stack
  static String permanentDeleteNotification(String notificationId) =>
      '$notifications/$notificationId/permanent';

// ================ ADMIN - QUẢN LÝ BÀI VIẾT =============
  static const String adminUsersWithPosts = '$baseUrl/admin/users-with-posts';
  static String adminUsersWithPostsPaginated({int page = 1, int limit = 20}) {
    return '$adminUsersWithPosts?page=$page&limit=$limit';
  }

  /// GET /api/admin/user-posts/{userId}?page=1&limit=10
  static String adminUserPosts(String userId, {int page = 1, int limit = 10}) {
    return '$baseUrl/admin/user-posts/$userId?page=$page&limit=$limit';
  }

  /// PATCH /api/admin/rentals/{rentalId} - Chỉnh sửa bài viết (Admin)
  static String adminEditRental(String rentalId) {
    return '$baseUrl/admin/rentals/$rentalId';
  }

  /// DELETE /api/admin/rentals/{rentalId} - Xóa bài viết (Admin)
  static String adminDeleteRental(String rentalId) {
    return '$baseUrl/admin/rentals/$rentalId';
  }

  // ==================== BANNER  ====================
  static const String banners = '$baseUrl/banners';
  static String bannerById(String bannerId) => '$banners/$bannerId';
  static const String adminBanners = '$banners/admin';
  // ==================== NEW ====================
  static const String news = '$baseUrl/news';
  static String newsById(String newsId) => '$news/$newsId';
  static const String featuredNews = '$news/featured';
  static const String adminNews = '$news/admin/all';

  // News Save/Unsave routes
  static String saveArticle(String newsId) => '$news/$newsId/save';
  static String unsaveArticle(String newsId) => '$news/$newsId/unsave';
  static String checkIsSaved(String newsId) => '$news/$newsId/is-saved';
  static const String savedArticles = '$news/user/saved-articles';

  // ==================== ADMIN USER MANAGEMENT ====================
  static const String adminUsers = '$baseUrl/auth/admin/users';

  // GET: Danh sách người dùng
  static String adminUserList({int? page, int? limit}) {
    final params = <String, String>{};
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();
    final uri = Uri.parse(adminUsers).replace(queryParameters: params);
    return uri.toString();
  }

  // GET: Chi tiết người dùng (không có ảnh)
  static String adminUserDetail(String userId) => '$adminUsers/$userId';

  // PUT: Cập nhật thông tin người dùng
  static String adminUserUpdate(String userId) => '$adminUsers/$userId';

  // DELETE: Xóa người dùng
  static String adminUserDelete(String userId) => '$adminUsers/$userId';

  // PUT: Cập nhật avatar (giữ nguyên như cũ - đã đúng)
  static String adminUserAvatarUpdate(String userId) =>
      '$adminUsers/$userId/avatar';

  // GET: LẤY RIÊNG ẢNH ĐẠI DIỆN (MỚI - BẮT BUỘC PHẢI CÓ)
  static String adminUserAvatar(String userId) => '$adminUsers/$userId/avatar';
  // Định nghĩa các endpoint dữ liệu cụ thể ------------------------------------------


  static const String rentals = '$baseUrl/rentals';
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String sendResetEmail = '$baseUrl/auth/send-reset-email';
  static const String resetPassword = '$baseUrl/auth/reset-password';
  static const String updateProfile = '$baseUrl/auth/update-profile';
  static const String users = '$baseUrl/auth/users';
  static const String favorites = '$baseUrl/favorites';

  // Các endpoint lấy thông tin đăng nhập người dùng
  static const String profile = '$baseUrl/auth/profile';
  static const String uploadImage = '$baseUrl/auth/upload-image';

  // Endpoint lấy dữ liệu ảnh tài khoản người dùng
  static const String avatar = '$baseUrl/auth/user';

  // Các endpoint bình luận cho bài viết
  static const String comments = '$baseUrl/comments';
  static String commentReplies(String commentId) =>
      '$comments/$commentId/replies';
  static String likeComment(String commentId) => '$comments/$commentId/like';
  static String unlikeComment(String commentId) =>
      '$comments/$commentId/unlike';
  static String getAvatar(String userId) => '$avatar/$userId/avatar';

  // Các endpoint cho phản hồi (replies) và phản hồi lồng nhau (nested replies)
  static String reply(String commentId, String replyId) =>
      '$comments/$commentId/replies/$replyId';
  static String likeReply(String commentId, String replyId) =>
      '$comments/$commentId/replies/$replyId/like';
  static String unlikeReply(String commentId, String replyId) =>
      '$comments/$commentId/replies/$replyId/unlike';
  static String deleteReply(String replyId) =>
      '$baseUrl/profile/reply/$replyId';

  // Chat Endpoints
  static const String conversations = '$baseUrl/conversations';
  static String conversationById(String conversationId) =>
      '$conversations/$conversationId';
  static const String pendingConversations = '$conversations/pending';
  static const String messages = '$baseUrl/messages';
  static String messagesByConversation(String conversationId) =>
      '$baseUrl/messages/$conversationId';

  // Booking Endpoints
  static const String bookings = '$baseUrl/bookings';
  static String myBookings = '$bookings/my-bookings';
  static String rentalBookings(String rentalId) => '$bookings/rental/$rentalId';
  static String bookingById(String bookingId) => '$bookings/$bookingId';
  static String updateBookingStatus(String bookingId) =>
      '$bookings/$bookingId/status';
  static String cancelBooking(String bookingId) =>
      '$bookings/$bookingId/cancel';

  // Cấu hình EmailJS
  static const String emailJsApi =
      'https://api.emailjs.com/api/v1.0/email/send';
  static const String emailJsServiceId = 'service_gz8v706';
  static const String emailJsTemplateId = 'template_1k09fcg';
  static const String emailJsUserId = 'bGlLdgP91zmfcVxzm';

  static const String myPosts = '$baseUrl/profile/my-posts';
  static const String recentComments = '$baseUrl/profile/recent-comments';

  // Gọi các API địa chỉ --------------------
  static const String baseUrlAddress = 'https://provinces.open-api.vn/api';
  static Uri get provinces => Uri.parse('$baseUrlAddress/p/');
  static Uri getDistricts(String provinceCode) =>
      Uri.parse('$baseUrlAddress/p/$provinceCode?depth=2');
  static Uri getWards(String districtCode) =>
      Uri.parse('$baseUrlAddress/d/$districtCode?depth=2');


  // ==================== ADMIN DASHBOARD ====================

  /// GET /api/admin/dashboard - Lấy thống kê tổng quan
  static const String adminDashboard = '$baseUrl/admin/dashboard';

  /// GET /api/admin/dashboard/revenue-chart?days=7
  static String adminDashboardRevenueChart({int days = 7}) {
    return '$baseUrl/admin/dashboard/revenue-chart?days=$days';
  }

  /// GET /api/admin/dashboard/property-types
  static const String adminDashboardPropertyTypes =
      '$baseUrl/admin/dashboard/property-types';

  /// GET /api/admin/dashboard/user-growth?months=6
  static String adminDashboardUserGrowth({int months = 6}) {
    return '$baseUrl/admin/dashboard/user-growth?months=$months';
  }

  /// GET /api/admin/dashboard/top-posts?limit=5
  static String adminDashboardTopPosts({int limit = 5}) {
    return '$baseUrl/admin/dashboard/top-posts?limit=$limit';
  }

  // ==================== RENTALS & AI SUGGEST ====================
  /// GET /api/rentals/ai-suggest?q=keyword
  static String aiSuggest({
    required String query,
    int? minPrice,
    int? maxPrice,
    String? propertyType,
    int limit = 5,
  }) {
    final params = <String, String>{
      'q': query,
      'limit': limit.toString(),
    };
    if (minPrice != null) params['minPrice'] = minPrice.toString();
    if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
    if (propertyType != null) params['propertyType'] = propertyType;

    final uri =
        Uri.parse('$rentals/ai-suggest').replace(queryParameters: params);
    return uri.toString();
  }

  /// GET /api/rentals/ai-suggest/advanced?q=query
  static String aiSuggestAdvanced({required String query}) {
    final params = <String, String>{'q': query};
    final uri = Uri.parse('$rentals/ai-suggest/advanced')
        .replace(queryParameters: params);
    return uri.toString();
  }

  /// GET /api/rentals/ai-suggest/trending?limit=5
  static String aiSuggestTrending({int limit = 5}) {
    final params = <String, String>{'limit': limit.toString()};
    final uri = Uri.parse('$rentals/ai-suggest/trending')
        .replace(queryParameters: params);
    return uri.toString();
  }
}
