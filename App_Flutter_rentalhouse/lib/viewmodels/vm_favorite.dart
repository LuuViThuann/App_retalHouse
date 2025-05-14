import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_routes.dart'; // Đảm bảo import này đúng
import '../models/favorite.dart'; // Đảm bảo import này đúng (model Favorite của bạn)

class FavoriteViewModel with ChangeNotifier {
  List<Favorite> _favorites = [];
  // Sử dụng một Map để theo dõi trạng thái loading cho từng rentalId cụ thể
  // hoặc một String để theo dõi rentalId đang được xử lý.
  // Nếu bạn muốn loading chung cho cả list thì dùng bool _isLoadingList = false;
  Map<String, bool> _itemLoadingStates = {};
  bool _isListLoading = false; // Cho fetchFavorites và removeMultipleFavorites

  String? _errorMessage;

  List<Favorite> get favorites => _favorites;
  String? get errorMessage => _errorMessage;

  // Trạng thái loading cho một item cụ thể (dùng khi toggle/remove từng item)
  bool isLoading(String rentalId) => _itemLoadingStates[rentalId] ?? false;
  // Trạng thái loading cho cả danh sách (dùng khi fetch ban đầu hoặc xóa nhiều)
  bool get isListLoading => _isListLoading;


  FavoriteViewModel() {
    // Không nên gọi async trong constructor. Load từ initState của View hoặc một hàm khởi tạo riêng.
    // _loadFavoritesFromPrefs(); // Sẽ được gọi bởi View nếu cần thiết
  }

  void clearFavoritesLocally() {
    _favorites = [];
    _saveFavoritesToPrefs(); // Lưu danh sách rỗng
    notifyListeners();
  }


  Future<void> _loadFavoritesFromPrefs() async {
    // Hàm này có thể không cần thiết nếu bạn luôn fetch từ server khi có token
    // Hoặc dùng để hiển thị cache khi offline
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorites_cache'); // Sử dụng key khác để tránh nhầm lẫn
    if (favoritesJson != null) {
      try {
        final List<dynamic> data = jsonDecode(favoritesJson);
        _favorites = data.map((json) => Favorite.fromJson(json)).toList();
        // Không gọi notifyListeners() ở đây nếu hàm này chỉ dùng để khởi tạo nội bộ
      } catch (e) {
        print('Lỗi khi tải danh sách yêu thích từ bộ nhớ cache: $e');
        _favorites = []; // Đảm bảo danh sách rỗng nếu có lỗi
      }
    }
  }

