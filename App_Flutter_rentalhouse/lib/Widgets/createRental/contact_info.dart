import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';

class ContactInfoForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController availableHoursController;

  const ContactInfoForm({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.availableHoursController,
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
    String? hintText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isRequired = false,
    bool showClearButton = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon,
                  color: Theme.of(context).primaryColor.withOpacity(0.8))
              : null,
          suffixIcon: showClearButton && controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => controller.clear(),
                )
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
        keyboardType: keyboardType,
        validator: validator,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Thông tin liên hệ'),
        _buildTextField(
          context: context,
          controller: nameController,
          labelText: 'Tên người liên hệ',
          prefixIcon: Icons.person_outline,
          isRequired: true,
          showClearButton: true,
          validator: (value) =>
              Validators.requiredField(value, 'tên người liên hệ'),
        ),
        _buildTextField(
          context: context,
          controller: phoneController,
          labelText: 'Số điện thoại/Zalo',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          isRequired: true,
          showClearButton: true,
          validator: Validators.phoneValidator,
        ),
        _buildTextField(
          context: context,
          controller: availableHoursController,
          labelText: 'Giờ liên hệ thuận tiện',
          hintText: 'VD: 9:00 - 20:00, hoặc ghi chú cụ thể',
          prefixIcon: Icons.access_time_outlined,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'giờ liên hệ'),
        ),
      ],
    );
  }
}
