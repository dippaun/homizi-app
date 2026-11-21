import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
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
          title: 'From your profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                homiziText(
                  context,
                  'Budget, city, localities, move-in, food, smoking, pets, and schedule come from your profile. This page does not ask for them again.',
                ),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  height: 1.35,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('roommate-edit-habits'),
                  onPressed: () => context.push(RoutePaths.profileMe),
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
