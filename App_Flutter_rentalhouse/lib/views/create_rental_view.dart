import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:flutter_rentalhouse/views/login_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../viewmodels/vm_auth.dart';
import '../models/rental.dart';

class CreateRentalScreen extends StatefulWidget {
  const CreateRentalScreen({super.key});

  @override
  _CreateRentalScreenState createState() => _CreateRentalScreenState();
}

class _CreateRentalScreenState extends State<CreateRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  List<File> _images = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    // Kiểm tra và yêu cầu quyền
    final storagePermission = await Permission.storage.request();
    if (!storagePermission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền truy cập thư viện ảnh')),
      );
      return;
    }

    // Khởi tạo ImagePicker trong hàm
    final ImagePicker picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles != null) {
        setState(() {
          _images.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Bài Đăng')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Giá (VND)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập giá';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Giá phải là số hợp lệ và lớn hơn 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Vị trí',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập vị trí';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Ảnh (tối đa 5):'),
              const SizedBox(height: 10),
              _images.isNotEmpty
                  ? SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Stack(
                        children: [
                          Image.file(
                            _images[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _images.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
                  : const Text('Chưa chọn ảnh'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _images.length >= 5 ? null : _pickImages,
                child: const Text('Chọn Ảnh'),
              ),
              const SizedBox(height: 20),
              if (rentalViewModel.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (authViewModel.currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng đăng nhập để tạo bài đăng'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                        return;
                      }
                      if (_images.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn ít nhất một ảnh'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      final rental = Rental(
                        title: _titleController.text,
                        description: _descriptionController.text,
                        price: double.parse(_priceController.text),
                        location: _locationController.text,
                        userId: authViewModel.currentUser!.id,
                        images: [], // Sẽ được backend xử lý
                        createdAt: DateTime.now(),
                      );
                      final imagePaths = _images.map((file) => file.path).toList();
                      await rentalViewModel.createRental(rental, imagePaths);
                      if (rentalViewModel.errorMessage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tạo bài đăng thành công'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(rentalViewModel.errorMessage!),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Đăng Bài'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}