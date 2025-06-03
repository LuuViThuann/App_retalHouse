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
        const PopupMenuItem(
          value: 'map',
          child: Row(
            children: [
              Icon(Icons.map, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Chọn từ bản đồ'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'manual',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Nhập địa chỉ'),
            ],
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
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Center(
              child: Text(
                'Thông tin cá nhân',
                style: TextStyle(color: Colors.black),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.link, color: Colors.black),
                onPressed: () {
                  // TODO: Implement link sharing functionality
                },
              ),
            ],
          ),
          body: authViewModel.isLoading
              ? Center(
                  child: Lottie.asset(
                    AssetsConfig.loadingLottie,
                    width: 100,
                    height: 100,
                    fit: BoxFit.fill,
                  ),
                )
              : user == null
                  ? const Center(child: Text('Không có dữ liệu người dùng'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 50,
                                  backgroundImage:
                                      getImageProvider(user.avatarUrl),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickAndUploadImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  color: Colors.grey),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tên người dùng',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    _isEditing
                                        ? TextField(
                                            controller: _userNameController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              hintText:
                                                  'Nhập tên người dùng...',
                                            ),
                                          )
                                        : Text(
                                            user.username.isEmpty
                                                ? 'Chưa cập nhật'
                                                : user.username,
                                            style:
                                                const TextStyle(fontSize: 16),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined,
                                  color: Colors.grey),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Email',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    Text(
                                      _email ?? 'Chưa cập nhật',
                                      style: const TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  color: Colors.grey),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Số điện thoại',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    _isEditing
                                        ? TextField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              hintText: 'Nhập số điện thoại',
                                            ),
                                          )
                                        : Text(
                                            user.phoneNumber?.isNotEmpty ??
                                                    false
                                                ? user.phoneNumber!
                                                : 'Chưa cập nhật',
                                            style:
                                                const TextStyle(fontSize: 16),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.grey),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Địa chỉ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    _isEditing
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _addressController,
                                                  decoration:
                                                      const InputDecoration(
                                                    border:
                                                        OutlineInputBorder(),
                                                    hintText: 'Chọn địa chỉ...',
                                                  ),
                                                  readOnly: true,
                                                  onTap: _showAddressPickerMenu,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              PopupMenuButton<String>(
                                                color: Colors.white,
                                                icon: const Icon(
                                                  Icons.place,
                                                  color: Colors.blueAccent,
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'map') {
                                                    _pickAddressFromMap();
                                                  } else if (value ==
                                                      'manual') {
                                                    _pickAddressManually();
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'map',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.map,
                                                            color: Colors
                                                                .blueAccent),
                                                        SizedBox(width: 8),
                                                        Text('Chọn từ bản đồ'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'manual',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit,
                                                            color: Colors
                                                                .blueAccent),
                                                        SizedBox(width: 8),
                                                        Text('Nhập địa chỉ'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        : Text(
                                            user.address?.isNotEmpty ?? false
                                                ? user.address!
                                                : 'Chưa cập nhật',
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: const [
                                    Colors.blueAccent,
                                    Colors.lightBlueAccent
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 15),
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
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
}
