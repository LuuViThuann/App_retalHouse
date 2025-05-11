class ApiRoutes {
  static const String baseUrl = 'http://192.168.1.218:3000/api';

  // Định nghĩa các endpoint dữ liệu cụ thể ------------------------------------------
  static const String rentals = '$baseUrl/rentals';
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String users = '$baseUrl/auth/users';
}