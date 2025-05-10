import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:provider/provider.dart';


class ChangePasswordScreen extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Đổi Mật Khẩu')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(labelText: 'Mật khẩu hiện tại'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
              ),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'Mật khẩu mới'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập mật khẩu mới' : null,
              ),
              SizedBox(height: 20),
              if (authViewModel.isLoading)
                CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await authViewModel.changePassword(
                        _currentPasswordController.text,
                        _newPasswordController.text,
                      );
                      if (authViewModel.errorMessage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đổi mật khẩu thành công')),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authViewModel.errorMessage!)),
                        );
                      }
                    }
                  },
                  child: Text('Đổi Mật Khẩu'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}