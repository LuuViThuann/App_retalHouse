class ApiRoutes {
  static const String rootUrl = 'http://192.168.1.72:3000';
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;

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
}