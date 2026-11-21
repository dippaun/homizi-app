import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Titled block for a single scrolling page.
///
/// The header carries an icon and a count. An empty block keeps a short line
/// so the section stays on the page.
class SplitSection extends StatelessWidget {
  const SplitSection({
    required this.sectionKey,
    required this.icon,
    required this.title,
    required this.count,
    required this.tint,
    required this.accent,
    required this.emptyLine,
    required this.children,
    super.key,
  });

  final Key sectionKey;
  final IconData icon;
  final String title;
  final int count;
  final Color tint;
  final Color accent;
  final String emptyLine;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomiziColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: HomiziColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Text(
                homiziText(context, emptyLine),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  height: 1.35,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
