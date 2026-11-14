import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

const _propertyTypes = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK'];

int _roomsFor(String type) => switch (type) {
  '1 RK' || '1 BHK' => 1,
  '2 BHK' => 2,
  '4 BHK' => 4,
  _ => 3,
};

/// "Post a shared home – add complete details", for hosts, owners and
/// existing tenants. Adds occupancy to one of their listings.
class HostSharedHomeScreen extends ConsumerStatefulWidget {
  const HostSharedHomeScreen({super.key});

  @override
  ConsumerState<HostSharedHomeScreen> createState() =>
      _HostSharedHomeScreenState();
}

class _HostSharedHomeScreenState extends ConsumerState<HostSharedHomeScreen> {
  String? _listingId;
  var _type = '3 BHK';
  var _rooms = 3;
  var _living = 1;
  var _vacant = 2;
  var _capacity = 3;
  var _occupancy = HostOccupancy.separate;
  final _mateName = TextEditingController();
  final _mateInitial = TextEditingController();
  final _mateAge = TextEditingController();
  final _mateJob = TextEditingController();
  var _mateFood = 'veg';
  var _mateGender = 'male';
  var _mateSmoker = false;
  var _busy = false;
  String? _problem;
  bool? _savedToAccount;

  @override
  void dispose() {
    _mateName.dispose();
    _mateInitial.dispose();
    _mateAge.dispose();
    _mateJob.dispose();
    super.dispose();
  }

  HomeOccupancy get _details => HomeOccupancy(
    totalRooms: _rooms,
    totalCapacity: _capacity,
    currentlyLiving: _living,
    vacantRooms: _vacant,
    type: _occupancy,
    housemates: [
      if (_living > 0 && _mateName.text.trim().isNotEmpty)
        Housemate(
          firstName: _mateName.text.trim(),
          lastInitial: _mateInitial.text.trim().toUpperCase(),
          age: int.tryParse(_mateAge.text.trim()),
          occupation: _mateJob.text.trim(),
          food: _mateFood,
          gender: _mateGender,
          smoker: _mateSmoker,
        ),
    ],
  );

