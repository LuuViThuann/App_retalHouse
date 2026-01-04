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
  late Rental _currentRental;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
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
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(price)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // 🔝 MODERN HEADER
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFF2D3142), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: const Text(
              'Chi tiết bài đăng',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.5,
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(),
                      const SizedBox(height: 20),
                      _buildPriceSection(),
                      const SizedBox(height: 20),
                      _buildKeyInfoSection(),
                      const SizedBox(height: 20),
                      _buildLocationSection(),
                      const SizedBox(height: 20),
                      _buildPostedDateSection(),
                      const SizedBox(height: 20),

                      if (_currentRental.furniture.isNotEmpty ||
                          _currentRental.amenities.isNotEmpty)
                        _buildPropertyDetailsSection(),

                      if (_currentRental.surroundings.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSurroundingsSection(),
                      ],

                      if (_currentRental.rentalTerms != null) ...[
                        const SizedBox(height: 20),
                        _buildRentalTermsSection(),
                      ],

                      if (_currentRental.contactInfo != null) ...[
                        const SizedBox(height: 20),
                        _buildContactInfoSection(),
                      ],

                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 32),
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
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[200]!, Colors.grey[300]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Không có hình ảnh',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Image Carousel
        SizedBox(
          height: 320,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey[200]!, Colors.grey[300]!],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.broken_image,
                          size: 64, color: Colors.grey[400]),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Gradient Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Image Counter
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_currentImageIndex + 1}/${_currentRental.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Status Badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentRental.status == 'available'
                    ? [const Color(0xFF11998E), const Color(0xFF38EF7D)]
                    : [Colors.grey[600]!, Colors.grey[800]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_currentRental.status == 'available'
                      ? const Color(0xFF11998E)
                      : Colors.grey[600]!).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentRental.status == 'available'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentRental.status == 'available'
                      ? 'Còn trống'
                      : 'Đã thuê',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Image Indicators
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _currentRental.images.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentImageIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: index == _currentImageIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3142),
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text(
                'Đăng bởi: ${widget.userName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== PRICE SECTION ==========
  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Giá thuê / tháng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatPrice(_currentRental.price),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ========== KEY INFO SECTION ==========
  Widget _buildKeyInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              icon: Icons.straighten_outlined,
              label: 'Diện tích',
              value: '${_currentRental.area['total']?.toStringAsFixed(0) ?? '0'}m²',
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.home_outlined,
              label: 'Loại BĐS',
              value: _currentRental.propertyType ?? 'N/A',
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.bed_outlined,
              label: 'Phòng ngủ',
              value: '${_currentRental.area['bedrooms']?.toStringAsFixed(0) ?? '0'}',
              color: const Color(0xFFEC4899),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ========== LOCATION SECTION ==========
  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Địa chỉ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentRental.location['short'] ?? 'Chưa cập nhật',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                    height: 1.4,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ngày đăng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(_currentRental.createdAt),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.home_work_outlined,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Chi tiết tài sản',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_currentRental.furniture.isNotEmpty) ...[
            const Text(
              'Nội thất',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentRental.furniture.map((item) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.1),
                          const Color(0xFF8B5CF6).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],

          if (_currentRental.amenities.isNotEmpty) ...[
            const Text(
              'Tiện ích',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentRental.amenities.map((item) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withOpacity(0.1),
                          const Color(0xFF06B6D4).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ========== SURROUNDINGS SECTION ==========
  Widget _buildSurroundingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_city,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Xung quanh',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentRental.surroundings.map((item) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF59E0B).withOpacity(0.1),
                        const Color(0xFFEF4444).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ).toList(),
          ),
        ],
      ),
    );
  }

  // ========== RENTAL TERMS SECTION ==========
  Widget _buildRentalTermsSection() {
    final terms = _currentRental.rentalTerms;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Điều kiện thuê',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTermRow('Thời hạn tối thiểu', terms?['minimumLease'] ?? 'N/A', Icons.schedule),
          _buildTermRow('Tiền cọc', terms?['deposit'] ?? 'N/A', Icons.account_balance_wallet_outlined),
          _buildTermRow('Phương thức thanh toán', terms?['paymentMethod'] ?? 'N/A', Icons.payment),
          _buildTermRow('Điều kiện gia hạn', terms?['renewalTerms'] ?? 'N/A', Icons.autorenew, isLast: true),
        ],
      ),
    );
  }

  Widget _buildTermRow(String label, String value, IconData icon, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3142),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(color: Colors.grey[200], height: 1),
      ],
    );
  }

  // ========== CONTACT INFO SECTION ==========
  Widget _buildContactInfoSection() {
    final contact = _currentRental.contactInfo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF06B6D4).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.contact_phone,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thông tin liên hệ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactRow(
            Icons.person_outline,
            'Người liên hệ',
            contact?['name'] ?? 'Chủ nhà',
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            Icons.phone_outlined,
            'Số điện thoại',
            contact?['phone'] ?? 'Không có',
            isPhone: true,
          ),
          if (contact?['availableHours'] != null &&
              (contact!['availableHours'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildContactRow(
              Icons.access_time_outlined,
              'Thời gian liên hệ',
              contact['availableHours'],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, {bool isPhone = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF10B981)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isPhone ? const Color(0xFF10B981) : const Color(0xFF2D3142),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== ACTION BUTTONS ==========
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  label: const Text('Quay lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6B7280),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showEditDialog(),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Chỉnh sửa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteReasonDialog(),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Xóa bài đăng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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

          if (mounted && Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }

          await Future.delayed(const Duration(milliseconds: 300));

          if (mounted) {
            debugPrint('🔄 Fetching updated rental data from server...');
            final updatedRental = await context
                .read<AdminViewModel>()
                .fetchRentalForEdit(_currentRental.id);

            if (updatedRental != null && mounted) {
              setState(() {
                _currentRental = updatedRental;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Cập nhật thông tin thành công',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            } else {
              debugPrint('❌ Failed to fetch updated rental data');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Không thể lấy dữ liệu cập nhật',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFF59E0B),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }

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
        SnackBar(
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
              const SizedBox(width: 12),
              const Text(
                'Đang xóa bài viết...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: const Color(0xFF6B7280),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
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
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Xóa bài viết thành công',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
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
            content: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context
                        .read<AdminViewModel>()
                        .error ?? 'Xóa bài viết thất bại',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
  }