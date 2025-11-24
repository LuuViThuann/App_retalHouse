import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_routes.dart';
import '../../../services/auth_service.dart';
import '../ViewModel/admin_viewmodel.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Map<String, dynamic> user;
  String? avatarBase64; // Lưu riêng ảnh
  bool isLoading = true;
  bool isSaving = false;

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  String? _selectedRole;

  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// ✅ Load thông tin người dùng + ảnh (tất cả trong 1 lần)
  Future<void> _loadUserData({bool forceReload = false}) async {
    setState(() => isLoading = true);

    final vm = context.read<AdminViewModel>();

    // ✅ Fetch chi tiết người dùng (bao gồm ảnh đầy đủ)
    await vm.fetchUserDetail(widget.userId);

    if (!mounted) return;

    final detail = vm.currentUserDetail;
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được thông tin người dùng')),
      );
      return;
    }

    setState(() {
      user = Map.from(detail);
      _nameCtrl = TextEditingController(text: user['username'] ?? '');
      _emailCtrl = TextEditingController(text: user['email'] ?? '');
      _phoneCtrl = TextEditingController(text: user['phoneNumber'] ?? '');
      _selectedRole = user['role'] ?? 'user';

      // ✅ Lấy ảnh từ response
      avatarBase64 = user['avatarBase64'];

      isLoading = false;
    });
  }

  /// Đổi ảnh đại diện
  Future<void> _changeAvatar() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 80,
    );

    if (picked == null || !mounted) return;

    setState(() => isSaving = true);

    try {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final vm = context.read<AdminViewModel>();
      final success = await vm.updateUserAvatar(widget.userId, base64Image);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi ảnh đại diện thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ Cập nhật ảnh hiển thị ngay
        setState(() {
          avatarBase64 = base64Image;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi ảnh thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  /// Lưu thông tin
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final updateData = {
      'username': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      if (_selectedRole != null) 'role': _selectedRole,
    };

    final vm = context.read<AdminViewModel>();
    final success = await vm.updateUser(widget.userId, updateData);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // ✅ Quay lại ngay mà không cần reload
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => isSaving = false);
  }

  /// ✅ Xử lý ảnh hiển thị (từ base64)
  Widget _buildAvatarWidget() {
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(avatarBase64!),
            width: 160,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ),
        );
      } catch (e) {
        debugPrint('Lỗi load ảnh: $e');
        return _defaultAvatar();
      }
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return const CircleAvatar(
      radius: 80,
      backgroundImage: AssetImage('assets/default_avatar.png'),
      backgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chi tiết người dùng'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (!isLoading)
            IconButton(
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: isSaving ? null : _saveChanges,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadUserData(forceReload: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // AVATAR + NÚT CHỌN ẢNH
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _buildAvatarWidget(),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: isSaving ? null : _changeAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.deepPurple,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FORM THÔNG TIN
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameCtrl,
                                label: 'Tên người dùng',
                                icon: Icons.person_outline,
                                validator: (v) => v!.trim().isEmpty
                                    ? 'Vui lòng nhập tên'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _emailCtrl,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _phoneCtrl,
                                label: 'Số điện thoại',
                                icon: Icons.phone_iphone,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 28),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Vai trò',
                                  prefixIcon:
                                      const Icon(Icons.admin_panel_settings),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'user',
                                    child: Text('Người dùng thường'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Quản trị viên'),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedRole = val),
                                validator: (v) =>
                                    v == null ? 'Chọn vai trò' : null,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isSaving ? null : _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text(
                                          'Lưu thay đổi',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
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
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
    );
  }
}
