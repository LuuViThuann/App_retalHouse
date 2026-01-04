import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  String? avatarUrl;
  bool isLoading = true;
  bool isSaving = false;
  bool _isEditing = false;

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  String? _selectedRole;

  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadUserData();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
  }

  Future<void> _loadUserData({bool forceReload = false}) async {
    setState(() => isLoading = true);

    final vm = context.read<AdminViewModel>();
    await vm.fetchUserDetail(widget.userId);

    if (!mounted) return;

    final detail = vm.currentUserDetail;
    if (detail == null) {
      setState(() => isLoading = false);
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: 'Không tải được thông tin người dùng',
          icon: Icons.cloud_off_outlined,
        ),
      );
      return;
    }

    debugPrint('✅ User detail loaded: ${detail.toString()}');

    setState(() {
      user = Map.from(detail);
      _nameCtrl.text = user['username'] ?? '';
      _emailCtrl.text = user['email'] ?? '';
      _phoneCtrl.text = user['phoneNumber'] ?? '';
      _addressCtrl.text = user['address'] ?? '';
      _selectedRole = user['role'] ?? 'user';
      avatarUrl = user['avatarUrl'];

      debugPrint('📝 Loaded user data:');
      debugPrint('   Username: ${user['username']}');
      debugPrint('   Email: ${user['email']}');
      debugPrint('   Phone: ${user['phoneNumber']}');
      debugPrint('   Address: ${user['address']}');
      debugPrint('   Avatar URL: $avatarUrl');

      isLoading = false;
    });
  }

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
      final vm = context.read<AdminViewModel>();
      final success = await vm.updateUserAvatar(widget.userId, picked.path);

      if (!mounted) return;

      if (success) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(
            message: 'Đổi ảnh đại diện thành công',
            icon: Icons.image_outlined,
          ),
        );
        await _loadUserData(forceReload: true);
      } else {
        AppSnackBar.show(
          context,
          AppSnackBar.error(
            message: vm.error ?? 'Đổi ảnh thất bại',
            icon: Icons.image_not_supported_outlined,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error changing avatar: $e');
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: 'Lỗi: $e',
          icon: Icons.error_outline,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final updateData = {
      'username': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      if (_selectedRole != null) 'role': _selectedRole,
    };

    debugPrint('📝 Saving user data: $updateData');

    final vm = context.read<AdminViewModel>();
    final success = await vm.updateUser(widget.userId, updateData);

    if (!mounted) return;

    if (success) {
      AppSnackBar.show(
        context,
        AppSnackBar.success(
          message: 'Cập nhật thông tin thành công',
          icon: Icons.check_circle_outline,
        ),
      );
      setState(() => _isEditing = false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } else {
      AppSnackBar.show(
        context,
        AppSnackBar.error(
          message: vm.error ?? 'Cập nhật thất bại',
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    setState(() => isSaving = false);
  }

  Widget _buildAvatarWidget() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _defaultAvatar(),
          fadeInDuration: const Duration(milliseconds: 300),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade200, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.person, size: 80, color: Colors.blue),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thông tin tài khoản',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _isEditing
                  ? TextButton(
                onPressed: isSaving ? null : () => setState(() => _isEditing = false),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                onPressed: () => setState(() => _isEditing = true),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : RefreshIndicator(
        onRefresh: () => _loadUserData(forceReload: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ========== PROFILE HEADER ==========
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                child: Column(
                  children: [
                    // Avatar with edit button
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildAvatarWidget(),
                        ),
                        GestureDetector(
                          onTap: isSaving ? null : _changeAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              isSaving ? Icons.hourglass_empty : Icons.camera_alt,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      user['username'] ?? 'Người dùng',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'admin'
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _selectedRole == 'admin' ? '👑 Quản trị viên' : '👤 Người dùng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedRole == 'admin'
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ========== FORM SECTION ==========
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // User ID
                      _buildInfoCard(
                        icon: Icons.badge_outlined,
                        label: 'User ID',
                        value: widget.userId,
                        isEditable: false,
                      ),
                      const SizedBox(height: 16),

                      // Created Date
                      _buildInfoCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'Ngày tạo',
                        value: _formatDate(user['createdAt']),
                        isEditable: false,
                      ),
                      const SizedBox(height: 24),

                      // Editable Fields
                      if (_isEditing) ...[
                        _buildEditableField(
                          controller: _nameCtrl,
                          label: 'Tên người dùng',
                          icon: Icons.person_outline,
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildEditableField(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Vui lòng nhập email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildEditableField(
                          controller: _phoneCtrl,
                          label: 'Số điện thoại',
                          icon: Icons.phone_iphone,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v!.trim().isEmpty)
                              return 'Vui lòng nhập số điện thoại';
                            if (v.length < 10)
                              return 'Số điện thoại phải có ít nhất 10 chữ số';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildEditableField(
                          controller: _addressCtrl,
                          label: 'Địa chỉ',
                          icon: Icons.location_on_outlined,
                          keyboardType: TextInputType.text,
                          validator: (v) =>
                          v!.trim().isEmpty ? 'Vui lòng nhập địa chỉ' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildRoleDropdown(),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              disabledBackgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isSaving
                                ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text(
                              'Lưu thay đổi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildInfoCard(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user['email'] ?? 'Chưa cập nhật',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.phone_outlined,
                          label: 'Số điện thoại',
                          value: user['phoneNumber'] ?? 'Chưa cập nhật',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.location_on_outlined,
                          label: 'Địa chỉ',
                          value: user['address'] ?? 'Chưa cập nhật',
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
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
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue, size: 20),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          labelText: 'Vai trò',
          prefixIcon: const Icon(
            Icons.admin_panel_settings,
            color: Colors.blue,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: const TextStyle(fontSize: 14),
        ),
        items: const [
          DropdownMenuItem(value: 'user', child: Text('👤 Người dùng thường')),
          DropdownMenuItem(value: 'admin', child: Text('👑 Quản trị viên')),
        ],
        onChanged: (val) => setState(() => _selectedRole = val),
        validator: (v) => v == null ? 'Chọn vai trò' : null,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Chưa xác định';
    try {
      final DateTime parsedDate = date is String ? DateTime.parse(date) : date as DateTime;
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return 'Chưa xác định';
    }
  }
}