import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/choice.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';
import 'package:flutter_rentalhouse/Widgets/thousand_format.dart';

class BasicInfoForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController priceController;
  final ValueNotifier<String> statusNotifier;

  const BasicInfoForm({
    super.key,
    required this.titleController,
    required this.priceController,
    required this.statusNotifier,
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
    List<TextInputFormatter>? inputFormatters,
    int minLines = 1,
    int maxLines = 1,
    String? suffixText,
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
          suffixText: suffixText,
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
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Thông tin cơ bản'),
        _buildTextField(
          context: context,
          controller: titleController,
          labelText: 'Tiêu đề bài đăng',
          hintText: 'VD: Cho thuê căn hộ 2PN full nội thất gần trung tâm',
          prefixIcon: Icons.text_fields_rounded,
          isRequired: true,
          validator: (value) => Validators.requiredField(value, 'tiêu đề'),
        ),
        _buildTextField(
          context: context,
          controller: priceController,
          labelText: 'Giá thuê',
          hintText: 'Nhập số tiền, ví dụ: 5000000',
          prefixIcon: Icons.monetization_on_outlined,
          suffixText: 'VNĐ/tháng',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsFormatter(),
          ],
          isRequired: true,
          validator: Validators.priceValidator,
        ),
        _buildSectionTitle(context, 'Trạng thái bài đăng'),
        ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (context, value, child) {
            return DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                labelText: 'Trạng thái *',
                prefixIcon: Icon(Icons.info_outline,
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
              items: RentalConstants.statusOptionsVietnamese.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (newValue) =>
                  statusNotifier.value = newValue ?? 'Đang hoạt động',
              validator: (value) =>
                  Validators.requiredField(value, 'trạng thái'),
              isExpanded: true,
            );
          },
        ),
      ],
    );
  }
}
