import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

/// "Choose your match" (individual or group), then "Send join request".
class JoinRequestScreen extends ConsumerStatefulWidget {
  const JoinRequestScreen({required this.homeId, super.key});

  final String homeId;

  @override
  ConsumerState<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends ConsumerState<JoinRequestScreen> {
  var _choosing = true;
  JoinMode? _mode;
  var _group = 2;
  var _busy = false;
  String? _problem;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    final need = ref.read(occupancyNeedProvider);
    _group = need.groupSize;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    if (!_choosing) {
      setState(() {
        _choosing = true;
        _problem = null;
      });
      return;
    }
    HomiziBackButton.leave(context);
  }

  Future<void> _send(SharedHome home, OccupancyNeed need) async {
    final mode = _mode ?? JoinMode.individual;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final result = await ref
        .read(joinRequestsProvider.notifier)
        .send(
          home: home,
          need: need,
          mode: mode,
          people: mode == JoinMode.group ? _group : 1,
          firstName: _name.text.trim(),
        );
    if (!mounted) {
      return;
    }
    final request = result.request;
    if (request == null) {
      setState(() {
        _busy = false;
        _problem =
            result.problem ?? 'The request did not go through. Try again.';
      });
      return;
    }
    context.pushReplacement(SharedHomePaths.request(request.id));
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(sharedHomesProvider).byId(widget.homeId);
    final need = ref.watch(occupancyNeedProvider);
    return PopScope(
      canPop: _choosing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _back();
        }
      },
      child: Scaffold(
        key: const Key('join-screen'),
        backgroundColor: HomiziColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: HomiziBackButton(onPressed: _back),
          title: Text(
            homiziText(
              context,
              _choosing ? 'Choose your match' : 'Send join request',
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: home == null
              ? const EmptyState(
                  title: 'This home is not available',
                  message: 'It may have been rented or taken down.',
                )
              : (_choosing ? _choose(home, need) : _confirm(home, need)),
        ),
      ),
    );
  }

  Widget _choose(SharedHome home, OccupancyNeed need) {
    final alone = canJoinAlone(home);
    final maxGroup = maxGroupSize(home);
    final groupOk = maxGroup >= 2;
    final group = _group.clamp(2, groupOk ? maxGroup : 2);
    final selected =
        _mode ??
        (need.mode == JoinMode.group && groupOk
            ? JoinMode.group
            : (alone ? JoinMode.individual : null));
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('join-choose-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          '${home.tag} · ${home.place}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${home.occupancy.vacantLine} · ${home.occupancy.livingLine} ${homiziText(context, 'living')}',
        ),
        const SizedBox(height: 16),
        _Option(
          optionKey: const Key('join-individual'),
          icon: Icons.person,
          title: 'Join as an individual',
          body: home.occupancy.type == HostOccupancy.double
              ? 'Take 1 place and join the shared home.'
              : 'Take 1 vacant room and join the shared home.',
          selected: selected == JoinMode.individual,
          enabled: alone,
          color: HomiziColors.accentWash,
          onTap: () => setState(() => _mode = JoinMode.individual),
        ),
        const SizedBox(height: 12),
        _Option(
          optionKey: const Key('join-group'),
          icon: Icons.groups,
          title: groupOk
              ? 'Join as a group ($group people)'
              : 'Join as a group',
          body: groupOk
              ? (group == 2
                    ? 'You and your friend can take ${home.occupancy.type == HostOccupancy.double
                          ? 'two places'
                          : (home.occupancy.vacantRooms ?? 0) == 2
                          ? 'both vacant rooms'
                          : 'two vacant rooms'} together.'
                    : 'You and ${group - 1} friends can move in together.')
              : 'Only one place is free in this home.',
          selected: selected == JoinMode.group,
          enabled: groupOk,
          color: HomiziColors.soft,
          onTap: () => setState(() => _mode = JoinMode.group),
          trailing: groupOk && selected == JoinMode.group && maxGroup > 2
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('join-group-minus'),
                      tooltip: homiziText(context, 'Fewer people'),
                      onPressed: group > 2
                          ? () => setState(() => _group = group - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$group', key: const Key('join-group-size')),
                    IconButton(
                      key: const Key('join-group-plus'),
                      tooltip: homiziText(context, 'More people'),
                      onPressed: group < maxGroup
                          ? () => setState(() => _group = group + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 20),
        ShGradientButton(
          buttonKey: const Key('join-continue'),
          icon: Icons.send_outlined,
          label: 'Request to join',
          onPressed: selected == null
              ? null
              : () => setState(() {
                  _mode = selected;
                  _group = group;
                  _choosing = false;
                }),
        ),
      ],
    );
  }

  Widget _confirm(SharedHome home, OccupancyNeed need) {
    final text = Theme.of(context).textTheme;
    final share = home.shareFor(need.occupancy);
    final checks = joinChecks(home, need);
    final mate = home.housemate;
    final host = home.hostName;
    final mode = _mode ?? JoinMode.individual;
    final vacant = home.occupancy.vacantRooms;
    final roomsLine = vacant == null
        ? home.tag
        : '${home.bhkLabel} – $vacant ${vacant == 1 ? 'room' : 'rooms'} vacant';
    return ListView(
      key: const Key('join-confirm-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                const ShAvatar(initial: 'You', size: 64, you: true),
                const SizedBox(height: 6),
                Text(
                  mode == JoinMode.group
                      ? '${homiziText(context, 'You')} +${_group - 1}'
                      : homiziText(context, 'You'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('(${shortInr(share)})'),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.arrow_forward, color: HomiziColors.brandOrange),
            ),
            Column(
              children: [
                ShAvatar(initial: mate?.initial ?? 'H', size: 64),
                const SizedBox(height: 6),
                Text(host, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  homiziText(
                    context,
                    mate == null ? '(Host)' : '(Existing tenant)',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${homiziText(context, 'Send a request to')} $host ${homiziText(context, 'to join the home')} ($roomsLine)?',
          key: const Key('join-question'),
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ShSection(
          title: 'How you fit',
          icon: Icons.fact_check_outlined,
          child: Column(
            key: const Key('join-checks'),
            children: [for (final check in checks) ShCheckRow(check: check)],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('join-first-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: homiziText(
              context,
              'Your first name (shown to the host)',
            ),
            helperText: homiziText(
              context,
              'No phone number or email is shared. You chat in HOMIZI.',
            ),
          ),
        ),
        if (home.sample) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'This is a sample home, so nothing is sent to a real person.',
            ),
            key: const Key('join-sample-note'),
            style: const TextStyle(color: HomiziColors.muted),
          ),
        ],
        if (_problem != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, _problem!),
            key: const Key('join-problem'),
            style: const TextStyle(color: HomiziColors.error),
          ),
        ],
        const SizedBox(height: 16),
        ShGradientButton(
          buttonKey: const Key('join-send'),
          icon: Icons.send,
          label: 'Send join request',
          busy: _busy,
          onPressed: () => _send(home, need),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.optionKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final Key optionKey;
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? HomiziColors.brandOrange : HomiziColors.line,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          key: optionKey,
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 36, color: HomiziColors.brandOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            homiziText(context, title),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(homiziText(context, body)),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.chevron_right,
                      color: selected
                          ? HomiziColors.brandOrange
                          : HomiziColors.inkSoft,
                    ),
                  ],
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
