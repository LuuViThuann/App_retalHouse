import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/views/change_address_profile.dart';
import 'package:flutter_rentalhouse/views/home.dart';
import 'package:flutter_rentalhouse/views/Admin/View/HomeAdminScreen.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../viewmodels/vm_auth.dart';
import '../models/user.dart';

class MyProfileView extends StatefulWidget {
  const MyProfileView({super.key});

  @override
  _MyProfileViewState createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _userNameController;
  final ImagePicker _picker = ImagePicker();
  String? _email;
  bool _isFromAdmin = false;
  bool _isNavigating = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _userNameController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _isFromAdmin = args is bool ? args : false;

      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final user = authViewModel.currentUser;
      if (user != null) {
        setState(() {
          _phoneController.text = user.phoneNumber ?? '';
          _addressController.text = user.address ?? '';
          _userNameController.text = user.username ?? '';
          _email = user.email.isNotEmpty
              ? user.email
              : 'user_${user.id}@noemail.com';
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _userNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
        await authViewModel.uploadProfileImage(imageBase64: base64Image);
        if (authViewModel.errorMessage == null) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(message: 'Ảnh đại diện đã được cập nhật thành công!'),
          );
        } else {
          AppSnackBar.show(
            context,
            AppSnackBar.error(message: 'Lỗi: ${authViewModel.errorMessage}'),
          );
        }
      }
    } catch (e) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Lỗi khi tải ảnh: ${e.toString()}'),
      );
    }
  }

  Future<void> _updateProfile() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_phoneController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Vui lòng nhập số điện thoại hợp lệ'),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.error(message: 'Vui lòng nhập địa chỉ'),
      );
      return;
    }

    try {
      await authViewModel.updateUserProfile(
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        username: _userNameController.text.trim(),
      );
      if (mounted) {
        if (authViewModel.errorMessage == null) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(message: 'Thông tin đã được cập nhật thành công!'),
          );
          setState(() {
            _isEditing = false;
          });
        } else {
          AppSnackBar.show(
            context,
            AppSnackBar.error(
              message: 'Lỗi: ${authViewModel.errorMessage ?? 'Không thể cập nhật thông tin'}',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi khi cập nhật: ${e.toString()}'),
        );
      }
    }
  }

  Future<void> _pickAddressFromMap() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangeAddressView()),
    );

    if (selectedAddress != null && selectedAddress is String && mounted) {
      setState(() {
        _addressController.text = selectedAddress;
      });
    }
  }

  Future<void> _pickAddressManually() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewAddressPage()),
    );

    if (selectedAddress != null && selectedAddress is String && mounted) {
      setState(() {
        _addressController.text = selectedAddress;
      });
    }
  }

  ImageProvider getImageProvider(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        final base64String = avatarUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } else if (avatarUrl.startsWith('http')) {
        return NetworkImage(avatarUrl);
      }
    }
    return const AssetImage('assets/img/imageuser.png');
  }

  void _showAddressPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn địa chỉ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            _buildAddressOption(
              icon: Icons.map_outlined,
              title: 'Chọn từ bản đồ',
              subtitle: 'Định vị chính xác trên bản đồ',
              onTap: () {
                Navigator.pop(context);
                _pickAddressFromMap();
              },
            ),
            const SizedBox(height: 12),
            _buildAddressOption(
              icon: Icons.edit_location_alt_outlined,
              title: 'Nhập địa chỉ',
              subtitle: 'Nhập thủ công địa chỉ của bạn',
              onTap: () {
                Navigator.pop(context);
                _pickAddressManually();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                AssetsConfig.loadingLottie,
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHome() {
    setState(() {
      _isNavigating = true;
    });
    _showLoadingDialog('Đang di chuyển trang ...');
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    });
  }

  void _navigateToAdmin() {
    setState(() {
      _isNavigating = true;
    });
    _showLoadingDialog('Đang di chuyển trang ...');
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeAdminScreen()),
              (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final AppUser? user = authViewModel.currentUser;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: authViewModel.isLoading
              ? Center(
            child: Lottie.asset(
              AssetsConfig.loadingLottie,
              width: 100,
              height: 100,
            ),
          )
              : user == null
              ? const Center(
            child: Text(
              'Không có dữ liệu người dùng',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          )
              : CustomScrollView(
            slivers: [
              _buildAppBar(user),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileCard(user),
                      const SizedBox(height: 16),
                      _buildPersonalInfoCard(user),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 16),
                      if (user.role == 'admin') _buildAdminSection(context, authViewModel),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(AppUser user) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.blue[700],
      title: Text(
        _isEditing ? 'Chỉnh sửa hồ sơ' : 'Hồ sơ cá nhân',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildProfileCard(AppUser user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: getImageProvider(user.avatarUrl),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username.isEmpty ? 'Người dùng' : user.username,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _email ?? 'Chưa cập nhật',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (user.role == 'admin') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Color(0xFFF59E0B), size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Quản trị viên',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(AppUser user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF3B82F6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Thông tin cá nhân',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildModernInfoRow(
                  icon: Icons.person_outline,
                  label: 'Tên người dùng',
                  value: user.username.isEmpty ? 'Chưa cập nhật' : user.username,
                  isEditing: _isEditing,
                  controller: _userNameController,
                  hintText: 'Nhập tên của bạn',
                ),
                const SizedBox(height: 16),
                _buildModernInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _email ?? 'Chưa cập nhật',
                  isEditing: false,
                ),
                const SizedBox(height: 16),
                _buildModernInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Số điện thoại',
                  value: user.phoneNumber?.isNotEmpty ?? false
                      ? user.phoneNumber!
                      : 'Chưa cập nhật',
                  isEditing: _isEditing,
                  controller: _phoneController,
                  hintText: 'Nhập số điện thoại',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildModernInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ',
                  value: user.address?.isNotEmpty ?? false
                      ? user.address!
                      : 'Chưa cập nhật',
                  isEditing: _isEditing,
                  controller: _addressController,
                  hintText: 'Chọn địa chỉ',
                  readOnly: true,
                  onTap: _isEditing ? _showAddressPickerBottomSheet : null,
                  showArrow: _isEditing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isEditing = false,
    TextEditingController? controller,
    String? hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        isEditing && controller != null
            ? GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        )
            : Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                if (_isEditing) {
                  _updateProfile();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.save_outlined : Icons.edit_outlined,
                    size: 20, color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Lưu thông tin' : 'Chỉnh sửa hồ sơ',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                    final user = authViewModel.currentUser;
                    if (user != null) {
                      _phoneController.text = user.phoneNumber ?? '';
                      _addressController.text = user.address ?? '';
                      _userNameController.text = user.username ?? '';
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B7280),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Hủy bỏ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, AuthViewModel authViewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Khu vực quản trị',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isNavigating
                  ? null
                  : () {
                if (_isFromAdmin) {
                  _navigateToHome();
                } else {
                  _navigateToAdmin();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFromAdmin ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFromAdmin ? Icons.home_outlined : Icons.dashboard_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isFromAdmin ? 'Quay lại ứng dụng' : 'Vào trang quản trị',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}