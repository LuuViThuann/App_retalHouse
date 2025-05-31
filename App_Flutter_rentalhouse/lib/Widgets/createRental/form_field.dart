import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget buildSectionTitle(String title) {
  return Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(255, 9, 48, 81)!,
        ),
      ),
    ),
  );
}

Widget buildTextField({
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
  bool showClearButton = false,
  required BuildContext context,
}) {
  final lightBlue = const Color.fromARGB(255, 9, 48, 81)!;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$labelText *' : labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: lightBlue.withOpacity(0.8))
            : null,
        suffixIcon: showClearButton && controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  controller.clear();
                  (context as Element).markNeedsBuild();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: lightBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        suffixText: suffixText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) {
        (context as Element).markNeedsBuild();
      },
    ),
  );
}

Widget buildDropdownField({
  required String? value,
  required String labelText,
  required List<String> items,
  required IconData prefixIcon,
  required void Function(String?)? onChanged,
  String? Function(String?)? validator,
  bool isRequired = false,
  required BuildContext context,
}) {
  final lightBlue = const Color.fromARGB(255, 9, 48, 81)!;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: isRequired ? '$labelText *' : labelText,
        prefixIcon: Icon(prefixIcon, color: lightBlue.withOpacity(0.8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: lightBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
    ),
  );
}
