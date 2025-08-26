import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/views/change_address_profile.dart';
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

class _MyProfileViewState extends State<MyProfileView> {
  bool _isEditing = false;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _userNameController;
  final ImagePicker _picker = ImagePicker();
  String? _email;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _userNameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final authViewModel =
            Provider.of<AuthViewModel>(context, listen: false);
        await authViewModel.uploadProfileImage(imageBase64: base64Image);
        if (authViewModel.errorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh đại diện đã được cập nhật thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${authViewModel.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải ảnh: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập địa chỉ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await authViewModel.updateUserProfile(
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        username: _userNameController.text.trim(),
      );
      if (authViewModel.errorMessage == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông tin đã được cập nhật thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isEditing = false;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lỗi: ${authViewModel.errorMessage ?? 'Không thể cập nhật thông tin'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  void _showAddressPickerMenu() {
    showMenu(
      color: Colors.white,
      context: context,
      position: const RelativeRect.fromLTRB(100, 400, 100, 100),
      items: [
        PopupMenuItem(
          value: 'map',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: const [
                Icon(Icons.map, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Chọn từ bản đồ',
                    style: TextStyle(color: Colors.blueAccent)),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: 'manual',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: const [
                Icon(Icons.edit, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Nhập địa chỉ',
                    style: TextStyle(color: Colors.blueAccent)),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'map') {
        _pickAddressFromMap();
      } else if (value == 'manual') {
        _pickAddressManually();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final AppUser? user = authViewModel.currentUser;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.blueAccent,
            elevation: 0,
            title: const Text(
              'Thông tin cá nhân',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.link, color: Colors.white),
                onPressed: () {
                  // TODO: Implement link sharing functionality
                },
              ),
            ],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          body: authViewModel.isLoading
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Lottie.asset(
                      AssetsConfig.loadingLottie,
                      width: 100,
                      height: 100,
                      fit: BoxFit.fill,
                    ),
                  ),
                )
              : user == null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Không có dữ liệu người dùng',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent.withOpacity(0.2),
                                    Colors.blueAccent.withOpacity(0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 60,
                                    backgroundImage:
                                        getImageProvider(user.avatarUrl),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickAndUploadImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildInfoSection(
                            title: 'Thông tin cá nhân',
                            icon: Icons.person_outline,
                            iconColor: Colors.blueAccent,
                            children: [
                              _buildInfoRow(
                                label: 'Tên người dùng',
                                value: user.username.isEmpty
                                    ? 'Chưa cập nhật'
                                    : user.username,
                                icon: Icons.person,
                                iconColor: Colors.blueAccent,
                                isEditing: _isEditing,
                                controller: _userNameController,
                                hintText: 'Nhập tên người dùng...',
                              ),
                              _buildInfoRow(
                                label: 'Email',
                                value: _email ?? 'Chưa cập nhật',
                                icon: Icons.email_outlined,
                                iconColor: Colors.blueAccent,
                                isEditing: false,
                              ),
                              _buildInfoRow(
                                label: 'Số điện thoại',
                                value: user.phoneNumber?.isNotEmpty ?? false
                                    ? user.phoneNumber!
                                    : 'Chưa cập nhật',
                                icon: Icons.phone_outlined,
                                iconColor: Colors.blueAccent,
                                isEditing: _isEditing,
                                controller: _phoneController,
                                hintText: 'Nhập số điện thoại',
                                keyboardType: TextInputType.phone,
                              ),
                              _buildInfoRow(
                                label: 'Địa chỉ',
                                value: user.address?.isNotEmpty ?? false
                                    ? user.address!
                                    : 'Chưa cập nhật',
                                icon: Icons.location_on_outlined,
                                iconColor: Colors.blueAccent,
                                isEditing: _isEditing,
                                controller: _addressController,
                                hintText: 'Chọn địa chỉ...',
                                readOnly: true,
                                onTap:
                                    _isEditing ? _showAddressPickerMenu : null,
                                trailing: _isEditing
                                    ? PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.place,
                                          color: Colors.blueAccent,
                                        ),
                                        color: Colors.white,
                                        onSelected: (value) {
                                          if (value == 'map') {
                                            _pickAddressFromMap();
                                          } else if (value == 'manual') {
                                            _pickAddressManually();
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'map',
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.map,
                                                      color: Colors.blueAccent),
                                                  SizedBox(width: 8),
                                                  Text('Chọn từ bản đồ',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .blueAccent)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'manual',
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.edit,
                                                      color: Colors.blueAccent),
                                                  SizedBox(width: 8),
                                                  Text('Nhập địa chỉ',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .blueAccent)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent,
                                    Colors.blueAccent.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
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
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _isEditing
                                      ? 'Lưu thông tin'
                                      : 'Chỉnh sửa thông tin',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                iconColor.withOpacity(0.1),
                iconColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isEditing = false,
    TextEditingController? controller,
    String? hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: isEditing && controller != null
                ? TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      hintText: hintText,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF424242),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF424242),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}
