class ApiRoutes {
  static const String rootUrl = 'http://192.168.1.54:3000';
  static const String baseUrl = '$rootUrl/api';
  static const String serverBaseUrl = rootUrl;

  // Định nghĩa các endpoint dữ liệu cụ thể ------------------------------------------
  static const String rentals = '$baseUrl/rentals';
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String users = '$baseUrl/auth/users';
  static const String favorites = '$baseUrl/favorites';
}