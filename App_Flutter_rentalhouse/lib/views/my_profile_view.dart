import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // For Uint8List
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

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _userNameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).fetchCurrentUser();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  // Function to pick and upload image
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        await Provider.of<AuthViewModel>(context, listen: false)
            .uploadProfileImage(imageBase64: base64Image);
        if (Provider.of<AuthViewModel>(context, listen: false).errorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh đại diện đã được cập nhật thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper function to convert Base64 string to ImageProvider
  ImageProvider getImageProvider(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.startsWith('data:image')) {
      // Extract the Base64 part after "data:image/jpeg;base64,"
      final base64String = avatarUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    }
    return const AssetImage('assets/img/imageuser.png');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        final AppUser? user = authViewModel.currentUser;

        if (user != null) {
          _phoneController.text = user.phoneNumber ?? '';
          _addressController.text = user.address ?? '';
          _userNameController.text = user.username ?? ''; // Initialize username controller
        }

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
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.link, color: Colors.black),
                onPressed: () {
                  // Handle link button press
                },
              ),
            ],
          ),
          body: authViewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : user == null
              ? const Center(child: Text('No user data available'))
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
                        backgroundImage: getImageProvider(user?.avatarUrl),
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
                    const Icon(Icons.person_outline, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tên người dùng', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          _isEditing
                              ? TextField(
                            controller: _userNameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Nhập tên người dùng...',
                            ),
                          )
                              : Text(
                            user.username.isEmpty ? 'Chưa cập nhật' : user.username,
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
                    const Icon(Icons.email_outlined, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            user.email,
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
                    const Icon(Icons.phone_outlined, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số điện thoại', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          _isEditing
                              ? TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Nhập số điện thoại...',
                            ),
                          )
                              : Text(
                            user.phoneNumber ?? 'Chưa cập nhật',
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
                    const Icon(Icons.location_on_outlined, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Địa chỉ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          _isEditing
                              ? TextField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Nhập địa chỉ...',
                            ),
                          )
                              : Text(
                            user.address ?? 'Chưa cập nhật',
                            style: const TextStyle(fontSize: 16),
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
                      gradient: const LinearGradient(
                        colors: [Colors.blueAccent, Colors.lightBlueAccent],
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
                      onPressed: () async {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                        if (!_isEditing && user != null) {
                          try {
                            await authViewModel.updateUserProfile(
                              phoneNumber: _phoneController.text,
                              address: _addressController.text,
                              username: _userNameController.text, // Add username update
                            );
                            await authViewModel.fetchCurrentUser();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thông tin đã được cập nhật thành công!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Lưu thông tin' : 'Chỉnh sửa thông tin',
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