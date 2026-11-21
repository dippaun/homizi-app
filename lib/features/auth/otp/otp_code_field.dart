import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';

/// A 6-digit code field. Paste lands in the one text field.
///
/// [showBoxes] draws the digits in six separate boxes. The box being typed
/// into glows orange with a caret, each digit pops in, a wrong code turns
/// every box red and shakes the row, and [verified] turns them green.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    required this.controller,
    super.key,
    this.fieldKey = const Key('otp-field'),
    this.errorText,
    this.helperText,
    this.label = '6-digit code',
    this.showBoxes = false,
    this.autofocus = false,
    this.verified = false,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String? errorText;
  final String? helperText;
  final String label;
  final bool showBoxes;
  final bool autofocus;

  /// Paints the boxes green once the code is accepted.
  final bool verified;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final error = widget.errorText;
    if (widget.showBoxes && error != null && error != oldWidget.errorText) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxes = widget.showBoxes;
    final field = TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: 6,
      showCursor: !boxes,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(color: boxes ? HomiziColors.clear : HomiziColors.ink),
      decoration: boxes
          ? InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              helperText: widget.helperText,
              errorText: widget.errorText,
              errorMaxLines: 3,
              errorStyle: const TextStyle(
                color: HomiziColors.error,
                fontWeight: FontWeight.w600,
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            )
          : InputDecoration(
              labelText: widget.label,
              helperText: widget.helperText,
              errorText: widget.errorText,
              errorMaxLines: 3,
              counterText: '',
            ),
    );
    if (!boxes) {
      return field;
    }
    final hasError = widget.errorText != null;
    return Stack(
      children: [
        field,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 56,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final digits = otpDigits(value.text);
                  final focused = _focus.hasFocus;
                  return Row(
                    children: [
                      for (var index = 0; index < 6; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _OtpBox(
                            digit: index < digits.length ? digits[index] : '',
                            state: widget.verified
                                ? _BoxState.verified
                                : hasError
                                ? _BoxState.error
                                : focused &&
                                      (index == digits.length ||
                                          (digits.length == 6 && index == 5))
                                ? _BoxState.active
                                : index < digits.length
                                ? _BoxState.filled
                                : _BoxState.empty,
                            caret:
                                focused &&
                                !hasError &&
                                !widget.verified &&
                                index == digits.length,
                            boxKey: Key('otp-box-$index'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _BoxState { empty, active, filled, error, verified }

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.state,
    required this.caret,
    required this.boxKey,
  });

  final String digit;
  final _BoxState state;
  final bool caret;
  final Key boxKey;

  @override
  Widget build(BuildContext context) {
    final (fill, border, width) = switch (state) {
      _BoxState.empty => (HomiziColors.soft, HomiziColors.line, 1.0),
      _BoxState.active => (HomiziColors.white, HomiziColors.logoOrange, 2.0),
      _BoxState.filled => (HomiziColors.white, HomiziColors.ink, 1.2),
      _BoxState.error => (HomiziColors.errorWash, HomiziColors.error, 1.6),
      _BoxState.verified => (
        HomiziColors.successWash,
        HomiziColors.success,
        1.6,
      ),
    };
    final textColor = switch (state) {
      _BoxState.error => HomiziColors.error,
      _BoxState.verified => HomiziColors.success,
      _ => HomiziColors.ink,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 54,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: width),
        boxShadow: state == _BoxState.active
            ? const [
                BoxShadow(color: HomiziColors.accentHover, spreadRadius: 4),
              ]
            : const [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('digit-$digit'),
            tween: Tween(begin: digit.isEmpty ? 1 : 0.4, end: 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              digit,
              key: boxKey,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (caret && digit.isEmpty)
            Container(
              key: const Key('otp-caret'),
              width: 2,
              height: 22,
              decoration: BoxDecoration(
                color: HomiziColors.logoOrange,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
