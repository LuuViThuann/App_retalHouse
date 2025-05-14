import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/api_routes.dart';
import 'rental_detail_view.dart'; // Import RentalDetailScreen

class FavoriteView extends StatefulWidget {
  const FavoriteView({super.key});

  @override
  _FavoriteViewState createState() => _FavoriteViewState();
}

class _FavoriteViewState extends State<FavoriteView> {
  final Set<String> _selectedFavorites = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.currentUser != null &&
          authViewModel.currentUser!.token != null &&
          authViewModel.currentUser!.token!.isNotEmpty) {
        Provider.of<FavoriteViewModel>(context, listen: false)
            .fetchFavorites(authViewModel.currentUser!.token!);
      } else {
        Provider.of<FavoriteViewModel>(context, listen: false).clearFavoritesLocally();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Danh Sách Yêu Thích',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
        actions: [
          if (_selectedFavorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
              child: TextButton.icon(
                icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 20),
                label: Text(
                  'Xóa (${_selectedFavorites.length})',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 13),
                ),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                onPressed: () async {
                  if (authViewModel.currentUser == null ||
                      authViewModel.currentUser!.token == null ||
                      authViewModel.currentUser!.token!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Vui lòng đăng nhập để thực hiện thao tác này')));
                    return;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xác nhận xóa'),
                      content: Text(
                          'Bạn có chắc muốn xóa ${_selectedFavorites.length} mục yêu thích đã chọn?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Xóa',
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await favoriteViewModel
                        .removeMultipleFavorites(_selectedFavorites.toList(),
                        authViewModel.currentUser!.token!);
                    if (success) {
                      setState(() => _selectedFavorites.clear());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Đã xóa các mục yêu thích!'),
                            backgroundColor: Colors.green));
                      }
                    } else {
                      if (mounted){
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(favoriteViewModel.errorMessage ??
                                'Lỗi không xác định khi xóa'),
                            backgroundColor: Colors.redAccent));
                      }
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: _buildBody(favoriteViewModel, authViewModel),
    );
  }

  Widget _buildBody(FavoriteViewModel favoriteViewModel, AuthViewModel authViewModel) {
    if (authViewModel.currentUser == null || authViewModel.currentUser!.token == null || authViewModel.currentUser!.token!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('Vui lòng đăng nhập', style: TextStyle(fontSize: 17, color: Colors.grey)),
            Text('Để xem danh sách yêu thích của bạn.', style: TextStyle(fontSize: 15, color: Colors.grey)),
          ],
        ),
      );
    }

    if (favoriteViewModel.isLoading("")) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favoriteViewModel.errorMessage != null && favoriteViewModel.favorites.isEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                'Lỗi: ${favoriteViewModel.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          ));
    }

    if (favoriteViewModel.favorites.isEmpty) {
      return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border_outlined,
                  size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('Danh sách yêu thích trống',
                  style: TextStyle(fontSize: 17, color: Colors.grey)),
              Text('Hãy khám phá và thêm nhà/phòng bạn thích nhé.',
                style: TextStyle(fontSize: 15, color: Colors.grey), textAlign: TextAlign.center,),
            ],
          ));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      itemCount: favoriteViewModel.favorites.length,
      itemBuilder: (context, index) {
        final favorite = favoriteViewModel.favorites[index];
        return KeyedSubtree(
          key: ValueKey(favorite.rentalId),
          child: FutureBuilder<Rental?>(
            future: _fetchRental(favorite.rentalId, authViewModel.currentUser?.token),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _RentalItemShimmer();
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!))
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[300], size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Không tải được thông tin',
                                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                            Text('ID: ${favorite.rentalId}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final rental = snapshot.data!;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RentalDetailScreen(rental: rental),
                    ),
                  );
                },
                child: RentalFavoriteWidget(
                  key: ValueKey(rental.id),
                  rental: rental,
                  showCheckbox: _selectedFavorites.isNotEmpty,
                  isSelected: _selectedFavorites.contains(rental.id),
                  onSelectChanged: (isSelected) {
                    setState(() {
                      if (rental.id != null) {
                        if (isSelected) {
                          _selectedFavorites.add(rental.id!);
                        } else {
                          _selectedFavorites.remove(rental.id!);
                        }
                      }
                    });
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<Rental?> _fetchRental(String rentalId, String? token) async {
    if (token == null || token.isEmpty) {
      print('Fetch rental $rentalId failed: No token provided.');
      return null;
    }
    try {
      final response = await http.get(
          Uri.parse('${ApiRoutes.baseUrl}/rentals/$rentalId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          });
      if (response.statusCode == 200) {
        return Rental.fromJson(jsonDecode(response.body));
      } else {
        print(
            'Error fetching rental $rentalId: Status ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception fetching rental $rentalId: $e');
      return null;
    }
  }
}

class RentalFavoriteWidget extends StatefulWidget {
  final Rental rental;
  final bool showCheckbox;
  final bool isSelected;
  final Function(bool) onSelectChanged;

  const RentalFavoriteWidget({
    super.key,
    required this.rental,
    required this.showCheckbox,
    required this.isSelected,
    required this.onSelectChanged,
  });

  @override
  _RentalFavoriteWidgetState createState() => _RentalFavoriteWidgetState();
}

class _RentalFavoriteWidgetState extends State<RentalFavoriteWidget> {
  Future<void> _handleToggleFavorite(String token) async {
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context, listen: false);
    final success = await favoriteViewModel.removeFavorite(widget.rental.id!, token);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xóa khỏi danh sách yêu thích'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(favoriteViewModel.errorMessage ?? 'Không thể xóa khỏi yêu thích'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final favoriteViewModel = Provider.of<FavoriteViewModel>(context, listen: false);

    final priceVND = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(widget.rental.price);
    final location = widget.rental.location['short']?.isNotEmpty == true ? widget.rental.location['short'] : 'Không rõ vị trí';
    final statusText = widget.rental.status == 'available' ? 'Đang cho thuê' : 'Đã cho thuê';
    final propertyType = widget.rental.propertyType?.isNotEmpty == true ? widget.rental.propertyType : 'Chưa rõ loại';

    bool isLoadingThisItem = favoriteViewModel.isLoading(widget.rental.id!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              '${ApiRoutes.baseUrl.replaceAll('/api', '')}${widget.rental.images.firstOrNull ?? ''}',
              width: 120,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 130,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 30),
                );
              },
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 120,
                  height: 130,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: [
                    Chip(
                      label: Text(propertyType!, style: TextStyle(fontSize: 10, color: Colors.blueGrey[700], fontWeight: FontWeight.w500)),
                      backgroundColor: Colors.blueGrey[50],
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: widget.rental.status == 'available' ? Colors.green[700] : Colors.orange[800],
                        ),
                      ),
                      backgroundColor: widget.rental.status == 'available' ? Colors.green[50] : Colors.orange[50],
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  widget.rental.title ?? 'Chưa có tiêu đề',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Giá: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        Text(
                          priceVND,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColorDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Xem chi tiết', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              isLoadingThisItem
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.grey),
                  ))
                  : InkWell(
                onTap: () {
                  if (authViewModel.currentUser != null &&
                      authViewModel.currentUser!.token != null &&
                      authViewModel.currentUser!.token!.isNotEmpty &&
                      !isLoadingThisItem) {
                    _handleToggleFavorite(authViewModel.currentUser!.token!);
                  } else if (!isLoadingThisItem) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng đăng nhập để bỏ yêu thích')));
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red[400],
                    size: 22,
                  ),
                ),
              ),
              if (widget.showCheckbox)
                SizedBox(
                  height: 30,
                  width: 30,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (value) {
                      widget.onSelectChanged(value ?? false);
                    },
                    activeColor: Theme.of(context).primaryColor,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                const SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class _RentalItemShimmer extends StatelessWidget {
  const _RentalItemShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 60, height: 12, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 4),
                Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(width: 30, height: 16, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 5),
                    Container(width: 90, height: 16, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}