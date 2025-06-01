import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/snackbar/showsnackbar.dart';
import 'package:flutter_rentalhouse/utils/snackbar.dart';
import 'package:provider/provider.dart';
import '../viewmodels/vm_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? oobCode; // Nhận mã OOB từ liên kết email

  const ResetPasswordScreen({super.key, this.oobCode});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(AuthViewModel authViewModel) async {
    if (_formKey.currentState!.validate()) {
      try {
        await authViewModel.resetPassword(
          widget.oobCode ?? '',
          _newPasswordController.text,
        );
        if (authViewModel.errorMessage == null) {
          showSnackBar(context, 'Mật khẩu đã được đặt lại thành công!');
          Navigator.pop(context); // Quay lại màn hình đăng nhập
        } else {
          showSnackBar(context, authViewModel.errorMessage!);
        }
      } catch (e) {
        showSnackBar(context, 'Lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt Lại Mật Khẩu'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mật khẩu mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu mới',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Xác nhận mật khẩu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Xác nhận mật khẩu mới',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Mật khẩu không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              authViewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _resetPassword(authViewModel),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Đặt Lại Mật Khẩu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
