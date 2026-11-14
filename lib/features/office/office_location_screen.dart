import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/office/office_repository.dart';

/// First page after someone picks Tenant. `/office`.
class OfficeLocationScreen extends ConsumerStatefulWidget {
  const OfficeLocationScreen({super.key});

  @override
  ConsumerState<OfficeLocationScreen> createState() =>
      _OfficeLocationScreenState();
}

class _OfficeLocationScreenState extends ConsumerState<OfficeLocationScreen> {
  final _search = TextEditingController();
  final _nearby = TextEditingController();
  PlaceSuggestion? _place;
  TransportMode _mode = TransportMode.car;
  int _minutes = 30;
  var _status = ViewStatus.loading;
  var _saving = false;
  var _searching = false;
  String? _error;
  String? _locationNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _nearby.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(officeRepositoryProvider).load();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = ViewStatus.ready;
        _error = null;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _status = ViewStatus.error);
    }
  }

  void _onQuery(String value) {
    setState(() {
      _place = PlaceSuggestion(label: value.trim(), manual: true);
      _error = null;
    });
  }

  void _choose(PlaceSuggestion place) {
    setState(() {
      _place = place;
      _error = null;
    });
  }

  /// One location request. The office is named from the reverse-geocoded
  /// address and keeps the device coordinates.
  Future<void> _useMyLocation() async {
    setState(() {
      _searching = true;
      _locationNote = null;
      _error = null;
    });
    try {
      final service = ref.read(locationServiceProvider);
      final fix = await service.currentPosition();
      if (!mounted) {
        return;
      }
      if (fix == null) {
        setState(() {
          _locationNote =
              'Location permission was denied or is unavailable. Type the address instead.';
        });
        return;
      }
      final results = await Future.wait<Object?>([
        service.reverseGeocode(fix),
        service.nearbyPlaces(fix),
      ]);
      if (!mounted) {
        return;
      }
      final place = results[0] as PlaceSuggestion?;
      final nearby = results[1]! as NearbyResult;
      final address = (place?.address ?? '').trim();
      final label = address.isNotEmpty
          ? address
          : [
              if ((place?.locality ?? '').isNotEmpty) place!.locality!,
              if ((place?.city ?? '').isNotEmpty) place!.city!,
            ].join(', ');
      final finalLabel = label.isEmpty ? 'Current location' : label;
      _search.value = TextEditingValue(
        text: finalLabel,
        selection: TextSelection.collapsed(offset: finalLabel.length),
      );
      final landmarks = [
        for (final hit in nearby.places)
          if (officeLandmarkTypes.contains(hit.category)) hit.name,
      ];
      if (landmarks.isNotEmpty) {
        _nearby.text = landmarks.join(', ');
      }
      setState(() {
        _place = PlaceSuggestion(
          label: finalLabel,
          latitude: fix.latitude,
          longitude: fix.longitude,
          locality: place?.locality,
          city: place?.city,
          address: place?.address,
        );
        if (label.isEmpty && service.mapsEnabled) {
          _locationNote =
              'Location found, but maps did not name the address. You can type it.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _save() async {
    final label = (_place?.label ?? _search.text).trim();
    if (label.length < 2) {
      setState(() => _error = 'Enter your office, company, or area.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = [
      for (final part in _nearby.text.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final office = OfficeLocation(
      id: newOfficeId(),
      label: label,
      placeId: _place?.placeId,
      latitude: _place?.latitude,
      longitude: _place?.longitude,
      transport: _mode,
      maxCommuteMinutes: _minutes,
      primary: true,
      nearbyNotes: notes,
    );
    final saved = await ref.read(officeRepositoryProvider).save(office);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    await context.push(
      Uri(
        path: RoutePaths.officeSaved,
        queryParameters: {
          'label': office.label,
          'mode': office.transport.label,
          'minutes': '${office.maxCommuteMinutes}',
          'remote': saved.remote ? '1' : '0',
          'maps': ref.read(locationServiceProvider).mapsEnabled ? '1' : '0',
        },
      ).toString(),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(locationServiceProvider);
    final offices = ref.watch(officeRepositoryProvider).offices;
    return Scaffold(
      key: const Key('office-location-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: const Text('Your Office Location'),
      ),
      body: _status == ViewStatus.loading
          ? const LoadingState(message: 'Loading your offices')
          : _status == ViewStatus.error
          ? ErrorState(
              title: 'Offices',
              message: 'Offices could not be loaded.',
              onRetry: _load,
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      const Text(
                        'Live closer to what matters',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shorter commute, happier life. Save one or more offices.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.35,
                          color: HomiziColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PlaceAutocompleteField(
                        fieldKey: const Key('office-search'),
                        controller: _search,
                        hintText: 'Office, company or area',
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: HomiziColors.logoOrange,
                        ),
                        busy: _searching,
                        selected: _place,
                        manualOption: true,
                        manualSubtitle: maps.mapsEnabled
                            ? 'No place match. This address is saved as typed.'
                            : 'Saved as typed. Distance unavailable until a maps key is set.',
                        onChanged: _onQuery,
                        onSelected: _choose,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('office-use-location'),
                          onPressed: _searching
                              ? null
                              : () => unawaited(_useMyLocation()),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use my location'),
                        ),
                      ),
                      if (_locationNote != null)
                        Text(
                          _locationNote!,
                          style: const TextStyle(color: HomiziColors.error),
                        ),
                      const SizedBox(height: 8),
                      HomiziMapView(
                        mapsEnabled: maps.mapsEnabled,
                        apiKey: ref.watch(appConfigProvider).mapsApiKey,
                        latitude: _place?.latitude,
                        longitude: _place?.longitude,
                        label: (_place?.label ?? '').trim().isEmpty
                            ? 'My Office'
                            : _place!.label,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Preferred Transport Mode',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final mode in TransportMode.values)
                            Expanded(
                              child: _ModeButton(
                                mode: mode,
                                selected: _mode == mode,
                                onTap: () => setState(() => _mode = mode),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Max Commute Time (One Way)',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final minutes in commuteMinuteChoices) ...[
                            Expanded(
                              child: _MinuteButton(
                                minutes: minutes,
                                selected: _minutes == minutes,
                                onTap: () => setState(() => _minutes = minutes),
                              ),
                            ),
                            if (minutes != commuteMinuteChoices.last)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const Key('office-nearby'),
                        controller: _nearby,
                        decoration: InputDecoration(
                          labelText: maps.mapsEnabled
                              ? 'Nearby places'
                              : 'Nearby places (type them)',
                          hintText: 'Metro, market, park',
                        ),
                      ),
                      if (!maps.mapsEnabled)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            distanceUnavailableLabel,
                            key: Key('office-distance-unavailable'),
                            style: TextStyle(
                              color: HomiziColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (offices.isEmpty)
                        const Text(
                          'No office saved yet.',
                          key: Key('office-empty'),
                          style: TextStyle(color: HomiziColors.muted),
                        )
                      else
                        for (final office in offices)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              office.primary
                                  ? Icons.star
                                  : Icons.apartment_outlined,
                              color: HomiziColors.logoOrange,
                            ),
                            title: Text(office.label),
                            subtitle: Text(
                              '${office.transport.label} · ${office.maxCommuteMinutes} min',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove office',
                              onPressed: () async {
                                await ref
                                    .read(officeRepositoryProvider)
                                    .remove(office.id);
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          key: const Key('office-error'),
                          style: const TextStyle(color: HomiziColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    key: const Key('office-save'),
                    onPressed: _saving ? null : () => unawaited(_save()),
                    child: Text(_saving ? 'Saving…' : 'Save Office Location'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Nearby hits worth naming next to an office: transit, malls, hospitals,
/// groceries. Gyms, cinemas, and the airport stay off this list.
const officeLandmarkTypes = <String>{
  'subway_station',
  'train_station',
  'bus_station',
  'hospital',
  'shopping_mall',
  'supermarket',
};

class OfficeSavedScreen extends StatelessWidget {
  const OfficeSavedScreen({
    required this.label,
    required this.mode,
    required this.minutes,
    required this.remote,
    required this.mapsEnabled,
    super.key,
  });

  final String label;
  final String mode;
  final String minutes;
  final bool remote;
  final bool mapsEnabled;

  @override
  Widget build(BuildContext context) {
    final where = remote
        ? 'Saved on your profile.'
        : 'Saved on this device. It syncs to your profile when the office table is applied.';
    return Scaffold(
      key: const Key('office-saved-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: const Text('Office saved'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.success, size: 64),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text('$mode · $minutes min one way'),
          const SizedBox(height: 8),
          Text(where),
          const SizedBox(height: 8),
          Text(
            mapsEnabled
                ? 'Commute is shown after search, from Google Routes.'
                : distanceUnavailableLabel,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('office-continue'),
            onPressed: () => context.go(RoutePaths.searchStart),
            child: const Text('Search properties'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Add another office'),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      TransportMode.car => Icons.directions_car_filled,
      TransportMode.twoWheeler => Icons.two_wheeler,
      TransportMode.publicTransport => Icons.directions_transit,
      TransportMode.walk => Icons.directions_walk,
    };
    return InkWell(
      key: Key('office-mode-${mode.wire}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? HomiziColors.accent : HomiziColors.soft,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  icon,
                  color: selected ? HomiziColors.ink : HomiziColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? HomiziColors.ink : HomiziColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinuteButton extends StatelessWidget {
  const _MinuteButton({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.accent : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? HomiziColors.accent : HomiziColors.line,
        ),
      ),
      child: InkWell(
        key: Key('office-minutes-$minutes'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$minutes min',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
