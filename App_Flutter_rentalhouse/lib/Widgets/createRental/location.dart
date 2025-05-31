import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';

class LocationForm extends StatelessWidget {
  final TextEditingController shortController;
  final TextEditingController fullAddressController;

  const LocationForm({
    super.key,
    required this.shortController,
    required this.fullAddressController,
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
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isRequired = false,
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
        minLines: minLines,
        maxLines: maxLines,
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
        _buildSectionTitle(context, 'Vị trí'),
        _buildTextField(
          context: context,
          controller: shortController,
          labelText: 'Vị trí ngắn gọn',
          hintText: 'VD: Đường Nguyễn Văn Cừ, Quận Ninh Kiều',
          prefixIcon: Icons.location_on_outlined,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'vị trí'),
        ),
        _buildTextField(
          context: context,
          controller: fullAddressController,
          labelText: 'Địa chỉ đầy đủ',
          hintText: 'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành phố',
          prefixIcon: Icons.maps_home_work_outlined,
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          validator: (value) =>
              Validators.requiredField(value, 'địa chỉ đầy đủ'),
        ),
      ],
    );
  }
}
