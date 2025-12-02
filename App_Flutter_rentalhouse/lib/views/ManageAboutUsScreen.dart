
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:flutter_rentalhouse/views/Admin/View/about_us_preview_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rentalhouse/config/api_routes.dart';

class ManageAboutUsScreen extends StatefulWidget {
  const ManageAboutUsScreen({super.key});

  @override
  State<ManageAboutUsScreen> createState() => _ManageAboutUsScreenState();
}

class _ManageAboutUsScreenState extends State<ManageAboutUsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _existingImages = [];
  bool _isLoading = false;
  String? _aboutUsId;

  @override
  void initState() {
    super.initState();
    _loadAboutUs();
  }

  Future<void> _loadAboutUs() async {
    setState(() => _isLoading = true);
    try {
      final token = await Provider.of<AuthService>(context, listen: false).getIdToken();
      if (token == null) throw Exception('Không lấy được token');

      final response = await http.get(
        Uri.parse('${ApiRoutes.baseUrl}/admin/aboutus'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final aboutUs = data['data'][0];
          _aboutUsId = aboutUs['_id'];
          _titleController.text = aboutUs['title'] ?? '';
          _descriptionController.text = aboutUs['description'] ?? '';
          _existingImages.addAll(List<String>.from(aboutUs['images'] ?? []));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
      });
    }
  }

  Future<void> _submitAboutUs() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await Provider.of<AuthService>(context, listen: false).getIdToken();
      if (token == null) throw Exception('Không lấy được token');

      final uri = Uri.parse(
        _aboutUsId != null
            ? '${ApiRoutes.baseUrl}/admin/aboutus/$_aboutUsId'
            : '${ApiRoutes.baseUrl}/admin/aboutus',
      );

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['title'] = _titleController.text
        ..fields['description'] = _descriptionController.text;

      if (_aboutUsId != null) {
        request.fields['id'] = _aboutUsId!;
      }

      for (var image in _selectedImages) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _selectedImages.clear();
        _titleController.clear();
        _descriptionController.clear();
        _existingImages.clear();
        _aboutUsId = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu nội dung About Us thành công')),
        );
        await _loadAboutUs();
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage(String imageUrl) async {
    setState(() => _isLoading = true);
    try {
      final token = await Provider.of<AuthService>(context, listen: false).getIdToken();
      if (token == null) throw Exception('Không lấy được token');

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/admin/aboutus/$_aboutUsId/image'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        setState(() => _existingImages.remove(imageUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa ảnh thành công')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa ảnh: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  void _previewAboutUs() {

    final previewData = {
      'title': _titleController.text.isEmpty ? 'Công ty chúng tôi' : _titleController.text,
      'description': _descriptionController.text,
      'images': [
        ..._existingImages,
      ],
    };


    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AboutUsPreviewScreen(previewData: previewData),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viết nội dung giới thiệu'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _existingImages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tiêu đề',
                hintText: 'Nhập tiêu đề về công ty...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title, color: Colors.redAccent),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            // Mô tả
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Nội dung giới thiệu',
                hintText: 'Viết nội dung chi tiết về công ty, sứ mệnh, tầm nhìn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon:
                const Icon(Icons.description, color: Colors.redAccent),
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 20),

            // Chọn ảnh
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image_search),
              label: const Text('Chọn ảnh từ thiết bị'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),

            // Hiển thị ảnh đã chọn
            if (_selectedImages.isNotEmpty) ...[
              Text(
                'Ảnh mới (${_selectedImages.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(
                                    () => _selectedImages.removeAt(index));
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Hiển thị ảnh hiện có
            if (_existingImages.isNotEmpty) ...[
              Text(
                'Ảnh hiện có (${_existingImages.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _existingImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '${ApiRoutes.rootUrl}${_existingImages[index]}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              _deleteImage(_existingImages[index]),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Nút lưu
            ElevatedButton(
              onPressed: _isLoading ? null : _submitAboutUs,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Lưu nội dung',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

// Nút Xem trước
            ElevatedButton.icon(
              onPressed: _previewAboutUs,
              icon: const Icon(Icons.visibility),
              label: const Text('Xem trước trang Giới thiệu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// ==================== MANAGE FEEDBACK SCREEN ====================

