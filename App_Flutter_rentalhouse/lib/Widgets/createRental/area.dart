import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';

// ===================== CUSTOM DECIMAL INPUT FORMATTER =====================
/// Formatter tối ưu cho số thập phân - Giảm lag khi gõ
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Nếu text rỗng, cho phép
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Kiểm tra chỉ có số và một dấu chấm
    final parts = newValue.text.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    // Giới hạn 2 chữ số sau dấu chấy
    if (parts.length == 2 && parts[1].length > 2) {
      return oldValue;
    }

    return newValue;
  }
}

// ===================== OPTIMIZED AREA FORM =====================
class AreaForm extends StatelessWidget {
  final TextEditingController totalController;
  final TextEditingController livingRoomController;
  final TextEditingController bedroomsController;
  final TextEditingController bathroomsController;

  const AreaForm({
    super.key,
    required this.totalController,
    required this.livingRoomController,
    required this.bedroomsController,
    required this.bathroomsController,
  });

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        'Diện tích (m²)',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Tối ưu: Build TextField một lần, tái sử dụng
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    required String? Function(String?)? validator,
  }) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        // Tối ưu: Giảm số lượng formatter
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          _DecimalInputFormatter(),
        ],
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: const TextStyle(fontSize: 15, color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: validator,
        textAlign: TextAlign.start,
        autocorrect: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(),

        // Hàng 1: Tổng diện tích + Phòng khách
        Row(
          children: [
            _buildTextField(
              controller: totalController,
              label: 'Tổng diện tích',
              icon: Icons.square_foot_outlined,
              isRequired: true,
              validator: (value) => Validators.areaValidator(value, 'tổng diện tích'),
            ),
            const SizedBox(width: 14),
            _buildTextField(
              controller: livingRoomController,
              label: 'Phòng khách',
              icon: Icons.living_outlined,
              validator: Validators.optionalAreaValidator,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Hàng 2: Phòng ngủ + Phòng tắm
        Row(
          children: [
            _buildTextField(
              controller: bedroomsController,
              label: 'Phòng ngủ',
              icon: Icons.bed_outlined,
              validator: Validators.optionalAreaValidator,
            ),
            const SizedBox(width: 14),
            _buildTextField(
              controller: bathroomsController,
              label: 'Phòng tắm',
              icon: Icons.bathtub_outlined,
              validator: Validators.optionalAreaValidator,
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}