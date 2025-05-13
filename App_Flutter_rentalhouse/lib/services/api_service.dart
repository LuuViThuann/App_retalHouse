import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/rental.dart';
import '../config/api_routes.dart';

class ApiService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Lấy ID token từ Firebase Authentication
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  // Lấy danh sách bài đăng
  Future<List<Rental>> getRentals() async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    final response = await http.get(
      Uri.parse(ApiRoutes.rentals),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Không thể tải danh sách bài đăng: ${response.body}');
    }
  }

  // Tạo bài đăng mới
  Future<void> createRental(Rental rental, List<String> imagePaths) async {
    final token = await _getIdToken();
    if (token == null) throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.rentals));
    request.headers['Authorization'] = 'Bearer $token';

    // Thêm các trường dữ liệu từ Rental
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
    request.fields['rentalTermsMinimumLease'] = rental.rentalTerms['minimumLease'];
    request.fields['rentalTermsDeposit'] = rental.rentalTerms['deposit'];
    request.fields['rentalTermsPaymentMethod'] = rental.rentalTerms['paymentMethod'];
    request.fields['rentalTermsRenewalTerms'] = rental.rentalTerms['renewalTerms'];
    request.fields['contactInfoName'] = rental.contactInfo['name'];
    request.fields['contactInfoPhone'] = rental.contactInfo['phone'];
    request.fields['contactInfoAvailableHours'] = rental.contactInfo['availableHours'];
    request.fields['status'] = rental.status;

    // Thêm các file ảnh
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
    if (response.statusCode != 201) {
      final errorMessage = await response.stream.bytesToString();
      throw Exception('Không thể tạo bài đăng: $errorMessage');
    }
  }
}