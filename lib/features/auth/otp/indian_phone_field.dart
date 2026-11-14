import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/homizi_fields.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';

/// Mobile field with a fixed +91 prefix. The controller holds the 10 digits.
class IndianPhoneField extends StatelessWidget {
  const IndianPhoneField({
    required this.controller,
    super.key,
    this.errorText,
    this.fieldKey = const Key('phone-field'),
  });

  final TextEditingController controller;
  final String? errorText;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        _IndianMobileFormatter(),
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(color: HomiziColors.ink),
      decoration: homiziFieldDecoration(
        labelText: 'Mobile number',
        hintText: '98765 43210',
        errorText: errorText,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              indianCallingCode,
              key: Key('phone-prefix'),
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 48,
        ),
      ),
    );
  }
}

class _IndianMobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final national =
        indianMobileNational(newValue.text) ??
        newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = national.length > 10 ? national.substring(0, 10) : national;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
