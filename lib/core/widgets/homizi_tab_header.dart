import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Tab bar row: an optional back control, the HOMIZI wordmark, and the bell.
///
/// The side slots are equal, so the wordmark stays centred when the right
/// side holds the notification bell and the left side is empty.
class HomiziTabHeader extends StatelessWidget {
  const HomiziTabHeader({
    this.leading,
    this.actions = const [],
    this.title,
    super.key,
  });

  final Widget? leading;
  final List<Widget> actions;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [?leading],
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: title ?? const HomiziWordmark(),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [...actions],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred HOMIZI wordmark used on the tab headers.
class HomiziWordmark extends StatelessWidget {
  const HomiziWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final word = homiziText(context, 'HOMIZI');
    const style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: HomiziColors.ink,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziSquareMark(size: 28),
        const SizedBox(width: 8),
        word == 'HOMIZI'
            ? Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    const TextSpan(text: 'H'),
                    TextSpan(
                      text: 'O',
                      style: style.copyWith(color: HomiziColors.accent),
                    ),
                    const TextSpan(text: 'MIZI'),
                  ],
                ),
              )
            : Text(word, style: style),
      ],
    );
  }
}
