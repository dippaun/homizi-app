import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

/// Dark green on white, used for verified checks. Labels stay near-black.
const profileVerifiedGreen = Color(0xFF0D6B3A);

const profileVerifiedWash = Color(0xFFE6F6EC);

class ProfileCreateLogo extends StatelessWidget {
  const ProfileCreateLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: HomiziColors.accent,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziMark(size: 32),
        const SizedBox(width: 8),
        Text(homiziText(context, 'HOMIZI'), style: style),
      ],
    );
  }
}

class ProfileCreateProgress extends StatelessWidget {
  const ProfileCreateProgress({required this.step, super.key});

  /// Zero-based step. The completed screen fills every segment.
  final int step;

  @override
  Widget build(BuildContext context) {
    final filled = step >= 4 ? 5 : step + 1;
    return Semantics(
      label: 'Step ${step + 1} of 5',
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < filled ? HomiziColors.accent : HomiziColors.line,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: const SizedBox(height: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration profileFieldDecoration(
  BuildContext context, {
  required String label,
  String? error,
  String? hint,
  String? helper,
  String? prefix,
}) {
  const radius = BorderRadius.all(Radius.circular(16));
  return InputDecoration(
    labelText: homiziText(context, label),
    hintText: hint == null ? null : homiziText(context, hint),
    helperText: helper == null ? null : homiziText(context, helper),
    errorText: error == null ? null : homiziText(context, error),
    prefixText: prefix,
    filled: true,
    fillColor: HomiziColors.mist,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.line),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.line),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.accent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class ProfileCreateButton extends StatelessWidget {
  const ProfileCreateButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: HomiziColors.ink,
      fontWeight: FontWeight.w700,
    );
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        key: const Key('profile-create-continue'),
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.accent,
          foregroundColor: HomiziColors.ink,
          disabledBackgroundColor: HomiziColors.accent.withValues(alpha: 0.5),
          disabledForegroundColor: HomiziColors.ink,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: style,
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HomiziColors.ink,
                ),
              )
            : Text(homiziText(context, label)),
      ),
    );
  }
}

class ProfileCheckLine extends StatelessWidget {
  const ProfileCheckLine({
    required this.label,
    required this.color,
    this.iconKey,
    super.key,
  });

  final String label;
  final Color color;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, key: iconKey, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(context, label),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic sun. This is not the Aadhaar emblem.
class ProfileSunburst extends StatelessWidget {
  const ProfileSunburst({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(painter: _SunburstPainter()),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.46;
    final inner = size.shortestSide * 0.28;
    final ray = Paint()
      ..color = HomiziColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2 - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        ray,
      );
    }
    canvas.drawCircle(
      center,
      inner * 0.72,
      Paint()..color = HomiziColors.accent,
    );
    canvas.drawCircle(
      center,
      inner * 0.36,
      Paint()..color = HomiziColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<int?> pickBirthYear(BuildContext context, int? current) {
  return showDialog<int>(
    context: context,
    builder: (context) => _BirthYearDialog(current: current),
  );
}

class _BirthYearDialog extends StatelessWidget {
  const _BirthYearDialog({required this.current});

  final int? current;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final latest = latestBirthYear(today);
    final earliest = earliestBirthYear(today);
    final count = latest - earliest + 1;
    return AlertDialog(
      title: Text(homiziText(context, 'Year of birth')),
      content: SizedBox(
        width: 320,
        height: 320,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final year = latest - index;
            final selected = year == current;
            return OutlinedButton(
              key: Key('birth-year-$year'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomiziColors.ink,
                backgroundColor: selected
                    ? HomiziColors.accentWash
                    : HomiziColors.white,
                side: BorderSide(
                  color: selected ? HomiziColors.accent : HomiziColors.line,
                  width: selected ? 2 : 1,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: () => Navigator.pop(context, year),
              child: Text('$year'),
            );
          },
        ),
      ),
    );
  }
}
