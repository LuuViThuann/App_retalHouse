import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/Widgets/createRental/validation_rental.dart';
import 'package:flutter_rentalhouse/Widgets/thousand_format.dart';

class RentalTermsForm extends StatelessWidget {
  final TextEditingController minimumLeaseController;
  final TextEditingController depositController;
  final TextEditingController paymentMethodController;
  final TextEditingController renewalTermsController;

  const RentalTermsForm({
    super.key,
    required this.minimumLeaseController,
    required this.depositController,
    required this.paymentMethodController,
    required this.renewalTermsController,
  });

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
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
    List<TextInputFormatter>? inputFormatters,
    int minLines = 1,
    int maxLines = 1,
    String? suffixText,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: Colors.grey[600],
                  size: 22,
                )
              : null,
          suffixText: suffixText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[800]!, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        validator: validator,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildPaymentMethodDropdown(BuildContext context) {
    const List<Map<String, dynamic>> paymentMethods = [
      {
        'label': 'Tiền mặt',
        'icon': Icons.money_outlined,
        'color': Colors.green
      },
      {
        'label': 'Thanh toán chuyển khoản',
        'icon': Icons.account_balance_outlined,
        'color': Colors.blue
      },
    ];

    if (paymentMethodController.text.isEmpty) {
      paymentMethodController.text = paymentMethods[0]['label'];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ValueListenableBuilder<String>(
        valueListenable: ValueNotifier<String>(paymentMethodController.text),
        builder: (context, value, child) {
          return DropdownButtonFormField<String>(
            value: paymentMethods.any((e) => e['label'] == value)
                ? value
                : paymentMethods[0]['label'],
            decoration: InputDecoration(
              labelText: 'Phương thức thanh toán *',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.payment_outlined,
                  color: Colors.grey[600], size: 22),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey[800]!, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: paymentMethods.map((method) {
              return DropdownMenuItem<String>(
                value: method['label'],
                child: Row(
                  children: [
                    Icon(method['icon'], color: method['color'], size: 20),
                    const SizedBox(width: 10),
                    Text(
                      method['label'],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                paymentMethodController.text = newValue;
              }
            },
            validator: (value) =>
                Validators.requiredField(value, 'phương thức thanh toán'),
            isExpanded: true,
            dropdownColor: Colors.white,
            style: TextStyle(color: Colors.grey[900], fontSize: 16),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Điều khoản thuê'),
        _buildTextField(
          context: context,
          controller: minimumLeaseController,
          labelText: 'Thời hạn thuê tối thiểu',
          hintText: 'VD: 6 tháng, 1 năm',
          prefixIcon: Icons.timer_outlined,
          isRequired: true,
          validator: (value) =>
              Validators.requiredField(value, 'thời hạn thuê'),
        ),
        _buildTextField(
          context: context,
          controller: depositController,
          labelText: 'Tiền cọc',
          hintText: 'Nhập số tiền, ví dụ: 100.000 VNĐ',
          prefixIcon: Icons.security_outlined,
          suffixText: 'VNĐ',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsFormatter(allowZero: true),
          ],
          isRequired: true,
          validator: Validators.depositValidator,
        ),
        _buildPaymentMethodDropdown(context),
        _buildTextField(
          context: context,
          controller: renewalTermsController,
          labelText: 'Điều khoản gia hạn (nếu có)',
          hintText: 'Mô tả điều kiện, quy trình gia hạn hợp đồng',
          prefixIcon: Icons.autorenew_outlined,
          minLines: 2,
          maxLines: 3,
        ),
      ],
    );
  }
}
