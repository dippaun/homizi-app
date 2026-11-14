import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

/// Rent split prefilled with the housemates and the home.
String rentSplitPathFor(SharedHome? home, JoinRequest request) {
  final names = <String>[
    for (final mate in home?.occupancy.housemates ?? const <Housemate>[])
      mate.firstName,
  ];
  if (names.isEmpty) {
    names.add(request.hostName.split(' ').first);
  }
  final query = <String, String>{'with': names.join(',')};
  if (home != null) {
    final occ = home.occupancy;
    final places = occ.type == HostOccupancy.double
        ? occ.totalCapacity
        : occ.totalRooms;
    query['bhk'] = home.bhkLabel == '1 RK / Studio'
        ? '1 RK'
        : '${occ.totalRooms.clamp(1, 4)} BHK';
    query['place'] = home.place;
    query['rent'] = '${home.placeInr * places}';
  }
  return Uri(path: RoutePaths.rentSplit, queryParameters: query).toString();
}

/// Where a join request stands: sent, accepted ("You & Rohit S. are a
/// match!"), your shared home, and moved in.
class JoinStatusScreen extends ConsumerStatefulWidget {
  const JoinStatusScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<JoinStatusScreen> createState() => _JoinStatusScreenState();
}

class _JoinStatusScreenState extends ConsumerState<JoinStatusScreen> {
  var _showHome = false;
  var _busy = false;
  String? _note;

