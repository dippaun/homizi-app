import 'package:flutter/material.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Full-screen editor for one profile section.
///
/// One back control returns without saving. Save is the sticky button.
/// [revealKey] scrolls that field into view so Complete now opens the gap.
class ProfileSectionPage extends StatefulWidget {
  const ProfileSectionPage({
    required this.title,
    required this.child,
    this.revealKey,
    super.key,
  });

  final String title;
  final Widget child;
  final GlobalKey? revealKey;

  @override
  State<ProfileSectionPage> createState() => _ProfileSectionPageState();
}

class _ProfileSectionPageState extends State<ProfileSectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    final target = widget.revealKey?.currentContext;
    if (target == null || !target.mounted) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentScaffold(
      shotKey: const Key('profile-section-shot'),
      scaffoldKey: const Key('profile-section-page'),
      title: widget.title,
      pageId: 'profile-${widget.title}',
      onBack: () => Navigator.of(context).pop(false),
      primaryLabel: 'Save',
      primaryKey: const Key('profile-edit-save'),
      onPrimary: () => Navigator.of(context).pop(true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          FormSection(
            title: widget.title,
            icon: RealLifeIcons.person,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
