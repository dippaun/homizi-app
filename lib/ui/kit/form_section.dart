import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// A soft, borderless section: left-aligned heading, optional icon, then the
/// fields. Errors are ink-red text under the heading.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.error,
    this.errorKey,
    this.icon,
    super.key,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final String? error;
  final Key? errorKey;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: HomiziColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomiziColors.logoOrange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: HomiziColors.logoOrange, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.25,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: HomiziColors.muted, height: 1.35),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              key: errorKey,
              style: const TextStyle(color: HomiziColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
