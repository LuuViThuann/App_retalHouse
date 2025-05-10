import 'dart:convert';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/rental.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();

  Future<List<Rental>> getRentals() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('No token found');
    final response = await http.get(
      Uri.parse(ApiRoutes.rentals), // Sử dụng ApiRoutes.rentals
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load rentals: ${response.body}');
    }
  }

  Future<void> createRental(Rental rental, List<String> imagePaths) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('No token found');
    var request = http.MultipartRequest('POST', Uri.parse(ApiRoutes.rentals));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = rental.title;
    request.fields['description'] = rental.description;
    request.fields['price'] = rental.price.toString();
    request.fields['location'] = rental.location;
    request.fields['userId'] = rental.userId;

    for (var imagePath in imagePaths) {
      request.files.add(await http.MultipartFile.fromPath(
        'images',
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final response = await request.send();
    if (response.statusCode != 201) {
      throw Exception('Failed to create rental: ${await response.stream.bytesToString()}');
    }
  }
}