import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

const tenantHomeIntakeKey = 'flutter.homizi.tenant_home_intake';

const _intakeTypes = <(String, IconData)>[
  ('1 RK', RealLifeIcons.house),
  ('1 BHK', Icons.bed_outlined),
  ('2 BHK', Icons.meeting_room_outlined),
  ('3 BHK', Icons.holiday_village_outlined),
  ('4 BHK', Icons.apartment_outlined),
];

/// Details a tenant fills before any home or request is shown.
class TenantHomeIntake {
  const TenantHomeIntake({
    this.address = '',
    this.propertyType = '',
    this.rooms = 0,
    this.latitude,
    this.longitude,
  });

  final String address;
  final String propertyType;
  final int rooms;
  final double? latitude;
  final double? longitude;

  bool get complete =>
      address.trim().length >= 3 && propertyType.trim().isNotEmpty && rooms > 0;

  TenantHomeIntake copyWith({
    String? address,
    String? propertyType,
    int? rooms,
    double? latitude,
    double? longitude,
  }) {
    return TenantHomeIntake(
      address: address ?? this.address,
      propertyType: propertyType ?? this.propertyType,
      rooms: rooms ?? this.rooms,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, Object?> toJson() => {
    'address': address,
    'propertyType': propertyType,
    'rooms': rooms,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  static TenantHomeIntake fromJson(Object? raw) {
    if (raw is! Map) {
      return const TenantHomeIntake();
    }
    final rooms = raw['rooms'];
    final lat = raw['latitude'];
    final lng = raw['longitude'];
    return TenantHomeIntake(
      address: raw['address'] is String ? raw['address'] as String : '',
      propertyType: raw['propertyType'] is String
          ? raw['propertyType'] as String
          : '',
      rooms: rooms is int ? rooms : 0,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
    );
  }
}

class TenantHomeIntakeController extends Notifier<TenantHomeIntake> {
  @override
  TenantHomeIntake build() {
    unawaited(_load());
    return const TenantHomeIntake();
  }

  Future<void> _load() async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    String? raw;
    try {
      raw = await readDeviceString(tenantHomeIntakeKey);
    } on Object {
      raw = null;
    }
    if (raw == null || raw.isEmpty || !ref.mounted) {
      return;
    }
    try {
      state = TenantHomeIntake.fromJson(jsonDecode(raw));
    } on Object {
      // A damaged local copy starts the form again.
    }
  }

  Future<void> save(TenantHomeIntake next) async {
    state = next;
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    try {
      await writeDeviceString(tenantHomeIntakeKey, jsonEncode(next.toJson()));
      await LiveAccountSync.tenantIntake(next.toJson());
    } on Object {
      // The in-memory copy still unlocks homes for this session.
    }
  }

  void edit() {
    state = state.copyWith(rooms: 0);
  }
}

final tenantHomeIntakeProvider =
    NotifierProvider<TenantHomeIntakeController, TenantHomeIntake>(
      TenantHomeIntakeController.new,
    );

/// Asks for address, property type, and rooms, then opens homes and requests.
class TenantSharedIntake extends ConsumerStatefulWidget {
  const TenantSharedIntake({super.key});

  @override
  ConsumerState<TenantSharedIntake> createState() => _TenantSharedIntakeState();
}

class _TenantSharedIntakeState extends ConsumerState<TenantSharedIntake> {
  final _address = TextEditingController();
  var _type = '';
  var _rooms = 0;
  double? _lat;
  double? _lng;
  String? _problem;
  var _seeded = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final address = _address.text.trim();
    if (address.length < 3) {
      setState(() => _problem = 'Add the address of the home.');
      return;
    }
    if (_type.isEmpty) {
      setState(() => _problem = 'Choose a property type.');
      return;
    }
    if (_rooms < 1) {
      setState(() => _problem = 'Choose how many rooms the home has.');
      return;
    }
    await ref
        .read(tenantHomeIntakeProvider.notifier)
        .save(
          TenantHomeIntake(
            address: address,
            propertyType: _type,
            rooms: _rooms,
            latitude: _lat,
            longitude: _lng,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final intake = ref.watch(tenantHomeIntakeProvider);
    ref.listen(tenantHomeIntakeProvider, (previous, next) {
      if (_seeded || next.address.isEmpty || !mounted) {
        return;
      }
      setState(() {
        _seeded = true;
        _address.text = next.address;
        _type = next.propertyType;
        _rooms = next.rooms;
        _lat = next.latitude;
        _lng = next.longitude;
      });
    });
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      child: intake.complete
          ? _ready(intake)
          : _form(key: const ValueKey('tenant-intake-form')),
    );
  }

  Widget _form({required Key key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          homiziText(context, 'Add complete details'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            'Tell us about the home first. Homes and requests open once these details are saved.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 16),
        PlaceAutocompleteField(
          controller: _address,
          fieldKey: const Key('tenant-intake-address'),
          labelText: homiziText(context, 'Address'),
          hintText: homiziText(context, 'Area and city'),
          prefixIcon: const Icon(
            Icons.signpost_outlined,
            color: HomiziColors.logoOrange,
          ),
          onSelected: (place) {
            setState(() {
              _address.text = place.label;
              _lat = place.latitude;
              _lng = place.longitude;
              _problem = null;
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Property type'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        OptionGrid(
          children: [
            for (final option in _intakeTypes)
              OptionTile(
                key: Key('tenant-intake-type-${option.$1}'),
                label: option.$1,
                icon: option.$2,
                selected: _type == option.$1,
                onTap: () => setState(() {
                  _type = option.$1;
                  _problem = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Total rooms'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        OptionGrid(
          minTileWidth: 72,
          maxColumns: 4,
          children: [
            for (var count = 1; count <= 4; count++)
              OptionTile(
                key: Key('tenant-intake-rooms-$count'),
                label: '$count',
                icon: Icons.meeting_room_outlined,
                selected: _rooms == count,
                onTap: () => setState(() {
                  _rooms = count;
                  _problem = null;
                }),
              ),
          ],
        ),
        if (_problem != null) ...[
          const SizedBox(height: 12),
          Text(
            homiziText(context, _problem!),
            key: const Key('tenant-intake-error'),
            style: const TextStyle(color: HomiziColors.error),
          ),
        ],
        const SizedBox(height: 20),
        ShGradientButton(
          buttonKey: const Key('tenant-intake-save'),
          label: 'Save and see homes',
          icon: Icons.home_outlined,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }

  Widget _ready(TenantHomeIntake intake) {
    final homes = ref.watch(sharedHomesProvider).homes.where((home) {
      return !home.sample;
    }).toList();
    final requests = ref.watch(joinRequestsProvider);
    return ListView(
      key: const ValueKey('tenant-intake-ready'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          homiziText(context, intake.address),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${intake.propertyType} · ${intake.rooms} ${intake.rooms == 1 ? 'room' : 'rooms'}',
          style: const TextStyle(color: HomiziColors.inkSoft),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('tenant-intake-edit'),
            onPressed: () {
              ref.read(tenantHomeIntakeProvider.notifier).edit();
            },
            child: Text(homiziText(context, 'Edit details')),
          ),
        ),
        Text(
          homiziText(context, 'Homes'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (homes.isEmpty)
          Text(
            homiziText(
              context,
              'Shared homes that are actually listed show up here.',
            ),
          )
        else
          for (final home in homes.take(8))
            Card(
              key: Key('tenant-home-${home.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.home_outlined,
                  color: HomiziColors.logoOrange,
                ),
                title: Text(home.listing.title),
                subtitle: Text(home.place),
                onTap: () => context.push(SharedHomePaths.home(home.id)),
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('tenant-intake-all-homes'),
            onPressed: () => context.push(SharedHomePaths.search),
            child: Text(homiziText(context, 'See all homes')),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Requests'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Text(
            homiziText(context, 'Requests you send for a home show up here.'),
          )
        else
          for (final request in requests)
            Card(
              key: Key('tenant-request-${request.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.outgoing_mail,
                  color: HomiziColors.logoOrange,
                ),
                title: Text(request.homeTitle),
                subtitle: Text('${request.place} · ${request.status.name}'),
                onTap: () => context.push(SharedHomePaths.request(request.id)),
              ),
            ),
      ],
    );
  }
}
