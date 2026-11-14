import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/priorities/host_seeker_score.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_widgets.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';

/// WhatsApp and Call. Seekers' numbers are never on a public brief, so
/// both explain that and offer in-app chat instead of a wa.me / tel: link.
class SeekerContactButtons extends StatelessWidget {
  const SeekerContactButtons({
    required this.profile,
    required this.onChat,
    required this.keyPrefix,
    super.key,
  });

  final SeekerPublicProfile profile;
  final VoidCallback onChat;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: Key('$keyPrefix-whatsapp-${profile.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.success,
              foregroundColor: HomiziColors.onSuccess,
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => showSeekerContactSheet(
              context,
              profile: profile,
              channel: 'WhatsApp',
              onChat: onChat,
            ),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: Text(homiziText(context, 'WhatsApp')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: Key('$keyPrefix-call-${profile.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.brandDeepRed,
              side: const BorderSide(color: HomiziColors.brandRedOrange),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => showSeekerContactSheet(
              context,
              profile: profile,
              channel: 'a call',
              onChat: onChat,
            ),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text(homiziText(context, 'Call')),
          ),
        ),
      ],
    );
  }
}

Future<void> showSeekerContactSheet(
  BuildContext context, {
  required SeekerPublicProfile profile,
  required String channel,
  required VoidCallback onChat,
}) {
  final first = profile.name.split(' ').first;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: HomiziColors.white,
    builder: (sheet) => SafeArea(
      child: Padding(
        key: const Key('seeker-contact-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_outline,
              color: HomiziColors.logoOrange,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(sheet, '$first has not shared a number yet'),
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              homiziText(
                sheet,
                'Numbers stay hidden until you both connect and $first chooses to share one. Until then, $channel is replaced by HOMIZI chat.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('seeker-contact-chat'),
              style: FilledButton.styleFrom(
                backgroundColor: HomiziColors.logoOrange,
                foregroundColor: HomiziColors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () {
                Navigator.of(sheet).pop();
                onChat();
              },
              child: Text(homiziText(sheet, 'Message in HOMIZI')),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Top 5 priority match (your selection)" on a seeker's profile.
class SeekerPriorityBreakdown extends StatelessWidget {
  const SeekerPriorityBreakdown({required this.match, super.key});

  final HostPriorityMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seeker-priority-match'),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
              ),
            ),
            child: Text(
              homiziText(
                context,
                'Top ${match.lines.length} priority match (your selection)',
              ),
              style: const TextStyle(
                color: HomiziColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final line in match.lines)
            Padding(
              key: Key('seeker-priority-${hostCriterionWire(line.criterion)}'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  PriorityBadge(rank: line.rank),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      homiziText(context, hostCriterionTitle(line.criterion)),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      homiziText(context, line.value),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    line.matched
                        ? Icons.check_circle
                        : line.missed
                        ? Icons.cancel
                        : Icons.remove_circle_outline,
                    size: 20,
                    color: line.matched
                        ? HomiziColors.success
                        : line.missed
                        ? HomiziColors.error
                        : HomiziColors.warning,
                    semanticLabel: line.matched
                        ? 'Fits'
                        : line.missed
                        ? 'Does not fit'
                        : 'Partly fits or not shared',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
