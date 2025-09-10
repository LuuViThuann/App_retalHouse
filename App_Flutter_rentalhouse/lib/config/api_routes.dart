class ApiRoutes {
  static const String rootUrl =
      'http://192.168.1.156:3000'; // 192.168.43.168 - mạng dữ liệu
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;
  static const String socketUrl = serverBaseUrl;

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
