import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';

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
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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