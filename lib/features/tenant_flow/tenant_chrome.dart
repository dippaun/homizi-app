import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

/// One back chevron, a HOMIZI lockup or a title, and the page body.
class TenantFlowScaffold extends StatelessWidget {
  const TenantFlowScaffold({
    required this.pageKey,
    required this.onBack,
    required this.body,
    this.title,
    this.stepLabel,
    this.bottom,
    super.key,
  });

  final Key pageKey;
  final VoidCallback onBack;
  final Widget body;
  final String? title;
  final String? stepLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: HomiziBackButton(onPressed: onBack),
        title: title == null
            ? const BrandLockup(markSize: 28)
            : Text(
                homiziText(context, title!),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (stepLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: TenantStepChip(stepLabel!)),
            ),
        ],
      ),
      body: HomiziFrame(child: body),
      bottomNavigationBar: bottom == null
          ? null
          : Material(
              color: HomiziColors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

class TenantStepChip extends StatelessWidget {
  const TenantStepChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w800,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class TenantNextButton extends StatelessWidget {
  const TenantNextButton({
    required this.label,
    required this.onPressed,
    this.buttonKey = const Key('tenant-flow-next'),
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      child: Text(homiziText(context, label)),
    );
  }
}

class TenantSideToggle extends StatelessWidget {
  const TenantSideToggle({
    required this.side,
    required this.onChanged,
    super.key,
  });

  final MatchSide side;
  final ValueChanged<MatchSide> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomiziColors.mist,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SideChip(
              label: side == MatchSide.tenant ? "I'm a Tenant" : 'Tenant',
              selected: side == MatchSide.tenant,
              chipKey: const Key('tenant-side-tenant'),
              onTap: () => onChanged(MatchSide.tenant),
            ),
          ),
          Expanded(
            child: _SideChip(
              label: 'Host',
              selected: side == MatchSide.host,
              chipKey: const Key('tenant-side-host'),
              onTap: () => onChanged(MatchSide.host),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.label,
    required this.selected,
    required this.chipKey,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Key chipKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.accent : HomiziColors.clear,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            homiziText(context, label),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ),
    );
  }
}

class TenantPoint extends StatelessWidget {
  const TenantPoint({
    required this.icon,
    required this.label,
    required this.color,
    this.detail,
    this.iconColor = HomiziColors.ink,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, label),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                  ),
                ),
                if (detail != null)
                  Text(
                    homiziText(context, detail!),
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      fontFamily: 'Inter',
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TenantNumberedStep extends StatelessWidget {
  const TenantNumberedStep({
    required this.number,
    required this.title,
    required this.detail,
    this.icon,
    super.key,
  });

  final String number;
  final String title;
  final String detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: HomiziColors.accent,
            foregroundColor: HomiziColors.ink,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: HomiziColors.ink),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        homiziText(context, title),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  homiziText(context, detail),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontFamily: 'Inter',
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TenantMatchBadge extends StatelessWidget {
  const TenantMatchBadge({
    required this.percent,
    required this.importantMismatch,
    super.key,
  });

  final int percent;
  final bool importantMismatch;

  @override
  Widget build(BuildContext context) {
    final tone = matchFill(percent, importantMismatch: importantMismatch);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        homiziText(context, '$percent% Match'),
        style: TextStyle(
          color: tone.foreground,
          fontWeight: FontWeight.w800,
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
        ),
      ),
    );
  }
}

class TenantVerifiedBadge extends StatelessWidget {
  const TenantVerifiedBadge({super.key, this.label = 'Verified'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: HomiziColors.success),
          const SizedBox(width: 4),
          Text(
            homiziText(context, label),
            style: const TextStyle(
              color: HomiziColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class TenantScoreRing extends StatelessWidget {
  const TenantScoreRing({required this.percent, super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final tone = matchTone(percent);
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              strokeWidth: 12,
              backgroundColor: HomiziColors.mist,
              color: tone.bar,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class TenantStoryBox extends StatelessWidget {
  const TenantStoryBox({
    required this.title,
    required this.lines,
    required this.strength,
    super.key,
  });

  final String title;
  final List<String> lines;
  final MatchStrength strength;

  @override
  Widget build(BuildContext context) {
    final wash = switch (strength) {
      MatchStrength.strong => HomiziColors.successWash,
      MatchStrength.partial => HomiziColors.warningWash,
      MatchStrength.low => HomiziColors.errorWash,
    };
    final mark = switch (strength) {
      MatchStrength.strong => HomiziColors.success,
      MatchStrength.partial => HomiziColors.warning,
      MatchStrength.low => HomiziColors.error,
    };
    final icon = strength == MatchStrength.strong
        ? Icons.check_circle
        : Icons.info_outline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 6),
          if (lines.isEmpty)
            Text(
              homiziText(context, 'None'),
              style: const TextStyle(color: HomiziColors.ink),
            )
          else
            for (final line in lines.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: mark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        homiziText(context, line),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontFamily: 'Inter',
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class TenantFeatureStrip extends StatelessWidget {
  const TenantFeatureStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, Color, String, String)>[
      (
        Icons.star,
        HomiziColors.success,
        'Your Best Matches First',
        'Based on your priorities and compatibility score.',
      ),
      (
        Icons.verified_user,
        HomiziColors.accent,
        'Verified Listings & Users',
        'Aadhaar, face ID and photo verified.',
      ),
      (
        Icons.photo_library_outlined,
        HomiziColors.ink,
        'Mandatory Photo Sequence',
        'Room, Kitchen, WC, Hall, Balcony, Building exterior.',
      ),
      (
        Icons.notifications_active_outlined,
        HomiziColors.brandDeepOrange,
        'Instant Notifications',
        'Get notified of right swipe and new matches.',
      ),
      (
        Icons.event_available_outlined,
        HomiziColors.warning,
        'Schedule Visits',
        'Book property visits directly in the app.',
      ),
      (
        Icons.chat_bubble_outline,
        HomiziColors.success,
        'Chat After Match',
        'Secure in-app chat and option to share contact.',
      ),
    ];
    return Column(
      children: [
        for (final item in items)
          TenantPoint(
            icon: item.$1,
            label: item.$3,
            detail: item.$4,
            color: item.$2 == HomiziColors.warning
                ? HomiziColors.warningWash
                : item.$2 == HomiziColors.ink
                ? HomiziColors.mist
                : item.$2.withValues(alpha: 0.15),
            iconColor: item.$2 == HomiziColors.warning
                ? HomiziColors.warning
                : item.$2 == HomiziColors.success
                ? HomiziColors.success
                : HomiziColors.ink,
          ),
      ],
    );
  }
}