  Future<void> _saveFavoritesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final favoritesJson = jsonEncode(_favorites.map((f) => f.toJson()).toList());
      await prefs.setString('favorites_cache', favoritesJson);
    } catch (e) {
      print('Lỗi khi lưu danh sách yêu thích vào bộ nhớ cache: $e');
    }
  }

  Future<void> fetchFavorites(String token) async {
    if (token.isEmpty) {
      _errorMessage = 'Không có token. Vui lòng đăng nhập.';
      _isListLoading = false;
      notifyListeners();
      return;
    }

    _isListLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.favorites), // Đảm bảo ApiRoutes.favorites đúng
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15)); // Thêm timeout

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Ánh xạ dữ liệu từ API của bạn. Giả sử API trả về danh sách các đối tượng Favorite đầy đủ
        // hoặc danh sách các đối tượng có chứa rentalId.
        // Ví dụ, nếu API trả về [{ "rentalId": { "_id": "someId", ... }, "userId": "userId" }]
        _favorites = data.map((json) {
          // Kiểm tra cấu trúc JSON trả về từ API của bạn
          if (json['rentalId'] is String) { // Nếu rentalId là String trực tiếp
            return Favorite.fromJson({
              'userId': json['userId'] as String? ?? '', // Cung cấp giá trị mặc định nếu null
              'rentalId': json['rentalId'] as String,
            });
          } else if (json['rentalId'] is Map && json['rentalId']['_id'] is String) { // Nếu rentalId là object có _id
            return Favorite.fromJson({
              'userId': json['userId'] as String? ?? '',
              'rentalId': json['rentalId']['_id'] as String,
            });
          }
          // Nếu cấu trúc không khớp, trả về null hoặc throw error, rồi filter out nulls
          return null;
        }).whereType<Favorite>().toList(); // Lọc bỏ các giá trị null nếu có

        await _saveFavoritesToPrefs(); // Lưu cache
        _errorMessage = null;
      } else {
        _errorMessage = 'Lỗi ${response.statusCode}: Không thể tải danh sách yêu thích.';
        print('Fetch favorites error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối hoặc timeout. Vui lòng thử lại.';
      print('Fetch favorites exception: $e');
    } finally {
      _isListLoading = false;
      notifyListeners();
    }
  }


  // Hàm này không còn cần thiết nếu removeFavorite chỉ xóa
  // Future<bool> toggleFavorite(String userId, String rentalId, String token) async {...}


  Future<bool> addFavorite(String userId, String rentalId, String token) async {
    // Hàm này dùng ở nơi khác, không phải màn hình FavoriteView
    if (isFavorite(rentalId)) {
      _errorMessage = 'Đã có trong danh sách yêu thích.';
      notifyListeners();
      return true; // Hoặc false nếu bạn coi đây là một "lỗi"
    }

    if (token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập.';
      notifyListeners();
      return false;
    }

    _itemLoadingStates[rentalId] = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiRoutes.favorites),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'rentalId': rentalId, 'userId': userId}), // Gửi cả userId nếu API cần
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) { // 201 Created, 200 OK
        // Giả sử API trả về đối tượng favorite mới hoặc xác nhận
        // Thêm vào danh sách local nếu API không trả về danh sách mới nhất
        _favorites.add(Favorite(userId: userId, rentalId: rentalId));
        await _saveFavoritesToPrefs();
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = 'Lỗi ${response.statusCode}: Không thể thêm vào yêu thích.';
        print('Add favorite error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối khi thêm yêu thích. Vui lòng thử lại.';
      print('Add favorite exception: $e');
      return false;
    } finally {
      _itemLoadingStates[rentalId] = false;
      notifyListeners();
    }
  }

  Future<bool> removeFavorite(String rentalId, String token) async {
    // Hàm này được gọi từ icon trái tim trong FavoriteView
    if (!isFavorite(rentalId)) {
      // _errorMessage = 'Không có trong danh sách yêu thích.'; // Không cần thông báo lỗi này ở đây
      // notifyListeners();
      return true; // Coi như đã thành công nếu nó không có sẵn để xóa
    }
    if (token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập.';
      notifyListeners();
      return false;
    }

    _itemLoadingStates[rentalId] = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiRoutes.favorites}/$rentalId'), // API endpoint để xóa một favorite
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) { // 200 OK, 204 No Content
        _favorites.removeWhere((favorite) => favorite.rentalId == rentalId);
        await _saveFavoritesToPrefs();
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = 'Lỗi ${response.statusCode}: Không thể xóa khỏi yêu thích.';
        print('Remove favorite error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối khi xóa yêu thích. Vui lòng thử lại.';
      print('Remove favorite exception: $e');
      return false;
    } finally {
      _itemLoadingStates.remove(rentalId); // Xóa trạng thái loading của item này
      // Hoặc _itemLoadingStates[rentalId] = false;
      notifyListeners();
    }
  }

  Future<bool> removeMultipleFavorites(List<String> rentalIds, String token) async {
    if (token.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập.';
      notifyListeners();
      return false;
    }
    if (rentalIds.isEmpty) return true;

    _isListLoading = true; // Sử dụng loading chung cho thao tác hàng loạt
    _errorMessage = null;
    notifyListeners();

    List<String> successfullyRemoved = [];
    String? firstError;

    // Có thể gọi API xóa hàng loạt nếu backend hỗ trợ
    // Hoặc lặp và xóa từng cái
    for (String rentalId in rentalIds) {
      _itemLoadingStates[rentalId] = true; // Đánh dấu từng item đang được xử lý
      notifyListeners(); // Cập nhật UI để có thể hiển thị loading cho từng item nếu muốn

      try {
        final response = await http.delete(
          Uri.parse('${ApiRoutes.favorites}/$rentalId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 204) {
          successfullyRemoved.add(rentalId);
        } else {
          if (firstError == null) {
            firstError = 'Lỗi ${response.statusCode} khi xóa ID $rentalId.';
          }
          print('Error removing $rentalId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (firstError == null) {
          firstError = 'Lỗi kết nối khi xóa ID $rentalId.';
        }
        print('Exception removing $rentalId: $e');
      } finally {
        _itemLoadingStates.remove(rentalId);
        // Không gọi notifyListeners() trong vòng lặp để tránh quá nhiều rebuild,
        // trừ khi bạn muốn cập nhật UI cho từng item riêng lẻ khi nó hoàn thành.
      }
    }

    _favorites.removeWhere((fav) => successfullyRemoved.contains(fav.rentalId));
    await _saveFavoritesToPrefs();

    if (firstError != null && successfullyRemoved.length < rentalIds.length) {
      _errorMessage = 'Một số mục không xóa được. $firstError';
    } else if (successfullyRemoved.isEmpty && rentalIds.isNotEmpty) {
      _errorMessage = 'Không thể xóa các mục đã chọn. $firstError';
    }
    else {
      _errorMessage = null; // Xóa lỗi nếu tất cả thành công
    }

    _isListLoading = false;
    notifyListeners(); // Gọi một lần sau khi tất cả hoàn tất
    return firstError == null;
  }

  bool isFavorite(String rentalId) {
    return _favorites.any((favorite) => favorite.rentalId == rentalId);
  }
}