class ApiRoutes {
  static const String rootUrl = 'http://192.168.1.128:3000';
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;
  static const String socketUrl = serverBaseUrl;

  // Định nghĩa các endpoint dữ liệu cụ thể ------------------------------------------
  static const String rentals = '$baseUrl/rentals';
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String changePassword = '$baseUrl/auth/change-password';
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
  static String commentReplies(String commentId) => '$comments/$commentId/replies';
  static String likeComment(String commentId) => '$comments/$commentId/like';
  static String unlikeComment(String commentId) => '$comments/$commentId/unlike';
  static String getAvatar(String userId) => '$avatar/$userId/avatar';


  // Các endpoint cho phản hồi (replies) và phản hồi lồng nhau (nested replies)
  static String reply(String commentId, String replyId) => '$comments/$commentId/replies/$replyId';
  static String likeReply(String commentId, String replyId) => '$comments/$commentId/replies/$replyId/like';
  static String unlikeReply(String commentId, String replyId) => '$comments/$commentId/replies/$replyId/unlike';

  // Chat Endpoints
  static const String conversations = '$baseUrl/conversations';
  static const String pendingConversations = '$conversations/pending';
  static String messages(String conversationId) => '$baseUrl/messages/$conversationId';
}
