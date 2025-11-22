import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/api_routes.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/banner.dart';
import 'package:flutter_rentalhouse/views/Admin/Widget/Banner/EditBanner.dart';
import 'package:flutter_rentalhouse/views/Admin/model/banner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final BannerService _bannerService = BannerService();
  final ImagePicker _imagePicker = ImagePicker();
  List<BannerModel> banners = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() => isLoading = true);
    try {
      final token =
          Provider.of<AuthViewModel>(context, listen: false).currentUser?.token;
      if (token != null) {
        final fetchedBanners = await _bannerService.fetchAllBanners(token);
        setState(() => banners = fetchedBanners);
      }
    } catch (e) {
      _showSnackBar('Lỗi tải banner: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa banner'),
        content: const Text('Bạn có chắc chắn muốn xóa banner này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        final token = Provider.of<AuthViewModel>(context, listen: false)
            .currentUser
            ?.token;
        if (token != null) {
          await _bannerService.deleteBanner(bannerId, token);
          _showSnackBar('Xóa banner thành công');
          await _fetchBanners();
        }
      } catch (e) {
        _showSnackBar('Lỗi xóa banner: $e', isError: true);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quản lý Banner Quảng cáo'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: isLoading && banners.isEmpty
          ? _buildShimmerLoading()
          : banners.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchBanners,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 16,
                      childAspectRatio: 16 / 9,
                    ),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return _buildBannerCard(banner);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddBannerScreen(
                onBannerAdded: () => _fetchBanners(),
              ),
            ),
          );
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBannerCard(BannerModel banner) {
    // Tạo full URL cho ảnh
    final imageUrl = banner.imageUrl.startsWith('http')
        ? banner.imageUrl
        : '${ApiRoutes.serverBaseUrl}${banner.imageUrl}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'Lỗi tải ảnh\nURL: $imageUrl',
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: banner.isActive
                        ? Colors.green.withOpacity(0.9)
                        : Colors.grey.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        banner.isActive ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        banner.isActive ? 'Hoạt động' : 'Tắt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          const Text('Chỉnh sửa'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditBannerScreen(
                                banner: banner,
                                onBannerUpdated: () => _fetchBanners(),
                              ),
                            ),
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          const SizedBox(width: 12),
                          const Text('Xóa'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _deleteBanner(banner.id);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.image_not_supported,
                size: 50, color: Colors.blue[700]),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có banner nào',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm banner đầu tiên để bắt đầu quảng cáo',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ==================== ADD BANNER SCREEN ====================
class AddBannerScreen extends StatefulWidget {
  final VoidCallback onBannerAdded;

  const AddBannerScreen({required this.onBannerAdded, super.key});

  @override
  State<AddBannerScreen> createState() => _AddBannerScreenState();
}

class _AddBannerScreenState extends State<AddBannerScreen> {
  final BannerService _bannerService = BannerService();
  final ImagePicker _imagePicker = ImagePicker();

  File? selectedImage;
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final linkController = TextEditingController();
  final positionController = TextEditingController(text: '0');
  bool isLoading = false;

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar('Lỗi chọn ảnh: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _createBanner() async {
    if (selectedImage == null) {
      _showSnackBar('Vui lòng chọn ảnh banner', isError: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      final token =
          Provider.of<AuthViewModel>(context, listen: false).currentUser?.token;
      if (token != null) {
        await _bannerService.createBanner(
          title: titleController.text,
          description: descController.text,
          link: linkController.text,
          position: int.tryParse(positionController.text) ?? 0,
          imageFile: selectedImage!,
          token: token,
        );
        _showSnackBar('Thêm banner thành công');
        widget.onBannerAdded();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Lỗi tạo banner: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    linkController.dispose();
    positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thêm Banner Mới'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image Picker Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue[300]!,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                    color: Colors.blue[50],
                  ),
                  child: selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.cloud_upload_outlined,
                                  size: 40, color: Colors.blue[800]),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chọn ảnh banner',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nhấn để chọn ảnh từ thư viện',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '(JPEG, PNG, WebP - Tối đa 5MB)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedImage = null),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // Title Field
              _buildTextField(
                controller: titleController,
                label: 'Tiêu đề',
                hint: 'Nhập tiêu đề banner',
                icon: Icons.title,
              ),
              const SizedBox(height: 16),

              // Description Field
              _buildTextField(
                controller: descController,
                label: 'Mô tả',
                hint: 'Nhập mô tả banner',
                icon: Icons.description,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Link Field
              _buildTextField(
                controller: linkController,
                label: 'Link (Tùy chọn)',
                hint: 'https://example.com',
                icon: Icons.link,
              ),
              const SizedBox(height: 16),

              // Position Field
              _buildTextField(
                controller: positionController,
                label: 'Vị trí (0-999)',
                hint: '0',
                icon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createBanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Thêm Banner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blue[700]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
