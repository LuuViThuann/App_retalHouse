import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';

class AISuggestService {

  static Future<List<Rental>> getSuggestions({
    required String query,
    int? minPrice,
    int? maxPrice,
    String? propertyType,
    int limit = 5,
  }) async {
    try {
      if (query.trim().length < 3) {
        print('❌ Query quá ngắn: "${query}" (${query.length} ký tự)');
        return [];
      }

      final url = ApiRoutes.aiSuggest(
        query: query.trim(),
        minPrice: minPrice,
        maxPrice: maxPrice,
        propertyType: propertyType,
        limit: limit,
      );

      print('🔗 API URL: $url');
      print('📝 Query: "${query.trim()}"');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Request timeout');
          throw Exception('Request timeout');
        },
      );

      print('📊 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        print('✅ Parse thành công');
        print('📈 Success: ${data['success']}');
        print('🔢 Count: ${data['count']}');

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> rentalList = data['data'];
          print('✅ Tìm được ${rentalList.length} kết quả');

          return rentalList
              .map((item) {
            try {
              return Rental.fromJson(item);
            } catch (e) {
              print('⚠️ Error parsing rental: $e');
              return null;
            }
          })
              .whereType<Rental>()
              .toList();
        }
        print('⚠️ Data rỗng hoặc success = false');
        return [];
      } else {
        print('❌ Status code: ${response.statusCode}');
        throw Exception('Failed to load suggestions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  /// Gợi ý nâng cao với parsing thông minh từ câu hỏi tự nhiên
  ///
  /// Ví dụ:
  /// - "tìm phòng trọ giá rẻ dưới 3 triệu ở cần thơ"
  /// - "căn hộ 2 phòng ngủ có wifi"
  /// - "nhà từ 10 đến 20 triệu, diện tích 50m2"
  ///
  /// Returns: List<Rental>
  static Future<List<Rental>> getAdvancedSuggestions({
    required String query,
  }) async {
    try {
      if (query.trim().length < 3) {
        print('❌ Query quá ngắn: "${query}"');
        return [];
      }

      final url = ApiRoutes.aiSuggestAdvanced(query: query.trim());

      print('🔗 Advanced API URL: $url');
      print('📝 Query: "${query.trim()}"');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Advanced request timeout');
          throw Exception('Request timeout');
        },
      );

      print('📊 Advanced Response Status: ${response.statusCode}');
      print('📄 Advanced Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> rentalList = data['data'];
          print('✅ Advanced: Tìm được ${rentalList.length} kết quả');

          return rentalList
              .map((item) {
            try {
              return Rental.fromJson(item);
            } catch (e) {
              print('⚠️ Error parsing rental: $e');
              return null;
            }
          })
              .whereType<Rental>()
              .toList();
        }
        return [];
      } else {
        throw Exception('Failed to load advanced suggestions');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  /// Lấy các bài đăng trending/phổ biến
  ///
  /// Parameters:
  ///   - limit: số lượng kết quả (tùy chọn, mặc định 5, tối đa 10)
  ///
  /// Returns: List<Rental>
  static Future<List<Rental>> getTrendingRentals({int limit = 5}) async {
    try {
      final url = ApiRoutes.aiSuggestTrending(limit: limit);

      print('🔗 Trending API URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Trending request timeout');
          throw Exception('Request timeout');
        },
      );

      print('📊 Trending Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> rentalList = data['data'];
          print('✅ Trending: Tìm được ${rentalList.length} kết quả');

          return rentalList
              .map((item) {
            try {
              return Rental.fromJson(item);
            } catch (e) {
              print('⚠️ Error parsing rental: $e');
              return null;
            }
          })
              .whereType<Rental>()
              .toList();
        }
        return [];
      } else {
        throw Exception('Failed to load trending rentals');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }
}