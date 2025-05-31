import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/rental.dart';
import '../config/api_routes.dart';

class ApiService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<List<Rental>> getRentals() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    print('Get rentals headers: $headers');
    final response = await http.get(
      Uri.parse(ApiRoutes.rentals),
      headers: headers,
    );
    print(
        'Get rentals response: status=${response.statusCode}, body=${response.body}');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Không thể tải danh sách bài đăng: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> searchRentals({
    String? search,
    double? minPrice,
    double? maxPrice,
    List<String>? propertyTypes,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (minPrice != null) queryParameters['minPrice'] = minPrice.toString();
    if (maxPrice != null) queryParameters['maxPrice'] = maxPrice.toString();
    if (propertyTypes != null && propertyTypes.isNotEmpty) {
      queryParameters['propertyType'] = propertyTypes.join(',');
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;

    final uri = Uri.parse('${ApiRoutes.rentals}/search')
        .replace(queryParameters: queryParameters);
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    print('Search rentals headers: $headers');
    final response = await http.get(uri, headers: headers);
    print(
        'Search rentals response: status=${response.statusCode}, body=${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('rentals')) {
        return {
          'rentals': (data['rentals'] as List)
              .map((json) => Rental.fromJson(json))
              .toList(),
          'total': data['total'] as int,
          'page': data['page'] as int,
          'pages': data['pages'] as int,
        };
      } else {
        throw Exception('Unexpected response format: ${response.body}');
      }
    } else {
      throw Exception('Không thể tải danh sách bài đăng: ${response.body}');
    }
  }

  Future<List<String>> getSearchHistory() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    print('Search history headers: $headers');
    final response = await http.get(
      Uri.parse('${ApiRoutes.baseUrl}/search-history'),
      headers: headers,
    );
    print(
        'Search history response: status=${response.statusCode}, body=${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Không thể tải lịch sử tìm kiếm: ${response.body}');
    }
  }

  Future<void> createRental(Rental rental, List<String> imagePaths) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }
    var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.rentals));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    print('Create rental headers: ${request.headers}');

    request.fields['title'] = rental.title;
    request.fields['price'] = rental.price.toString();
    request.fields['areaTotal'] = rental.area['total'].toString();
    request.fields['areaLivingRoom'] = rental.area['livingRoom'].toString();
    request.fields['areaBedrooms'] = rental.area['bedrooms'].toString();
    request.fields['areaBathrooms'] = rental.area['bathrooms'].toString();
    request.fields['locationShort'] = rental.location['short'];
    request.fields['locationFullAddress'] = rental.location['fullAddress'];
    request.fields['propertyType'] = rental.propertyType;
    request.fields['furniture'] = rental.furniture.join(',');
    request.fields['amenities'] = rental.amenities.join(',');
    request.fields['surroundings'] = rental.surroundings.join(',');
    request.fields['rentalTermsMinimumLease'] =
        rental.rentalTerms['minimumLease'];
    request.fields['rentalTermsDeposit'] =
        rental.rentalTerms['deposit'].toString();
    request.fields['rentalTermsPaymentMethod'] =
        rental.rentalTerms['paymentMethod'];
    request.fields['rentalTermsRenewalTerms'] =
        rental.rentalTerms['renewalTerms'];
    request.fields['contactInfoName'] = rental.contactInfo['name'];
    request.fields['contactInfoPhone'] = rental.contactInfo['phone'];
    request.fields['contactInfoAvailableHours'] =
        rental.contactInfo['availableHours'];
    request.fields['status'] = rental.status;

    for (var imagePath in imagePaths) {
      try {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ));
      } catch (e) {
        throw Exception('Không thể tải ảnh: $e');
      }
    }

    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);

    print(
        'Create rental response: status=${response.statusCode}, body=${responseBody.body}');

    if (response.statusCode != 201) {
      throw Exception('Không thể tạo bài đăng: ${responseBody.body}');
    }
  }
}
