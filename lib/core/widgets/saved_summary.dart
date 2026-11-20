import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Shown while saved preferences are read. Never the input form.
class PrefsSkeleton extends StatelessWidget {
  const PrefsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('prefs-skeleton'),
      color: HomiziColors.white,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: HomiziColors.logoOrange,
          ),
        ),
      ),
    );
  }
}

/// "Preferences saved ✓ – Edit" once a form has already been saved.
class SavedSummaryCard extends StatelessWidget {
  const SavedSummaryCard({
    required this.title,
    required this.onEdit,
    this.prompt = 'Wanna change?',
    this.lines = const [],
    this.editLabel = 'Edit',
    super.key,
  });

  final String title;
  final String prompt;
  final List<String> lines;
  final String editLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        key: const Key('saved-summary-card'),
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: HomiziColors.success,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('saved-summary-edit'),
                    onPressed: onEdit,
                    child: Text(
                      homiziText(context, editLabel),
                      style: const TextStyle(
                        color: HomiziColors.logoOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  homiziText(context, prompt),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final line in lines)
                  if (line.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 30, top: 4),
                      child: Text(
                        homiziText(context, line),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
