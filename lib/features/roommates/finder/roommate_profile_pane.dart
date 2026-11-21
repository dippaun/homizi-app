import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/homizi_portrait.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Your Roommate Profile: inherited account rows, plus the extra roommate
/// answers, plus the door into the ranked "I want my roommate to be…" list.
class RoommateProfilePane extends ConsumerStatefulWidget {
  const RoommateProfilePane({
    required this.ask,
    required this.onSave,
    required this.onOpenWants,
    super.key,
  });

  final RoommateAsk ask;
  final Future<void> Function(RoommateAsk ask) onSave;
  final VoidCallback onOpenWants;

  @override
  ConsumerState<RoommateProfilePane> createState() =>
      _RoommateProfilePaneState();
}

class _RoommateProfilePaneState extends ConsumerState<RoommateProfilePane> {
  TenantProfile _profile = const TenantProfile();
  String _office = '';
  var _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    TenantProfile profile = const TenantProfile();
    try {
      profile = await ref.read(accountGatewayProvider).loadTenantProfile();
    } on Object {
      profile = const TenantProfile();
    }
    try {
      await ref.read(officeRepositoryProvider).load();
    } on Object {
      // Office stays blank when the row is missing.
    }
    var gender = widget.ask.ownGender.trim();
    var age = widget.ask.ownAge;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? '';
      if (userId.isNotEmpty) {
        final row = await client
            .from('profiles')
            .select('gender, age')
            .eq('user_id', userId)
            .maybeSingle();
        final savedGender = row?['gender'];
        final savedAge = row?['age'];
        if (gender.isEmpty && savedGender is String) {
          gender = savedGender.trim();
        }
        if (age <= 0 && savedAge is num && savedAge > 0) {
          age = savedAge.round();
        }
      }
    } on Object {
      // Demo sessions have no profile row.
    }
    if (!mounted) {
      return;
    }
    final offices = ref.read(officeRepositoryProvider).offices;
    setState(() {
      _profile = profile;
      _office = offices.isEmpty ? '' : offices.first.label.trim();
      _ready = true;
    });
    if ((gender.isNotEmpty && gender != widget.ask.ownGender) ||
        (age > 0 && age != widget.ask.ownAge)) {
      await widget.onSave(widget.ask.copyWith(ownGender: gender, ownAge: age));
    }
  }

  Future<void> _choose(RoommateAskId id) async {
    final options = roommateAskOptions(id);
    if (options.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              homiziText(context, roommateAskTitle(id)),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in options.entries)
                  ChoiceChip(
                    key: Key('roommate-self-${id.name}-${entry.key}'),
                    label: Text(homiziText(context, entry.value)),
                    selected:
                        roommateAskValue(widget.ask, id) == entry.value ||
                        _raw(id) == entry.key,
                    selectedColor: HomiziColors.logoOrange,
                    onSelected: (_) => Navigator.of(context).pop(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    await widget.onSave(_apply(widget.ask, id, picked));
  }

  String _raw(RoommateAskId id) => switch (id) {
    RoommateAskId.food => widget.ask.food,
    RoommateAskId.smoking => widget.ask.smoking,
    RoommateAskId.drinking => widget.ask.drinking,
    RoommateAskId.sleep => widget.ask.sleep,
    RoommateAskId.cleanliness => '${widget.ask.cleanliness}',
    RoommateAskId.guests => widget.ask.guests,
    RoommateAskId.pets => widget.ask.pets,
    RoommateAskId.schedule => widget.ask.schedule,
    RoommateAskId.lookingFor => widget.ask.lookingFor,
    _ => '',
  };

  RoommateAsk _apply(RoommateAsk ask, RoommateAskId id, String picked) {
    return switch (id) {
      RoommateAskId.food => ask.copyWith(food: picked),
      RoommateAskId.smoking => ask.copyWith(smoking: picked),
      RoommateAskId.drinking => ask.copyWith(drinking: picked),
      RoommateAskId.sleep => ask.copyWith(sleep: picked),
      RoommateAskId.cleanliness => ask.copyWith(
        cleanliness: int.tryParse(picked) ?? ask.cleanliness,
      ),
      RoommateAskId.guests => ask.copyWith(guests: picked),
      RoommateAskId.pets => ask.copyWith(pets: picked),
      RoommateAskId.schedule => ask.copyWith(schedule: picked),
      RoommateAskId.lookingFor => ask.copyWith(lookingFor: picked),
      _ => ask,
    };
  }

  Future<void> _languages() async {
    final selected = {...widget.ask.languages};
    final next = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  homiziText(context, 'Languages'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in roommateAskOptions(
                      RoommateAskId.languages,
                    ).entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: selected.contains(entry.key),
                        selectedColor: HomiziColors.logoOrange,
                        onSelected: (on) => setSheet(() {
                          if (on) {
                            selected.add(entry.key);
                          } else {
                            selected.remove(entry.key);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected.toList()),
                  child: Text(homiziText(context, 'Save languages')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    await widget.onSave(widget.ask.copyWith(languages: next));
  }

  Future<void> _moveIn() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 540)),
      initialDate: widget.ask.moveIn,
    );
    if (picked == null || !mounted) {
      return;
    }
    await widget.onSave(
      widget.ask.copyWith(
        moveYear: picked.year,
        moveMonth: picked.month,
        moveDay: picked.day,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final ask = widget.ask;
    final city = _profile.preferences.city.trim().isNotEmpty
        ? _profile.preferences.city.trim()
        : ask.city;
    final photo = _profile.avatarUrl?.trim() ?? '';
    final wants = ask.want ?? ask;
    return ListView(
      key: const Key('roommate-profile-pane'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Center(
          child: HomiziPortrait(
            photo: photo,
            size: 112,
            semanticLabel: _profile.displayName,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _profile.displayName.trim().isEmpty
              ? homiziText(context, 'Your Roommate Profile')
              : _profile.displayName.trim(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'From your profile',
          child: Column(
            children: [
              _Inherited(
                icon: Icons.badge_outlined,
                label: 'Name',
                value: _ready ? _profile.displayName : '',
              ),
              _Inherited(
                icon: Icons.cake_outlined,
                label: 'Age',
                value: ask.ownAge > 0 ? '${ask.ownAge}' : _profile.ageRange,
              ),
              _Inherited(
                icon: Icons.wc_outlined,
                label: 'Gender',
                value: _genderLabel(ask.ownGender),
              ),
              _Inherited(
                icon: Icons.work_outline,
                label: 'Occupation',
                value: _profile.occupation,
              ),
              _Inherited(
                icon: Icons.apartment,
                label: 'Office',
                value: _office,
              ),
              _Inherited(
                icon: Icons.notes_outlined,
                label: 'Bio',
                value: _profile.bio,
              ),
              _Inherited(
                icon: Icons.location_city_outlined,
                label: 'City',
                value: city,
              ),
              _Inherited(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: session.phoneVerified ? 'Verified' : '',
              ),
              _Inherited(
                icon: Icons.mail_outline,
                label: 'Email',
                value: session.emailVerified ? 'Verified' : '',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('roommate-edit-in-profile'),
                  onPressed: () => context.push(
                    _profile.displayName.trim().isEmpty
                        ? RoutePaths.profileCreate
                        : RoutePaths.tenantProfile,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: HomiziColors.logoOrange,
                  ),
                  label: Text(
                    homiziText(context, 'Edit in profile'),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Roommate details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                homiziText(
                  context,
                  'Budget per person · ${roommateAskValue(ask, RoommateAskId.budget)}',
                ),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.calendar_month_outlined,
                label: 'Move-in date',
                value: roommateAskValue(ask, RoommateAskId.moveIn),
                onTap: () => unawaited(_moveIn()),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(context, 'Looking for'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    '2BHK',
                    'Shared room',
                    'Has a flat',
                  ])
                    _LookTile(
                      selected:
                          ask.lookingFor == option ||
                          (option == '2BHK' &&
                              (ask.lookingFor == '1BHK' ||
                                  ask.lookingFor == '3BHK')),
                      label: option == '2BHK' ? 'BHK' : option,
                      icon: option == 'Shared room'
                          ? Icons.bed_outlined
                          : option == 'Has a flat'
                          ? Icons.vpn_key_outlined
                          : Icons.apartment,
                      onTap: () => unawaited(
                        option == '2BHK'
                            ? _choose(RoommateAskId.lookingFor)
                            : widget.onSave(ask.copyWith(lookingFor: option)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, 'Preferred localities'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              CityLocalityField(
                city: city,
                localities: [
                  for (final name in ask.localityList) PickedPlace(label: name),
                ],
                onChanged: (selection) {
                  final places = [
                    for (final place in selection.localities)
                      if (place.label.trim().isNotEmpty) place.label.trim(),
                  ];
                  unawaited(
                    widget.onSave(
                      ask.copyWith(
                        city: selection.city.trim().isEmpty
                            ? ask.city
                            : selection.city.trim(),
                        localities: places.join(', '),
                        pins: [
                          for (final place in selection.localities)
                            RoommatePin(
                              name: place.label,
                              latitude: place.latitude,
                              longitude: place.longitude,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in const [
                    RoommateAskId.food,
                    RoommateAskId.smoking,
                    RoommateAskId.drinking,
                    RoommateAskId.sleep,
                    RoommateAskId.cleanliness,
                    RoommateAskId.guests,
                    RoommateAskId.pets,
                    RoommateAskId.schedule,
                  ])
                    _Tile(
                      icon: roommateAskIcon(id),
                      label: roommateAskTitle(id),
                      value: roommateAskValue(ask, id),
                      onTap: () => unawaited(_choose(id)),
                    ),
                  _Tile(
                    icon: Icons.translate,
                    label: 'Languages',
                    value: ask.languages.isEmpty
                        ? ''
                        : ask.languages.join(', '),
                    onTap: () => unawaited(_languages()),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('publish-roommate-profile'),
          style: FilledButton.styleFrom(
            backgroundColor: ask.profilePosted
                ? HomiziColors.success
                : HomiziColors.logoOrange,
            foregroundColor: HomiziColors.ink,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => unawaited(
            widget.onSave(ask.copyWith(profilePosted: !ask.profilePosted)),
          ),
          icon: Icon(
            ask.profilePosted ? Icons.visibility : Icons.campaign_outlined,
          ),
          label: Text(
            homiziText(
              context,
              ask.profilePosted
                  ? 'Roommate profile is published'
                  : 'Publish my roommate profile',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'My Requirements for Roommie',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                homiziText(context, 'I want my roommate to be…'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < wants.active.take(4).length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: HomiziColors.logoOrange,
                        child: Text(
                          'P${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: HomiziColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${roommateAskTitle(wants.active[i])} · ${wants.isMust(wants.active[i]) ? 'Must have' : 'Flexible'}',
                          style: const TextStyle(color: HomiziColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                key: const Key('open-roommate-wants'),
                onPressed: widget.onOpenWants,
                icon: const Icon(
                  Icons.low_priority,
                  color: HomiziColors.logoOrange,
                ),
                label: Text(
                  homiziText(context, 'Rank what you want'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _genderLabel(String raw) {
  return switch (raw.trim()) {
    'woman' || 'female' => 'Woman',
    'man' || 'male' => 'Man',
    'nonbinary' => 'Non-binary',
    '' => '',
    _ => raw.trim(),
  };
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            homiziText(context, title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Inherited extends StatelessWidget {
  const _Inherited({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? 'Add in profile' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: HomiziColors.logoOrange),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              style: TextStyle(
                color: value.trim().isEmpty
                    ? HomiziColors.muted
                    : HomiziColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF6EE),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HomiziColors.homiziPurple),
              const SizedBox(height: 6),
              Text(
                homiziText(context, label),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value.trim().isEmpty ? homiziText(context, 'Add') : value,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.logoOrange : HomiziColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 104,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? HomiziColors.logoOrange : HomiziColors.line,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: HomiziColors.ink),
              const SizedBox(height: 4),
              Text(
                homiziText(context, label),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
