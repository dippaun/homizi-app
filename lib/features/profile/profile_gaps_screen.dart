import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/profile/profile_dashboard_model.dart';

/// Lists only the profile fields that are still empty.
///
/// Each tile opens the editor for that field. Saved values stay put; this
/// page rebuilds from [readScore] after the editor closes.
class ProfileGapsScreen extends StatefulWidget {
  const ProfileGapsScreen({
    required this.readScore,
    required this.onOpen,
    super.key,
  });

  final ProfileCompleteness Function() readScore;
  final Future<void> Function(ProfileGap gap) onOpen;

  @override
  State<ProfileGapsScreen> createState() => _ProfileGapsScreenState();
}

class _ProfileGapsScreenState extends State<ProfileGapsScreen> {
  var _busy = false;

  Future<void> _open(ProfileGap gap) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await widget.onOpen(gap);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.readScore();
    final gaps = score.gaps;
    return Scaffold(
      key: const Key('profile-gaps-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        title: Text(homiziText(context, 'Finish your profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(context, '${score.percent}%'),
            key: const Key('profile-gaps-percent'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: HomiziColors.logoOrange,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(99)),
            child: LinearProgressIndicator(
              value: score.percent / 100,
              minHeight: 6,
              color: score.complete
                  ? HomiziColors.success
                  : HomiziColors.logoOrange,
              backgroundColor: HomiziColors.line,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              score.complete
                  ? 'Profile complete ✓'
                  : 'These are the only details still missing. Saved answers stay as they are.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (gaps.isEmpty)
            const ListTile(
              key: Key('profile-gaps-done'),
              leading: Icon(Icons.check_circle, color: HomiziColors.success),
              title: Text('Profile complete ✓'),
            )
          else
            for (final gap in gaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: HomiziColors.soft,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    key: Key('profile-gap-${gap.field}'),
                    enabled: !_busy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      homiziText(context, profileGapTitle(gap)),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(homiziText(context, profileGapDetail(gap))),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(gap),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
