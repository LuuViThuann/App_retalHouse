import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/choice.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';

class PropertyDetailsForm extends StatelessWidget {
  final ValueNotifier<String?> propertyTypeNotifier;
  final TextEditingController furnitureController;
  final TextEditingController amenitiesController;
  final TextEditingController surroundingsController;

  const PropertyDetailsForm({
    super.key,
    required this.propertyTypeNotifier,
    required this.furnitureController,
    required this.amenitiesController,
    required this.surroundingsController,
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
        _buildSectionTitle(context, 'Chi tiết bất động sản'),
        ValueListenableBuilder<String?>(
          valueListenable: propertyTypeNotifier,
          builder: (context, value, child) {
            return DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                labelText: 'Loại hình bất động sản *',
                prefixIcon: Icon(Icons.business_outlined,
                    color: Theme.of(context).primaryColor.withOpacity(0.8)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: RentalConstants.propertyTypes.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (newValue) => propertyTypeNotifier.value = newValue,
              validator: (value) =>
                  Validators.requiredField(value, 'loại hình'),
              isExpanded: true,
            );
          },
        ),
        _buildTextField(
          context: context,
          controller: furnitureController,
          labelText: 'Nội thất',
          hintText:
              'Liệt kê các nội thất, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Giường, tủ, máy lạnh, bàn ghế',
          prefixIcon: Icons.chair_outlined,
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'nội thất'),
        ),
        _buildTextField(
          context: context,
          controller: amenitiesController,
          labelText: 'Tiện ích',
          hintText:
              'Liệt kê các tiện ích, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Wifi, Chỗ để xe, Thang máy, An ninh 24/7',
          prefixIcon: Icons.widgets_outlined,
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'tiện ích'),
        ),
        _buildTextField(
          context: context,
          controller: surroundingsController,
          labelText: 'Môi trường xung quanh',
          hintText:
              'Liệt kê các đặc điểm xung quanh, mỗi mục cách nhau bằng dấu phẩy (,)\nVD: Gần chợ, siêu thị, trường học, công viên',
          prefixIcon: Icons.nature_people_outlined,
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          validator: (value) =>
              Validators.requiredField(value, 'môi trường xung quanh'),
        ),
      ],
    );
  }
}
