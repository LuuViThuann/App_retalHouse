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

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        'Điều khoản thuê',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  // TextField chung
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    bool isRequired = false,
    required String? Function(String?)? validator,
  }) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hintText,
          labelStyle: const TextStyle(fontSize: 15, color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
          suffixText: suffixText,
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
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  // Dropdown phương thức thanh toán (full width)
  Widget _buildPaymentMethodDropdown() {
    const List<Map<String, dynamic>> paymentMethods = [
      {'label': 'Tiền mặt', 'icon': Icons.money_outlined, 'color': Colors.green},
      {'label': 'Chuyển khoản', 'icon': Icons.account_balance_outlined, 'color': Colors.blue},
    ];

    // Đặt giá trị mặc định nếu chưa có
    if (paymentMethodController.text.isEmpty) {
      paymentMethodController.text = paymentMethods[0]['label'];
    }

    return DropdownButtonFormField<String>(
      value: paymentMethods.any((e) => e['label'] == paymentMethodController.text)
          ? paymentMethodController.text
          : paymentMethods[0]['label'],
      decoration: InputDecoration(
        labelText: 'Phương thức thanh toán *',
        labelStyle: const TextStyle(fontSize: 15, color: Colors.grey),
        prefixIcon: const Icon(Icons.payment_outlined, color: Colors.grey, size: 22),
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
      items: paymentMethods.map((method) {
        return DropdownMenuItem<String>(
          value: method['label'],
          child: Row(
            children: [
              Icon(method['icon'], color: method['color'], size: 20),
              const SizedBox(width: 10),
              Text(method['label']),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) paymentMethodController.text = value;
      },
      validator: (value) => Validators.requiredField(value, 'phương thức thanh toán'),
      isExpanded: true,
      dropdownColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(),

        // Hàng 1: Thời hạn thuê + Tiền cọc (nằm ngang)
        Row(
          children: [
            _buildTextField(
              controller: minimumLeaseController,
              label: 'Thời hạn thuê tối thiểu',
              icon: Icons.timer_outlined,
              hintText: 'VD: 6 tháng, 1 năm',
              isRequired: true,
              validator: (value) => Validators.requiredField(value, 'thời hạn thuê'),
            ),
            const SizedBox(width: 14),
            _buildTextField(
              controller: depositController,
              label: 'Tiền cọc',
              icon: Icons.security_outlined,
              hintText: 'VD: 5.000.000',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                OptimizedThousandsFormatter(),
              ],
              suffixText: ' VNĐ',
              isRequired: true,
              validator: Validators.depositValidator,
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Phương thức thanh toán (full width)
        _buildPaymentMethodDropdown(),

        const SizedBox(height: 18),

        // Điều khoản gia hạn (full width, nhiều dòng)
        TextFormField(
          controller: renewalTermsController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Điều khoản gia hạn (nếu có)',
            hintText: 'Mô tả điều kiện gia hạn hợp đồng, phí, thời gian thông báo...',
            labelStyle: const TextStyle(fontSize: 15, color: Colors.grey),
            prefixIcon: const Icon(Icons.autorenew_outlined, color: Colors.grey, size: 22),
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
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}