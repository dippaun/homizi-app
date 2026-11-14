import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';

/// A 6-digit code field. Paste lands in the one text field.
///
/// [showBoxes] draws the digits in six boxes. The sign-in page leaves that
/// off so the page keeps the height the rest of the app was built around.
/// The mobile verification screen turns it on.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    required this.controller,
    super.key,
    this.fieldKey = const Key('otp-field'),
    this.errorText,
    this.helperText,
    this.label = '6-digit code',
    this.showBoxes = false,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String? errorText;
  final String? helperText;
  final String label;
  final bool showBoxes;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(
        color: showBoxes ? HomiziColors.clear : HomiziColors.ink,
      ),
      decoration: InputDecoration(
        labelText: showBoxes ? null : label,
        helperText: helperText,
        errorText: errorText,
        errorMaxLines: 3,
        counterText: '',
      ),
    );
    if (!showBoxes) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final digits = otpDigits(value.text);
            return Row(
              children: [
                for (var index = 0; index < 6; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _OtpBox(
                      digit: index < digits.length ? digits[index] : '',
                      filled: index < digits.length,
                      boxKey: Key('otp-box-$index'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.filled,
    required this.boxKey,
  });

  final String digit;
  final bool filled;
  final Key boxKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled ? HomiziColors.logoOrange : HomiziColors.line,
          width: filled ? 2 : 1,
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(
            digit,
            key: boxKey,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
