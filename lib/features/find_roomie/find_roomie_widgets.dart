import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';

/// One entry on the Roommate tab. The home card stays on the finder.
class FindRoomieEntryLink extends StatelessWidget {
  const FindRoomieEntryLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('find-roomie-entry'),
        onPressed: () => context.push(FindRoomiePaths.connect),
        icon: const Icon(
          Icons.diversity_3_outlined,
          color: HomiziColors.logoOrange,
        ),
        label: Text(homiziText(context, 'Find Your Roomie')),
        style: TextButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class FindRoomiePage extends StatelessWidget {
  const FindRoomiePage({
    required this.title,
    required this.shotKey,
    required this.body,
    this.bottom,
    super.key,
  });

  final String title;
  final Key shotKey;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: shotKey,
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, title)),
        ),
        body: body,
        bottomNavigationBar: bottom,
      ),
    );
  }
}

class FindRoomiePercent extends StatelessWidget {
  const FindRoomiePercent({
    required this.personId,
    required this.percent,
    super.key,
  });

  final String personId;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomiziColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        homiziText(context, '$percent%'),
        key: Key('find-roomie-percent-$personId'),
        style: const TextStyle(
          color: HomiziColors.onSuccess,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class FindRoomieSampleChip extends StatelessWidget {
  const FindRoomieSampleChip({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('find-roomie-sample'),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          homiziText(context, 'Sample'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class FindRoomieVerified extends StatelessWidget {
  const FindRoomieVerified({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 16, color: HomiziColors.success),
            const SizedBox(width: 4),
            Text(
              homiziText(context, 'Verified'),
              style: const TextStyle(
                color: HomiziColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FindRoomieButton extends StatelessWidget {
  const FindRoomieButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.buttonKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
              ),
        color: onPressed == null ? HomiziColors.line : null,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        color: HomiziColors.clear,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: HomiziColors.ink, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      homiziText(context, label),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FindRoomiePhoto extends StatelessWidget {
  const FindRoomiePhoto({
    required this.reference,
    this.height = 220,
    super.key,
  });

  final String? reference;
  final double height;

  @override
  Widget build(BuildContext context) {
    final path = reference?.trim() ?? '';
    final child = path.startsWith('assets/')
        ? Image.asset(
            path,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: HomiziColors.soft),
          )
        : const ColoredBox(color: HomiziColors.soft);
    return SizedBox(height: height, width: double.infinity, child: child);
  }
}
