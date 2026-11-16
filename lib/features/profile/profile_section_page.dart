import 'package:flutter/material.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Full-screen editor for one profile section.
///
/// One back control returns without saving. Save is the sticky button.
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
    return ContentScaffold(
      shotKey: const Key('profile-section-shot'),
      scaffoldKey: const Key('profile-section-page'),
      title: title,
      pageId: 'profile-$title',
      onBack: () => Navigator.of(context).pop(false),
      primaryLabel: 'Save',
      primaryKey: const Key('profile-edit-save'),
      onPrimary: () => Navigator.of(context).pop(true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FormSection(title: title, icon: RealLifeIcons.person, child: child),
        ],
      ),
    );
  }
}
