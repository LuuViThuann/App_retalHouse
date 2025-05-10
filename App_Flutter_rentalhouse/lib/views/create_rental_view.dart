import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_rental.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateRentalScreen extends StatefulWidget {
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
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    setState(() {
      _images.addAll(pickedFiles.map((file) => File(file.path)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final rentalViewModel = Provider.of<RentalViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Tạo Bài Đăng')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Tiêu đề'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Mô tả'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập mô tả' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Giá (VND)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập giá' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Vị trí'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập vị trí' : null,
              ),
              SizedBox(height: 20),
              Text('Ảnh (tối đa 5):'),
              SizedBox(height: 10),
              _images.isNotEmpty
                  ? SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Stack(
                        children: [
                          Image.file(_images[index], width: 100, fit: BoxFit.cover),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red),
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
                  : Text('Chưa chọn ảnh'),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _images.length >= 5 ? null : _pickImages,
                child: Text('Chọn Ảnh'),
              ),
              SizedBox(height: 20),
              if (rentalViewModel.isLoading)
                Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (authViewModel.user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Vui lòng đăng nhập lại')),
                        );
                        return;
                      }
                      await rentalViewModel.createRental(
                        title: _titleController.text,
                        description: _descriptionController.text,
                        price: double.parse(_priceController.text),
                        location: _locationController.text,
                        userId: authViewModel.user!.id,
                        images: _images,
                      );
                      if (rentalViewModel.errorMessage == null) {
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(rentalViewModel.errorMessage!)),
                        );
                      }
                    }
                  },
                  child: Text('Đăng Bài'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}