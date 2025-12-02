import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/models/rental.dart';
import 'package:flutter_rentalhouse/views/Admin/ViewModel/admin_viewmodel.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/DeleteReasonDialog.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/UserDetail/EditRentalDialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class UserPostDetailScreen extends StatefulWidget {
  final Rental post;
  final String userName;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostUpdated;

  const UserPostDetailScreen({
    super.key,
    required this.post,
    required this.userName,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  State<UserPostDetailScreen> createState() => _UserPostDetailScreenState();
}

class _UserPostDetailScreenState extends State<UserPostDetailScreen> {
  late PageController _imageController;
  int _currentImageIndex = 0;

  //  STATE: Lưu trữ rental hiện tại (có thể được cập nhật)
  late Rental _currentRental;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    //  Khởi tạo _currentRental từ widget.post
    _currentRental = widget.post;
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M đ';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K đ';
    }
    return '${price.toStringAsFixed(0)} đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 🔝 HEADER
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Chi tiết bài đăng',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),

          // 📋 CONTENT
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 🖼️ Image Gallery
                _buildImageGallery(),

                // 📄 Post Information
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Status
                      _buildTitleSection(),
                      const SizedBox(height: 16),

                      // Price Section
                      _buildPriceSection(),
                      const SizedBox(height: 16),

                      // Key Information
                      _buildKeyInfoSection(),
                      const SizedBox(height: 16),

                      // Location Section
                      _buildLocationSection(),
                      const SizedBox(height: 16),

                      // Posted Date
                      _buildPostedDateSection(),
                      const SizedBox(height: 16),

                      // Property Details
                      if (_currentRental.furniture.isNotEmpty ||
                          _currentRental.amenities.isNotEmpty)
                        _buildPropertyDetailsSection(),

                      if (_currentRental.surroundings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSurroundingsSection(),
                      ],

                      if (_currentRental.rentalTerms != null) ...[
                        const SizedBox(height: 16),
                        _buildRentalTermsSection(),
                      ],

                      // Contact Info
                      if (_currentRental.contactInfo != null) ...[
                        const SizedBox(height: 16),
                        _buildContactInfoSection(),
                      ],

                      const SizedBox(height: 16),

                      // Action Buttons
                      _buildActionButtons(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== IMAGE GALLERY ==========
  Widget _buildImageGallery() {
    if (_currentRental.images.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Image Carousel
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _imageController,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemCount: _currentRental.images.length,
            itemBuilder: (context, index) {
              final imageUrl = _currentRental.images[index].contains('http')
                  ? _currentRental.images[index]
                  : '${ApiRoutes.rootUrl}${_currentRental.images[index]}';

              return Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Image Counter
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${_currentRental.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Status Badge
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _currentRental.status == 'available'
                  ? Colors.green
                  : Colors.grey[700],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentRental.status == 'available'
                  ? '✓ Còn trống'
                  : '✗ Đã thuê',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Image Indicators
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _currentRental.images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentImageIndex
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== TITLE SECTION ==========
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentRental.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đăng bởi: ${widget.userName}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ========== PRICE SECTION ==========
  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Giá thuê:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatPrice(_currentRental.price),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ========== KEY INFO SECTION ==========
  Widget _buildKeyInfoSection() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: '📐',
            label: 'Diện tích',
            value:
                '${_currentRental.area['total']?.toStringAsFixed(0) ?? '0'}m²',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: '🏠',
            label: 'Loại BĐS',
            value: _currentRental.propertyType ?? 'N/A',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: '🛏️',
            label: 'Phòng ngủ',
            value:
                '${_currentRental.area['bedrooms']?.toStringAsFixed(0) ?? '0'}',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ========== LOCATION SECTION ==========
  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber[100]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Địa chỉ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentRental.location['short'] ?? 'Chưa cập nhật',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== POSTED DATE SECTION ==========
  Widget _buildPostedDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple[100]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.purple[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngày đăng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(_currentRental.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== PROPERTY DETAILS SECTION ==========
  Widget _buildPropertyDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏠 Chi tiết tài sản',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_currentRental.furniture.isNotEmpty) ...[
          const Text(
            'Nội thất:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentRental.furniture
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.blue[100],
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (_currentRental.amenities.isNotEmpty) ...[
          const Text(
            'Tiện ích:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentRental.amenities
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.green[100],
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ========== SURROUNDINGS SECTION ==========
  Widget _buildSurroundingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🌆 Xung quanh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _currentRental.surroundings
              .map(
                (item) => Chip(
                  label: Text(item),
                  backgroundColor: Colors.orange[100],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ========== RENTAL TERMS SECTION ==========
  Widget _buildRentalTermsSection() {
    final terms = _currentRental.rentalTerms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📋 Điều kiện thuê',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildTermRow('Thời hạn tối thiểu:', terms?['minimumLease'] ?? 'N/A'),
        _buildTermRow('Tiền cọc:', terms?['deposit'] ?? 'N/A'),
        _buildTermRow(
            'Phương thức thanh toán:', terms?['paymentMethod'] ?? 'N/A'),
        _buildTermRow('Điều kiện gia hạn:', terms?['renewalTerms'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== CONTACT INFO SECTION ==========
  Widget _buildContactInfoSection() {
    final contact = _currentRental.contactInfo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📞 Thông tin liên hệ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                contact?['name'] ?? 'Chủ nhà',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 20, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                contact?['phone'] ?? 'Không có',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (contact?['availableHours'] != null &&
              (contact!['availableHours'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact['availableHours'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ========== ACTION BUTTONS ==========
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Quay lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showEditDialog(),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Chỉnh sửa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteReasonDialog(),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Xóa bài đăng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== SHOW EDIT DIALOG ==========
  void _showEditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EditRentalDialogComplete(
        rental: _currentRental,
        onEditSuccess: () async {
          debugPrint('✅ Edit dialog: Edit successful');

          // Đóng dialog
          if (mounted && Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }

          //  Chờ một chút để dialog đóng hoàn toàn
          await Future.delayed(const Duration(milliseconds: 300));

          //  Lấy dữ liệu mới từ server
          if (mounted) {
            debugPrint(' Fetching updated rental data from server...');
            final updatedRental = await context
                .read<AdminViewModel>()
                .fetchRentalForEdit(_currentRental.id);

            if (updatedRental != null && mounted) {
              setState(() {
                _currentRental = updatedRental;
              });

              //  Hiển thị snackbar thành công
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ Cập nhật thông tin thành công'),
                  backgroundColor: Colors.green[600],
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            } else {
              debugPrint('❌ Failed to fetch updated rental data');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('⚠️ Không thể lấy dữ liệu cập nhật'),
                  backgroundColor: Colors.orange[600],
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }

          // ✅ Gọi callback để cập nhật danh sách cha
          widget.onPostUpdated?.call();
        },
      ),
    );
  }

  // ========== SHOW DELETE REASON DIALOG ==========
  void _showDeleteReasonDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteReasonDialog(
        postTitle: _currentRental.title,
        postAddress: _currentRental.location['short'] ?? 'N/A',
        postPrice: _currentRental.price,
        onConfirmDelete: () {
          _performDelete();
        },
      ),
    );
  }

  // ========== PERFORM DELETE ==========
  Future<void> _performDelete() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Đang xóa bài viết...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    final success =
        await context.read<AdminViewModel>().deleteUserPost(_currentRental.id);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Xóa bài viết thành công'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        debugPrint('✅ Delete successful, calling onPostDeleted callback');
        widget.onPostDeleted?.call();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AdminViewModel>().error ?? '❌ Xóa bài viết thất bại',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}