  Future<void> _save(List<OwnerListing> listings) async {
    final id = _listingId ?? listings.first.id;
    final details = _details;
    final problem = details.problem;
    final text = [_mateName.text, _mateJob.text].join(' ');
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    if (text.contains('@') || RegExp('[0-9]{6,}').hasMatch(text)) {
      setState(
        () => _problem = 'Names cannot include a phone number or email.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final saved = await ref
        .read(sharedHomeRepositoryProvider)
        .saveDetails(listingId: id, label: _type, occupancy: details);
    ref.invalidate(sharedHomeDetailsProvider);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _savedToAccount = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(ownerListingsProvider);
    return Scaffold(
      key: const Key('host-shared-screen'),
      backgroundColor: HomiziColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Post a shared home')),
      ),
      body: SafeArea(
        top: false,
        child: listings.when(
          loading: () => const LoadingState(message: 'Loading your homes…'),
          error: (error, _) => ErrorState(
            title: 'Your homes did not load',
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(ownerListingsProvider),
          ),
          data: (rows) {
            if (_savedToAccount != null) {
              return _done(rows);
            }
            if (rows.isEmpty) {
              return EmptyState(
                title: 'Post your home first',
                message:
                    'Add the home as a listing, then come back to add who lives there and the vacant rooms.',
                actionLabel: 'Post a listing',
                onAction: () =>
                    context.push('${RoutePaths.listingEditor}?fresh=1'),
              );
            }
            return _form(rows);
          },
        ),
      ),
    );
  }

  Widget _number({
    required String key,
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: Key(key),
      initialValue: value.clamp(min, max),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: homiziText(context, label),
        isDense: true,
      ),
      items: [
        for (var i = min; i <= max; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (next) {
        if (next != null) {
          setState(() {
            onChanged(next);
            _problem = null;
          });
        }
      },
    );
  }

  Widget _form(List<OwnerListing> rows) {
    final text = Theme.of(context).textTheme;
    final selected = rows.any((row) => row.id == _listingId)
        ? _listingId!
        : rows.first.id;
    return ListView(
      key: const Key('host-shared-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          homiziText(context, 'Add complete details'),
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Seekers match on the rooms that are actually free, not just BHK.',
          ),
        ),
        const SizedBox(height: 16),
        ShSection(
          title: 'Your home',
          icon: Icons.home_outlined,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: const Key('host-listing'),
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Listing'),
                  isDense: true,
                ),
                items: [
                  for (final row in rows)
                    DropdownMenuItem(
                      value: row.id,
                      child: Text(
                        '${row.title} · ${row.locality} · ${formatInr(row.rentInr)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _listingId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('host-type'),
                      initialValue: _type,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Property type'),
                        isDense: true,
                      ),
                      items: [
                        for (final type in _propertyTypes)
                          DropdownMenuItem(
                            value: type,
                            child: Text(
                              type == '1 RK' ? type : '$type Apartment',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _type = value;
                          _rooms = _roomsFor(value);
                          _vacant = _vacant.clamp(1, _rooms);
                          _capacity = _capacity.clamp(_rooms, _rooms * 2);
                          _problem = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _number(
                      key: 'host-total-rooms',
                      label: 'Total rooms',
                      value: _rooms,
                      min: 1,
                      max: 6,
                      onChanged: (v) => _rooms = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _number(
                      key: 'host-living',
                      label: 'Currently living',
                      value: _living,
                      min: 0,
                      max: 8,
                      onChanged: (v) => _living = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _number(
                      key: 'host-vacant',
                      label: 'Vacant rooms',
                      value: _vacant,
                      min: 0,
                      max: 6,
                      onChanged: (v) => _vacant = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _number(
                key: 'host-capacity',
                label: 'Total capacity (persons)',
                value: _capacity,
                min: 1,
                max: 12,
                onChanged: (v) => _capacity = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ShSection(
          title: 'Occupancy type',
          icon: Icons.bed_outlined,
          child: RadioGroup<HostOccupancy>(
            groupValue: _occupancy,
            onChanged: (value) {
              if (value != null) {
                setState(() => _occupancy = value);
              }
            },
            child: Column(
              children: [
                for (final option in HostOccupancy.values)
                  RadioListTile<HostOccupancy>(
                    key: Key('host-occupancy-${option.wire}'),
                    value: option,
                    contentPadding: EdgeInsets.zero,
                    activeColor: HomiziColors.brandOrange,
                    title: Text(
                      homiziText(
                        context,
                        option == HostOccupancy.separate
                            ? '${option.label} (recommended)'
                            : option.label,
                      ),
                    ),
                    subtitle: Text(homiziText(context, option.hint)),
                  ),
              ],
            ),
          ),
        ),
        if (_living > 0) ...[
          const SizedBox(height: 14),
          ShSection(
            title: 'Who lives there now',
            icon: Icons.person_outline,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('host-mate-name'),
                        controller: _mateName,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 30,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'First name'),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const Key('host-mate-initial'),
                        controller: _mateInitial,
                        maxLength: 1,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Initial'),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const Key('host-mate-age'),
                        controller: _mateAge,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Age'),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        key: const Key('host-mate-job'),
                        controller: _mateJob,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Occupation'),
                          hintText: homiziText(context, 'e.g. IT Professional'),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('host-mate-food'),
                        initialValue: _mateFood,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Food'),
                          isDense: true,
                        ),
                        items: [
                          for (final entry in foodOptions.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(homiziText(context, entry.value)),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _mateFood = v ?? 'any'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('host-mate-gender'),
                        initialValue: _mateGender,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Gender'),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text(homiziText(context, 'Male')),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text(homiziText(context, 'Female')),
                          ),
                          DropdownMenuItem(
                            value: '',
                            child: Text(
                              homiziText(context, 'Prefer not to say'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _mateGender = v ?? ''),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  key: const Key('host-mate-smoker'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(homiziText(context, 'Smoker')),
                  value: _mateSmoker,
                  onChanged: (v) => setState(() => _mateSmoker = v),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _example(),
        if (_problem != null) ...[
          const SizedBox(height: 10),
          Text(
            homiziText(context, _problem!),
            key: const Key('host-problem'),
            style: const TextStyle(color: HomiziColors.error),
          ),
        ],
        const SizedBox(height: 16),
        ShGradientButton(
          buttonKey: const Key('host-save'),
          icon: Icons.check,
          label: 'Save shared home details',
          busy: _busy,
          onPressed: () => _save(rows),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('host-open-requests'),
          onPressed: () => context.push(SharedHomePaths.hostRequests),
          child: Text(homiziText(context, 'See join requests')),
        ),
      ],
    );
  }

  /// "How it works for this example", from the values in the form.
  Widget _example() {
    final mate = _mateName.text.trim();
    final total =
        _living +
        (_occupancy == HostOccupancy.double ? (_capacity - _living) : _vacant);
    final living = _living == 1 ? '1 person' : '$_living persons';
    final vacant = _vacant == 1 ? '1 vacant room' : '$_vacant vacant rooms';
    return ShSection(
      key: const Key('host-example'),
      title: 'How it works for this home',
      icon: Icons.groups_outlined,
      color: HomiziColors.soft,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          _Pill(text: '$_type home'),
          const Icon(Icons.arrow_forward, size: 16),
          _Pill(
            text: _living == 0
                ? 'Nobody living yet'
                : '$living already living${mate.isEmpty ? '' : ' ($mate)'}',
          ),
          const Icon(Icons.add, size: 16),
          _Pill(text: '$vacant (${_occupancy.label.toLowerCase()})'),
          const Icon(Icons.arrow_forward, size: 16),
          _Pill(text: 'Full home match (total $total persons)', green: true),
        ],
      ),
    );
  }

  Widget _done(List<OwnerListing> rows) {
    final text = Theme.of(context).textTheme;
    final id = _listingId ?? (rows.isEmpty ? '' : rows.first.id);
    final listing = rows.where((row) => row.id == id).firstOrNull;
    return ListView(
      key: const Key('host-done-list'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const ShDoneMark(),
        const SizedBox(height: 14),
        Text(
          homiziText(context, 'Shared home details saved'),
          key: const Key('host-done'),
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            color: HomiziColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (listing != null)
          Text(
            '${listing.title} · ${listing.locality}',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        Text(
          '$_type · ${_details.livingLine} ${homiziText(context, 'living')} · ${_details.vacantLine}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            _savedToAccount == true
                ? 'Saved to your HOMIZI account. Seekers now see the free rooms.'
                : 'Saved on this device. Seekers will see these details once the shared-home update is switched on.',
          ),
          key: const Key('host-saved-where'),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const SizedBox(height: 20),
        ShGradientButton(
          buttonKey: const Key('host-see-requests'),
          icon: Icons.inbox_outlined,
          label: 'See join requests',
          onPressed: () => context.push(SharedHomePaths.hostRequests),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const Key('host-finish'),
          onPressed: () => HomiziBackButton.leave(context),
          child: Text(homiziText(context, 'Done')),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.green = false});

  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: green ? HomiziColors.success : HomiziColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: green ? HomiziColors.success : HomiziColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          homiziText(context, text),
          style: TextStyle(
            color: green ? HomiziColors.onSuccess : HomiziColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

final hostJoinRequestsProvider =
    FutureProvider.autoDispose<List<HostJoinRequest>?>((ref) {
      return ref.watch(sharedHomeRepositoryProvider).remote.hostRequests();
    });

/// Join requests for the host's shared homes, with accept and decline.
class HostJoinRequestsScreen extends ConsumerStatefulWidget {
  const HostJoinRequestsScreen({super.key});

  @override
  ConsumerState<HostJoinRequestsScreen> createState() =>
      _HostJoinRequestsScreenState();
}

class _HostJoinRequestsScreenState
    extends ConsumerState<HostJoinRequestsScreen> {
  final _decided = <String, JoinStatus>{};
  String? _busy;

  Future<void> _decide(HostJoinRequest request, JoinStatus status) async {
    setState(() => _busy = request.id);
    final ok = await ref
        .read(sharedHomeRepositoryProvider)
        .remote
        .setStatus(request.id, status);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = null;
      if (ok) {
        _decided[request.id] = status;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          homiziText(
            context,
            !ok
                ? 'That did not save. Try again.'
                : status == JoinStatus.accepted
                ? 'Accepted. ${request.firstName} can now confirm the move-in. To chat, accept their interest under Interested seekers.'
                : 'Declined. ${request.firstName} will see that you chose someone else.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(hostJoinRequestsProvider);
    return Scaffold(
      key: const Key('host-requests-screen'),
      backgroundColor: HomiziColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Join requests')),
      ),
      body: SafeArea(
        top: false,
        child: rows.when(
          loading: () => const LoadingState(message: 'Loading join requests…'),
          error: (error, _) => ErrorState(
            title: 'Join requests did not load',
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(hostJoinRequestsProvider),
          ),
          data: (list) {
            if (list == null) {
              return EmptyState(
                key: const Key('host-requests-unavailable'),
                title: 'Join requests are not switched on yet',
                message:
                    'Until the shared-home update is live, seekers who want to join show up as interest under Interested seekers.',
                actionLabel: 'Open Interested seekers',
                onAction: () => context.push(RoutePaths.seekers),
              );
            }
            if (list.isEmpty) {
              return const EmptyState(
                key: Key('host-requests-empty'),
                title: 'No join requests yet',
                message:
                    'When someone asks to join one of your shared homes, it shows up here.',
              );
            }
            return ListView.separated(
              key: const Key('host-requests-list'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final row = list[index];
                final status = _decided[row.id] ?? row.status;
                return ShSection(
                  key: Key('host-request-${row.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShAvatar(
                            initial: row.firstName.isEmpty
                                ? '?'
                                : row.firstName[0].toUpperCase(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.firstName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${row.mode == JoinMode.group ? 'Group of ${row.people}' : 'Individual'} · ${formatInr(row.shareInr)} / month',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (status == JoinStatus.pending)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: Key('host-decline-${row.id}'),
                                onPressed: _busy == null
                                    ? () => _decide(row, JoinStatus.declined)
                                    : null,
                                child: Text(homiziText(context, 'Decline')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                key: Key('host-accept-${row.id}'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: HomiziColors.success,
                                  foregroundColor: HomiziColors.onSuccess,
                                ),
                                onPressed: _busy == null
                                    ? () => _decide(row, JoinStatus.accepted)
                                    : null,
                                child: Text(homiziText(context, 'Accept')),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          homiziText(context, switch (status) {
                            JoinStatus.accepted => 'Accepted',
                            JoinStatus.declined => 'Declined',
                            JoinStatus.withdrawn => 'Withdrawn by the seeker',
                            JoinStatus.movedIn => 'Moved in',
                            JoinStatus.pending => 'Waiting',
                          }),
                          key: Key('host-status-${row.id}'),
                          style: const TextStyle(
                            color: HomiziColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
