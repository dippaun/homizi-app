import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// Public legal page. The banner text is the review marker for every page.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;

  static const draftBanner = 'Draft, pending legal review';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLockup(markSize: 28),
            const SizedBox(height: 16),
            Container(
              key: const Key('legal-draft-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: HomiziColors.accentWash,
              child: Text(
                draftBanner,
                style: text.titleSmall?.copyWith(color: HomiziColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Policy version 2026-10-11-draft. This page describes the current build. It is not legal advice and it is not approved.',
              style: text.bodyMedium?.copyWith(color: HomiziColors.muted),
            ),
            const SizedBox(height: 16),
            Text(intro, style: text.bodyLarge),
            for (final section in sections) ...[
              const SizedBox(height: 20),
              Text(section.heading, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(section.body, style: text.bodyMedium),
            ],
            const SizedBox(height: 28),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Link(label: 'Privacy', path: RoutePaths.privacy),
                _Link(label: 'Terms', path: RoutePaths.terms),
                _Link(label: 'Support', path: RoutePaths.support),
                _Link(label: 'Delete account', path: RoutePaths.deleteAccount),
                _Link(label: 'Open HOMIZI', path: RoutePaths.welcome),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.go(path),
      child: Text(label),
    );
  }
}
