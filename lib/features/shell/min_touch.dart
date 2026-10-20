import 'package:flutter/material.dart';

/// Minimum interactive size for controls on the accessibility pass.
const double kMinTouchTarget = 48;

ButtonStyle minTouchIconStyle([ButtonStyle? style]) {
  final base = IconButton.styleFrom(
    minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
  if (style == null) {
    return base;
  }
  return base.merge(style);
}

ButtonStyle minTouchButtonStyle([ButtonStyle? style]) {
  const floor = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(kMinTouchTarget, kMinTouchTarget)),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
  if (style == null) {
    return floor;
  }
  return floor.merge(style);
}

/// Grows buttons and chips to 48dp. Colours stay on the surrounding theme.
ThemeData withMinTouchTargets(ThemeData theme) {
  return theme.copyWith(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: minTouchIconStyle(theme.iconButtonTheme.style),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: minTouchButtonStyle(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: minTouchButtonStyle(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: minTouchButtonStyle(theme.textButtonTheme.style),
    ),
  );
}

/// Zero while the system asks for reduced motion. Otherwise [duration].
Duration motionDuration(BuildContext context, Duration duration) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Duration.zero;
  }
  return duration;
}

/// Wraps [child] so buttons and chips on that screen meet [kMinTouchTarget].
class MinTouchScope extends StatelessWidget {
  const MinTouchScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: withMinTouchTargets(Theme.of(context)), child: child);
  }
}

/// Speaks [message] when it appears, and shows it.
class LiveNotice extends StatelessWidget {
  const LiveNotice({
    required this.message,
    this.isError = false,
    this.textKey,
    super.key,
  });

  final String message;
  final bool isError;

  /// When a test or a screen reader target needs the sentence itself.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Text(
        message,
        key: textKey,
        style: isError
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
    );
  }
}

/// Speaks [message] without painting a second copy of text already on a field.
class LiveLabel extends StatelessWidget {
  const LiveLabel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: const SizedBox(width: double.infinity, height: 1),
    );
  }
}
