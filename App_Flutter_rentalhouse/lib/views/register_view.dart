import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/Profile/enter_new_address.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_rentalhouse/views/select_address_register.dart';
import 'package:path/path.dart' as path;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isPasswordVisible = false;

  File? _avatarImage;
  String? _avatarBase64;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      // Kiểm tra định dạng file
      final extension = path.extension(picked.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains('$extension')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chỉ hỗ trợ file JPEG hoặc PNG'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Kiểm tra kích thước file (tối đa 5MB)
      final file = File(picked.path);
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh quá lớn (tối đa 5MB)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Mã hóa thành base64 không có tiền tố MIME
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _avatarImage = file;
        _avatarBase64 = base64String;
      });
    }
  }

  void _showAddressPickerMenu({String? type}) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const SelectAddressRegisterView()),
    );
    if (selectedAddress != null && selectedAddress is String && mounted) {
      setState(() {
        _addressController.text = selectedAddress;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    const Text(
                      'TẠO TÀI KHOẢN',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tên người dùng',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                hintText: 'Nhập tên người dùng',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập tên người dùng';
                                }
                                if (value.length < 3) {
                                  return 'Tên người dùng phải có ít nhất 3 ký tự';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Nhập email của bạn',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập email';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                                  return 'Vui lòng nhập email hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Mật Khẩu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                hintText: 'Nhập mật khẩu của bạn',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_isPasswordVisible,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                if (value.length < 6) {
                                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Số điện thoại',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneNumberController,
                              decoration: InputDecoration(
                                hintText: 'Nhập số điện thoại của bạn',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập số điện thoại';
                                }
                                if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                  return 'Số điện thoại phải có 10 chữ số';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Địa chỉ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _addressController,
                                    decoration: InputDecoration(
                                      hintText: 'Chọn địa chỉ...',
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 16, horizontal: 20),
                                    ),
                                    readOnly: true,
                                    onTap: () =>
                                        _showAddressPickerMenu(type: 'map'),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Vui lòng chọn địa chỉ';
                                      }
                                      return null;
                                    },
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
                                      _showAddressPickerMenu(type: 'map');
                                    } else if (value == 'manual') {
                                      _showAddressPickerMenu(type: 'manual');
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'map',
                                      child: Row(
                                        children: [
                                          Icon(Icons.map,
                                              color: Colors.blueAccent),
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
                                              color: Colors.blueAccent),
                                          SizedBox(width: 8),
                                          Text('Nhập địa chỉ'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Ảnh đại diện (bắt buộc)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: GestureDetector(
                                onTap: _pickAvatar,
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _avatarImage != null
                                      ? FileImage(_avatarImage!)
                                      : null,
                                  child: _avatarImage == null
                                      ? const Icon(Icons.add_a_photo,
                                          size: 40, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (authViewModel.isLoading)
                              Center(
                                child: Lottie.asset(
                                  AssetsConfig.loadingLottie,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.fill,
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () async {
                                  if (_formKey.currentState!.validate()) {
                                    if (_avatarBase64 == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Vui lòng chọn ảnh đại diện'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    await authViewModel.register(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text,
                                      phoneNumber:
                                          _phoneNumberController.text.trim(),
                                      address: _addressController.text,
                                      username: _usernameController.text.trim(),
                                      avatarBase64: _avatarBase64!,
                                    );
                                    if (authViewModel.errorMessage == null) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Đăng ký thành công'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen()),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                authViewModel.errorMessage!),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blueAccent,
                                        Colors.lightBlueAccent
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Xác nhận đăng ký',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Đã có tài khoản? ',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Đăng Nhập',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'Hoặc đăng ký với',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await authViewModel.signInWithGoogle();
                                    if (authViewModel.errorMessage == null &&
                                        authViewModel.currentUser != null) {
                                      if (mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen()),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(authViewModel
                                                    .errorMessage ??
                                                'Đăng nhập Google thất bại'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.g_mobiledata,
                                      color: Colors.red,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                GestureDetector(
                                  onTap: () async {
                                    await authViewModel.signInWithFacebook();
                                    if (authViewModel.errorMessage == null &&
                                        authViewModel.currentUser != null) {
                                      if (mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen()),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(authViewModel
                                                    .errorMessage ??
                                                'Đăng nhập Facebook thất bại'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.facebook,
                                      color: Colors.blue,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