  void _back() {
    if (_showHome) {
      setState(() => _showHome = false);
      return;
    }
    HomiziBackButton.leave(context);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    await action();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(joinRequestsProvider);
    JoinRequest? request;
    for (final row in requests) {
      if (row.id == widget.requestId) {
        request = row;
      }
    }
    final home = request == null
        ? null
        : ref.watch(sharedHomesProvider).byId(request.homeId);
    final title = switch (request?.status) {
      JoinStatus.accepted =>
        _showHome ? 'Your shared home' : 'Request accepted!',
      JoinStatus.movedIn => 'Welcome home',
      JoinStatus.declined => 'Request declined',
      JoinStatus.withdrawn => 'Request withdrawn',
      _ => 'Join request',
    };
    return PopScope(
      canPop: !_showHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _back();
        }
      },
      child: Scaffold(
        key: const Key('join-status-screen'),
        backgroundColor: HomiziColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: HomiziBackButton(onPressed: _back),
          title: Text(homiziText(context, title)),
        ),
        body: SafeArea(
          top: false,
          child: request == null
              ? EmptyState(
                  title: 'Request not found',
                  message: 'It may have been sent from another device.',
                  actionLabel: 'See shared homes',
                  onAction: () =>
                      context.pushReplacement(SharedHomePaths.results()),
                )
              : ListView(
                  key: const Key('join-status-list'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: switch (request.status) {
                    JoinStatus.pending => _sent(request, home),
                    JoinStatus.accepted =>
                      _showHome
                          ? _yourHome(request, home)
                          : _accepted(request, home),
                    JoinStatus.movedIn => _movedIn(request, home),
                    JoinStatus.declined ||
                    JoinStatus.withdrawn => _closed(request),
                  },
                ),
        ),
      ),
    );
  }

  Widget _noteText() => _note == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            homiziText(context, _note!),
            key: const Key('join-status-note'),
            textAlign: TextAlign.center,
          ),
        );

  List<Widget> _sent(JoinRequest request, SharedHome? home) {
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(joinRequestsProvider.notifier);
    return [
      const ShDoneMark(icon: Icons.mark_email_read_outlined),
      const SizedBox(height: 14),
      Text(
        homiziText(context, 'Join request sent'),
        key: const Key('join-sent'),
        textAlign: TextAlign.center,
        style: text.headlineSmall?.copyWith(
          color: HomiziColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${homiziText(context, 'Your request to join')} ${request.hostName} ${homiziText(context, 'at')} ${request.place} ${homiziText(context, 'is waiting for a reply.')}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      _summary(request),
      const SizedBox(height: 10),
      Text(
        homiziText(
          context,
          request.sample
              ? 'This is a sample home. Nothing was sent to a real person.'
              : request.savedToAccount
              ? 'Saved to your HOMIZI account. The host also sees your interest under Interested seekers.'
              : 'The host sees your interest under Interested seekers. The join details are saved on this device.',
        ),
        key: const Key('join-saved-where'),
        textAlign: TextAlign.center,
        style: text.bodySmall,
      ),
      const SizedBox(height: 18),
      if (request.sample)
        ShGradientButton(
          buttonKey: const Key('join-sample-reply'),
          icon: Icons.visibility_outlined,
          label: 'See ${request.hostName.split(' ').first}\'s sample reply',
          busy: _busy,
          onPressed: () => _run(() async {
            await notifier.sampleReply(request.id);
          }),
        )
      else
        ShGradientButton(
          buttonKey: const Key('join-check'),
          icon: Icons.refresh,
          label: 'Check for a reply',
          busy: _busy,
          onPressed: () => _run(() async {
            await ref.read(discoveryProvider.notifier).refresh();
            final next = await notifier.refresh(request.id, home: home);
            if (mounted && next?.status == JoinStatus.pending) {
              setState(
                () => _note =
                    'No reply yet. We will show it here when the host answers.',
              );
            }
          }),
        ),
      _noteText(),
      const SizedBox(height: 10),
      OutlinedButton(
        key: const Key('join-withdraw'),
        onPressed: _busy
            ? null
            : () => _run(() async {
                await notifier.withdraw(request.id);
              }),
        child: Text(homiziText(context, 'Withdraw request')),
      ),
      TextButton(
        key: const Key('join-more-homes'),
        onPressed: () => context.pushReplacement(SharedHomePaths.results()),
        child: Text(homiziText(context, 'See more shared homes')),
      ),
    ];
  }

  List<Widget> _accepted(JoinRequest request, SharedHome? home) {
    final text = Theme.of(context).textTheme;
    final first = request.hostName.split(' ').first;
    final match = home == null
        ? null
        : matchWithHost(ref.watch(discoveryProvider), home);
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ShAvatar(initial: 'You', size: 64, you: true),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: HomiziColors.success,
              child: Icon(Icons.check, color: HomiziColors.onSuccess),
            ),
          ),
          ShAvatar(initial: first.isEmpty ? 'H' : first[0], size: 64),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '${homiziText(context, 'You')} & ${request.hostName} ${homiziText(context, 'are a match!')}',
        key: const Key('join-accepted'),
        textAlign: TextAlign.center,
        style: text.headlineSmall?.copyWith(
          color: HomiziColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$first ${homiziText(context, 'has accepted your request. You can now move forward, chat, and confirm your move-in.')}',
        textAlign: TextAlign.center,
      ),
      if (request.sample) ...[
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Sample reply: this home is seed data.'),
          key: const Key('join-sample-accepted'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomiziColors.muted),
        ),
      ],
      const SizedBox(height: 18),
      if (match != null)
        ShGreenButton(
          buttonKey: const Key('join-chat'),
          icon: Icons.chat_bubble_outline,
          label: 'Chat with $first',
          onPressed: () => context.push(
            RoutePaths.chat(
              match.matchId,
              name: match.otherDisplayName,
              title: home?.listing.title,
              otherUserId: match.otherUserId,
            ),
          ),
        )
      else if (!request.sample)
        ShGreenButton(
          buttonKey: const Key('join-chat'),
          icon: Icons.chat_bubble_outline,
          label: 'Open my matches',
          onPressed: () => context.go(RoutePaths.matches),
        )
      else
        Text(
          homiziText(
            context,
            'Chat opens for real homes once the host accepts. Sample homes have no chat.',
          ),
          key: const Key('join-chat-note'),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('join-discuss'),
        style: OutlinedButton.styleFrom(
          foregroundColor: HomiziColors.brandDeepRed,
          side: const BorderSide(color: HomiziColors.brandOrange),
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: () => context.push(rentSplitPathFor(home, request)),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(homiziText(context, 'Discuss & finalize: split the rent')),
      ),
      const SizedBox(height: 10),
      ShGradientButton(
        buttonKey: const Key('join-continue-home'),
        icon: Icons.home_outlined,
        label: 'Continue to your shared home',
        onPressed: () => setState(() => _showHome = true),
      ),
    ];
  }

  List<Widget> _yourHome(JoinRequest request, SharedHome? home) {
    final notifier = ref.read(joinRequestsProvider.notifier);
    final moveIn = request.moveIn;
    return [
      if (home != null) ...[
        SizedBox(
          height: 170,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListingPhoto(
              asset: home.listing.photoAssets.isEmpty
                  ? null
                  : home.listing.photoAssets.first,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: ShTag(label: request.homeTag),
      ),
      const SizedBox(height: 12),
      ShSection(
        title: 'Home summary',
        icon: Icons.home_outlined,
        child: Column(
          key: const Key('join-home-summary'),
          children: [
            if (home != null) ...[
              ShInfoRow(
                icon: Icons.person_outline,
                label: 'Currently living',
                value: home.occupancy.housemates.isEmpty
                    ? home.occupancy.livingLine
                    : '${home.occupancy.livingLine} (${home.occupancy.housemates.first.displayName})',
              ),
              ShInfoRow(
                icon: Icons.bed_outlined,
                label: 'Vacant rooms',
                value: home.occupancy.vacantLine,
              ),
              ShInfoRow(
                icon: Icons.groups_outlined,
                label: 'Total capacity',
                value: home.occupancy.capacityLine,
              ),
            ],
            ShInfoRow(
              icon: Icons.currency_rupee,
              label: 'Your share',
              value: '${formatInr(request.shareInr)} / month',
            ),
            ShInfoRow(
              icon: Icons.calendar_month_outlined,
              label: 'Move-in from',
              value: moveIn == null ? 'Agree a date' : formatMoveIn(moveIn),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        key: const Key('join-split'),
        onPressed: () => context.push(rentSplitPathFor(home, request)),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(homiziText(context, 'Split rent with your housemates')),
      ),
      const SizedBox(height: 10),
      ShGreenButton(
        buttonKey: const Key('join-move-in'),
        icon: Icons.check_circle_outline,
        label: 'Confirm & move in',
        onPressed: _busy
            ? null
            : () => _run(() async {
                await notifier.moveIn(request.id);
                if (mounted) {
                  setState(() => _showHome = false);
                }
              }),
      ),
    ];
  }

  List<Widget> _movedIn(JoinRequest request, SharedHome? home) {
    final text = Theme.of(context).textTheme;
    return [
      const ShDoneMark(),
      const SizedBox(height: 14),
      Text(
        homiziText(context, 'You are moving in!'),
        key: const Key('join-moved-in'),
        textAlign: TextAlign.center,
        style: text.headlineSmall?.copyWith(
          color: HomiziColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${request.homeTag} · ${request.place}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      _summary(request),
      if (request.sample) ...[
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Sample home: nothing was booked.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomiziColors.muted),
        ),
      ],
      const SizedBox(height: 18),
      ShGreenButton(
        buttonKey: const Key('join-done'),
        icon: Icons.home,
        label: 'Done',
        onPressed: () => context.go(RoutePaths.home),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('join-checklist'),
        onPressed: () => context.push(RoutePaths.moveInChecklist),
        icon: const Icon(Icons.checklist),
        label: Text(homiziText(context, 'Open the move-in checklist')),
      ),
      TextButton(
        key: const Key('join-split-after'),
        onPressed: () => context.push(rentSplitPathFor(home, request)),
        child: Text(homiziText(context, 'Split the rent')),
      ),
    ];
  }

  List<Widget> _closed(JoinRequest request) {
    return [
      const ShDoneMark(icon: Icons.do_not_disturb_on_outlined),
      const SizedBox(height: 14),
      Text(
        homiziText(
          context,
          request.status == JoinStatus.declined
              ? 'The host chose someone else this time.'
              : 'You withdrew this request.',
        ),
        key: const Key('join-closed'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 18),
      ShGradientButton(
        buttonKey: const Key('join-other-homes'),
        icon: Icons.search,
        label: 'See other shared homes',
        onPressed: () => context.pushReplacement(SharedHomePaths.results()),
      ),
    ];
  }

  Widget _summary(JoinRequest request) {
    return ShSection(
      child: Column(
        children: [
          ShInfoRow(
            icon: Icons.home_outlined,
            label: 'Home',
            value: request.homeTag,
          ),
          ShInfoRow(
            icon: Icons.person_outline,
            label: 'Joining as',
            value: request.mode == JoinMode.group
                ? 'A group of ${request.people}'
                : 'An individual',
          ),
          ShInfoRow(
            icon: Icons.currency_rupee,
            label: 'Your share',
            value: '${formatInr(request.shareInr)} / month',
          ),
        ],
      ),
    );
  }
}
