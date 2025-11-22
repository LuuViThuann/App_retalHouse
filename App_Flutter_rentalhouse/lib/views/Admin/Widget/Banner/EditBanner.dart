import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/viewmodels/vm_auth.dart';
import 'package:flutter_rentalhouse/views/Admin/Service/banner.dart';
import 'package:flutter_rentalhouse/views/Admin/model/banner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// ==================== EDIT BANNER SCREEN ====================
class EditBannerScreen extends StatefulWidget {
  final BannerModel banner;
  final VoidCallback onBannerUpdated;

  const EditBannerScreen({
    required this.banner,
    required this.onBannerUpdated,
    super.key,
  });

  @override
  State<EditBannerScreen> createState() => _EditBannerScreenState();
}

class _EditBannerScreenState extends State<EditBannerScreen> {
  final BannerService _bannerService = BannerService();
  final ImagePicker _imagePicker = ImagePicker();

  File? selectedImage;
  late TextEditingController titleController;
  late TextEditingController descController;
  late TextEditingController linkController;
  late TextEditingController positionController;
  late bool isActive;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.banner.title);
    descController = TextEditingController(text: widget.banner.description);
    linkController = TextEditingController(text: widget.banner.link ?? '');
    positionController =
        TextEditingController(text: widget.banner.position.toString());
    isActive = widget.banner.isActive;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar('Lỗi chọn ảnh: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _updateBanner() async {
    setState(() => isLoading = true);
    try {
      final token =
          Provider.of<AuthViewModel>(context, listen: false).currentUser?.token;
      if (token != null) {
        await _bannerService.updateBanner(
          bannerId: widget.banner.id,
          title: titleController.text,
          description: descController.text,
          link: linkController.text,
          position: int.tryParse(positionController.text) ?? 0,
          isActive: isActive,
          imageFile: selectedImage,
          token: token,
        );
        _showSnackBar('Cập nhật banner thành công');
        widget.onBannerUpdated();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Lỗi cập nhật banner: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    linkController.dispose();
    positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chỉnh sửa Banner'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image Picker Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue[300]!,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: selectedImage == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                widget.banner.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.black.withOpacity(0.3),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 30,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Nhấn để đổi ảnh',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedImage = null),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // Title Field
              _buildTextField(
                controller: titleController,
                label: 'Tiêu đề',
                hint: 'Nhập tiêu đề banner',
                icon: Icons.title,
              ),
              const SizedBox(height: 16),

              // Description Field
              _buildTextField(
                controller: descController,
                label: 'Mô tả',
                hint: 'Nhập mô tả banner',
                icon: Icons.description,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Link Field
              _buildTextField(
                controller: linkController,
                label: 'Link (Tùy chọn)',
                hint: 'https://example.com',
                icon: Icons.link,
              ),
              const SizedBox(height: 16),

              // Position Field
              _buildTextField(
                controller: positionController,
                label: 'Vị trí (0-999)',
                hint: '0',
                icon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Active Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Text(
                          'Kích hoạt banner',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _updateBanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Cập nhật Banner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blue[700]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
