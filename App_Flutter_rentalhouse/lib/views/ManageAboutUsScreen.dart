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
                      _existingImages.add({
                        'url': img['url'] as String,
                        'cloudinaryId': img['cloudinaryId'] as String?,
                        'order': img['order'] as int? ?? i,
                      });
                    } else if (img is String) {
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _isLoading && _existingImages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Thông tin cơ bản'),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 28),
            _buildSectionHeader('Hình ảnh giới thiệu'),
            const SizedBox(height: 12),
            _buildPickImageButton(),
            const SizedBox(height: 20),
            if (_selectedImages.isNotEmpty) ...[
              _buildImageSection(
                'Ảnh mới',
                _selectedImages.length,
                _selectedImages,
                isNew: true,
              ),
              const SizedBox(height: 20),
            ],
            if (_existingImages.isNotEmpty) ...[
              _buildImageSection(
                'Ảnh hiện có',
                _existingImages.length,
                _existingImages.map((img) => img['url'] as String).toList(),
                isNew: false,
              ),
              const SizedBox(height: 20),
            ],
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Viết nội dung giới thiệu',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      centerTitle: false,
      backgroundColor: Colors.blue[700],
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: 'Tiêu đề',
          hintText: 'Nhập tiêu đề về công ty...',
          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.title, color: Colors.blue[700], size: 22),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _descriptionController,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Nội dung giới thiệu',
          hintText: 'Viết nội dung chi tiết về công ty, sứ mệnh, tầm nhìn...',
          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(Icons.description, color: Colors.blue[700], size: 22),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        maxLines: 8,
      ),
    );
  }

  Widget _buildPickImageButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue[700]!, width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue[50],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search, color: Colors.blue[700], size: 28),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  'Chọn ảnh từ thiết bị',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hỗ trợ JPG, PNG, GIF, WebP',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String title, int count, dynamic images, {required bool isNew}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$title ($count)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isNew ? Colors.blue[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isNew ? 'Chưa lưu' : 'Đã lưu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isNew ? Colors.blue[700] : Colors.green[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return _buildImageCard(index, images[index], isNew);
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(int index, dynamic imageData, bool isNew) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isNew
                ? Image.file(
              imageData as File,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
                : Image.network(
              imageData as String,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isNew) {
                  _selectedImages.removeAt(index);
                  AppSnackBar.show(
                    context,
                    AppSnackBar.info(message: 'Đã xóa ảnh mới'),
                  );
                } else {
                  _deleteImage(imageData as String);
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAboutUs,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            disabledBackgroundColor: Colors.grey[300],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          child: _isLoading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              strokeWidth: 2.5,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.save, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Lưu nội dung',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _previewAboutUs,
          icon: const Icon(Icons.visibility, size: 20),
          label: const Text('Xem trước trang Giới thiệu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}