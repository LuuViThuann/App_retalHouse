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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon,
                  color: Theme.of(context).primaryColor.withOpacity(0.8))
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Diện tích (m²)'),
        _buildTextField(
          context: context,
          controller: totalController,
          labelText: 'Tổng diện tích',
          prefixIcon: Icons.square_foot_outlined,
          isRequired: true,
          validator: (value) =>
              Validators.areaValidator(value, 'tổng diện tích'),
        ),
        _buildTextField(
          context: context,
          controller: livingRoomController,
          labelText: 'Diện tích phòng khách (nếu có)',
          prefixIcon: Icons.living_outlined,
          validator: Validators.optionalAreaValidator,
        ),
        _buildTextField(
          context: context,
          controller: bedroomsController,
          labelText: 'Diện tích phòng ngủ (nếu có)',
          prefixIcon: Icons.bed_outlined,
          validator: Validators.optionalAreaValidator,
        ),
        _buildTextField(
          context: context,
          controller: bathroomsController,
          labelText: 'Diện tích phòng tắm (nếu có)',
          prefixIcon: Icons.bathtub_outlined,
          validator: Validators.optionalAreaValidator,
        ),
      ],
    );
  }
}
