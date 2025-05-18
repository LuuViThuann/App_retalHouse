import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_favorite.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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