import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/services/auth_service.dart';
import 'package:flutter_rentalhouse/utils/Snackbar_process.dart';
import 'package:flutter_rentalhouse/views/Admin/View/about_us_preview_screen.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
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
  final List<Map<String, dynamic>> _existingImages = [];
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

      print('📥 Load AboutUs: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final aboutUs = data['data'][0];

          setState(() {
            _aboutUsId = aboutUs['_id'];
            _titleController.text = aboutUs['title'] ?? '';
            _descriptionController.text = aboutUs['description'] ?? '';
            _existingImages.clear();


            if (aboutUs['images'] != null) {
              try {
                final rawImages = aboutUs['images'];


                if (rawImages is List) {
                  for (int i = 0; i < rawImages.length; i++) {
                    final img = rawImages[i];

                    if (img is Map<String, dynamic>) {
                      // Format mới: {url, cloudinaryId, order}
                      _existingImages.add({
                        'url': img['url'] as String,
                        'cloudinaryId': img['cloudinaryId'] as String?,
                        'order': img['order'] as int? ?? i,
                      });
                    } else if (img is String) {
                      // Format cũ: chỉ URL string
                      _existingImages.add({
                        'url': img,
                        'cloudinaryId': null,
                        'order': i,
                      });
                    } else {
                      print('⚠️ Unknown image format at index $i: ${img.runtimeType}');
                    }
                  }
                }

                print('✅ Loaded ${_existingImages.length} existing images');
              } catch (parseError) {
                print('❌ Error parsing images: $parseError');
                print('   Raw images data: ${aboutUs['images']}');
              }
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error loading AboutUs: $e');
      print('   Stack trace: ${StackTrace.current}');
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi tải dữ liệu: ${e.toString().split(':').last}'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.success(message: 'Đã chọn ${pickedFiles.length} ảnh'),
        );
      }
    }
  }

  Future<void> _submitAboutUs() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Vui lòng điền đầy đủ thông tin'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await Provider.of<AuthService>(context, listen: false).getIdToken();
      if (token == null) throw Exception('Không lấy được token');

      final uri = Uri.parse('${ApiRoutes.baseUrl}/admin/aboutus');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['title'] = _titleController.text
        ..fields['description'] = _descriptionController.text;

      if (_aboutUsId != null) {
        request.fields['id'] = _aboutUsId!;
      }

      // Thêm ảnh mới với MIME type cụ thể
      for (var image in _selectedImages) {
        String mimeType;
        final ext = image.path.split('.').last.toLowerCase();

        switch (ext) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          default:
            mimeType = 'image/jpeg';
        }

        request.files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      print('📤 Submitting AboutUs...');
      print('   Title: ${_titleController.text}');
      print('   ID: $_aboutUsId');
      print('   New images: ${_selectedImages.length}');

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _selectedImages.clear();
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(
              message: 'Lưu nội dung thông tin thành công',
              icon: Icons.check_circle,
            ),
          );
        }

        await _loadAboutUs();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error submitting: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi: $e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteImage(String imageUrl) async {
    if (_aboutUsId == null) {
      AppSnackBar.show(
        context,
        AppSnackBar.warning(message: 'Chưa có thông tin để xóa ảnh'),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await Provider.of<AuthService>(context, listen: false).getIdToken();
      if (token == null) throw Exception('Không lấy được token');

      print('🗑️ Deleting image: $imageUrl');

      final response = await http.delete(
        Uri.parse('${ApiRoutes.baseUrl}/admin/aboutus/$_aboutUsId/image'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      print('📥 Delete response: ${response.statusCode}');

      if (response.statusCode == 200) {
        setState(() {
          _existingImages.removeWhere((img) => img['url'] == imageUrl);
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            AppSnackBar.success(message: 'Xóa ảnh thành công'),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Lỗi xóa ảnh');
      }
    } catch (e) {
      print('❌ Error deleting image: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.error(message: 'Lỗi xóa ảnh: $e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _previewAboutUs() {
    final previewData = {
      'title': _titleController.text.isEmpty ? 'Công ty chúng tôi' : _titleController.text,
      'description': _descriptionController.text,
      'images': _existingImages.map((img) => img['url'] as String).toList(),
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

            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Nội dung giới thiệu',
                hintText: 'Viết nội dung chi tiết về công ty, sứ mệnh, tầm nhìn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description, color: Colors.redAccent),
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image_search),
              label: const Text('Chọn ảnh từ thiết bị'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedImages.removeAt(index));
                            AppSnackBar.show(
                              context,
                              AppSnackBar.info(message: 'Đã xóa ảnh mới'),
                            );
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _existingImages.length,
                itemBuilder: (context, index) {
                  final imageUrl = _existingImages[index]['url'] as String;

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl, // ✅ FIX: URL đã là full URL từ Cloudinary
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deleteImage(imageUrl),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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