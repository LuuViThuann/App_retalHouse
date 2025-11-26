class ApiRoutes {
  static const String rootUrl =
      'http://192.168.1.153:3000'; // 192.168.43.168 - mạng dữ liệu
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;
  static const String socketUrl = serverBaseUrl;

// ================ ADMIN - QUẢN LÝ BÀI VIẾT =============
  static const String adminUsersWithPosts = '$baseUrl/admin/users-with-posts';
  static String adminUsersWithPostsPaginated({int page = 1, int limit = 20}) {
    return '$adminUsersWithPosts?page=$page&limit=$limit';
  }

  /// GET /api/admin/user-posts/{userId}?page=1&limit=10
  static String adminUserPosts(String userId, {int page = 1, int limit = 10}) {
    return '$baseUrl/admin/user-posts/$userId?page=$page&limit=$limit';
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
  static const String searchHistory = '$baseUrl/search-history';

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
  static const String notifications = '$baseUrl/profile/notifications';

  // Gọi các API địa chỉ --------------------
  static const String baseUrlAddress = 'https://provinces.open-api.vn/api';
  static Uri get provinces => Uri.parse('$baseUrlAddress/p/');
  static Uri getDistricts(String provinceCode) =>
      Uri.parse('$baseUrlAddress/p/$provinceCode?depth=2');
  static Uri getWards(String districtCode) =>
      Uri.parse('$baseUrlAddress/d/$districtCode?depth=2');
}
