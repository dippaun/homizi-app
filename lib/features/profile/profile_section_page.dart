import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Full-screen editor for one profile section.
///
/// One back control returns without saving. Save closes the page and the
/// caller shows the confirmation.
class ProfileSectionPage extends StatelessWidget {
  const ProfileSectionPage({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('profile-section-shot'),
      child: Scaffold(
        key: const Key('profile-section-page'),
        backgroundColor: HomiziColors.soft,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          leading: HomiziBackButton(
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: Text(
            homiziText(context, title),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            TextButton(
              key: const Key('profile-edit-save'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                homiziText(context, 'Save'),
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HomiziColors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
