import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/rent_cost_breakdown.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/maps/listing_area_map.dart';
import 'package:homizi/features/nearby/nearby_models.dart';
import 'package:homizi/features/nearby/nearby_places_page.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/office/office_repository.dart';

/// "18 min (5.8 km)" when a provider measured the drive. Otherwise the
/// shared unavailable label. Nothing here is guessed.
String formatOfficeCommute(CommuteEstimate estimate) {
  final meters = estimate.distanceMeters;
  final seconds = estimate.durationSeconds;
  if (!estimate.available ||
      meters == null ||
      seconds == null ||
      seconds <= 0) {
    return distanceUnavailableLabel;
  }
  final minutes = (seconds / 60).round();
  final km = meters / 1000;
  final raw = km >= 10 ? km.round().toString() : km.toStringAsFixed(1);
  final shown = raw.endsWith('.0') ? raw.substring(0, raw.length - 2) : raw;
  return '$minutes min ($shown km)';
}

/// Green-tick lines for "Why this matches?", drawn from the shared scorer.
///
/// Blank "No … set" factors are skipped. A measured drive inside the saved
/// commute limit adds "Close to office".
List<String> whyThisMatches({
  required ListingMatch match,
  required Listing listing,
  int? commuteMinutes,
  int? maxCommuteMinutes,
}) {
  final picked = <String, String>{};
  for (final factor in match.factors) {
    if (!factor.matched) {
      continue;
    }
    final detail = factor.detail.trim();
    if (detail.startsWith('No ') || detail.startsWith('Any household')) {
      continue;
    }
    final line = _whyLine(factor, listing);
    if (line == null || line.isEmpty) {
      continue;
    }
    picked[factor.label] = line;
  }
  final ordered = <String>[];
  void add(String? line) {
    if (line == null || line.isEmpty || ordered.contains(line)) {
      return;
    }
    ordered.add(line);
  }

  add(picked['Budget']);
  final close =
      commuteMinutes != null &&
      commuteMinutes > 0 &&
      (maxCommuteMinutes == null || commuteMinutes <= maxCommuteMinutes);
  if (close) {
    add('Close to office');
  }
  add(picked['Furnishing']);
  add(picked['Locality']);
  add(picked['Home type']);
  add(picked['City']);
  add(picked['Move-in']);
  for (final entry in picked.entries) {
    if (entry.key.startsWith('Amenity')) {
      add(entry.value);
    }
  }
  if (ordered.length > 4) {
    return ordered.sublist(0, 4);
  }
  return ordered;
}

String? _whyLine(MatchFactor factor, Listing listing) {
  switch (factor.label) {
    case 'Budget':
      return 'Budget is ideal';
    case 'Furnishing':
      return listing.furnishing == 'furnished'
          ? 'Fully furnished'
          : 'Furnishing matches';
    case 'Locality':
      final place = listing.locality.trim();
      return place.isEmpty ? 'Locality matches' : 'In $place';
    case 'City':
      final city = listing.city.trim();
      return city.isEmpty ? 'City matches' : 'In $city';
    case 'Home type':
      return '${listing.bhkLabel} matches';
    case 'Move-in':
      return 'Available for your move-in';
    default:
      if (factor.label.startsWith('Amenity · ')) {
        return factor.label.substring('Amenity · '.length);
      }
      final detail = factor.detail.trim();
      return detail.isEmpty ? null : detail;
  }
}

String listingBathsValue(Listing listing) {
  final bath = listing.bathroom.trim().toLowerCase();
  switch (bath) {
    case 'attached':
      return 'Attached';
    case 'private':
      return 'Private';
    case 'shared':
      return 'Shared';
    case '':
      break;
    default:
      return listing.bathroom.trim();
  }
  for (final amenity in listing.amenities) {
    if (amenity.toLowerCase().contains('bath')) {
      return amenity;
    }
  }
  return '—';
}

class ListingTitleBlock extends StatelessWidget {
  const ListingTitleBlock({
    required this.listing,
    required this.match,
    super.key,
  });

  final Listing listing;
  final ListingMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            homiziText(context, listing.title),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (match.showBadge) ...[
          const SizedBox(width: 12),
          _MatchPill(
            key: Key('match-badge-${listing.id}'),
            match: match,
            onTap: () => showMatchBreakdown(context, match: match),
          ),
        ],
      ],
    );
  }
}

class _MatchPill extends MatchBadge {
  const _MatchPill({required super.match, required super.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.success,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            homiziText(context, match.label),
            style: const TextStyle(
              color: HomiziColors.onSuccess,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class ListingPlaceRow extends StatelessWidget {
  const ListingPlaceRow({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: HomiziColors.logoOrange, size: 18),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            homiziText(
              context,
              listingPlaceLine(listing.locality, listing.city),
            ),
            key: const Key('listing-detail-place'),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ListingPriceBlock extends StatelessWidget {
  const ListingPriceBlock({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('listing-price'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '₹ ${formatIndianDigits(listing.rentInr)}',
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const TextSpan(
                text: ' / month',
                style: TextStyle(
                  color: HomiziColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (listing.maintenanceInr > 0) ...[
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              '+ Maintenance ${formatInr(listing.maintenanceInr)}',
            ),
            style: const TextStyle(
              color: HomiziColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class ListingSpecRow extends StatelessWidget {
  const ListingSpecRow({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final area = listing.areaSqft;
    final tiles = <(IconData, String, String, Key)>[
      (
        Icons.bed_outlined,
        listing.bhkLabel,
        'BHK',
        const Key('listing-spec-bhk'),
      ),
      (
        Icons.chair_outlined,
        listing.furnishingLabel,
        'Furnished',
        const Key('listing-spec-furnishing'),
      ),
      (
        Icons.bathtub_outlined,
        listingBathsValue(listing),
        'Baths',
        const Key('listing-spec-baths'),
      ),
      (
        Icons.square_foot,
        area == null || area <= 0 ? '—' : formatSqft(area),
        'sq ft',
        const Key('listing-spec-area'),
      ),
    ];
    return Row(
      key: const Key('listing-specs'),
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SpecTile(
              icon: tiles[i].$1,
              value: tiles[i].$2,
              caption: tiles[i].$3,
              tileKey: tiles[i].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.value,
    required this.caption,
    required this.tileKey,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Key tileKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: HomiziColors.logoOrange, size: 22),
          const SizedBox(height: 6),
          Text(
            homiziText(context, value),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            homiziText(context, caption),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HomiziColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ListingAmenityGrid extends StatelessWidget {
  const ListingAmenityGrid({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final tiles = amenityTiles(listing);
    return Column(
      key: const Key('listing-amenities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Amenities'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (tiles.isEmpty)
          Text(
            homiziText(context, 'No amenities listed'),
            style: const TextStyle(color: HomiziColors.muted),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 6 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return DecoratedBox(
                    key: Key('amenity-${tile.$2}'),
                    decoration: BoxDecoration(
                      color: HomiziColors.soft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tile.$1, color: HomiziColors.logoOrange),
                          const SizedBox(height: 6),
                          Text(
                            homiziText(context, tile.$2),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

/// Icon and a short label for each amenity the home actually has.
List<(IconData, String)> amenityTiles(Listing listing) {
  final seen = <String>{};
  final tiles = <(IconData, String)>[];
  void add(String raw) {
    final label = amenityDisplayLabel(raw);
    final key = label.toLowerCase();
    if (key.isEmpty || !seen.add(key)) {
      return;
    }
    tiles.add((amenityIcon(label), label));
  }

  for (final amenity in listing.amenities) {
    add(amenity);
  }
  if (listing.parking) {
    add('Parking');
  }
  const order = ['Wi-Fi', 'AC', 'Lift', 'Parking', 'Gym', 'Power Backup'];
  tiles.sort((a, b) {
    final left = order.indexOf(a.$2);
    final right = order.indexOf(b.$2);
    if (left == -1 && right == -1) {
      return a.$2.compareTo(b.$2);
    }
    if (left == -1) {
      return 1;
    }
    if (right == -1) {
      return -1;
    }
    return left.compareTo(right);
  });
  return tiles;
}

String amenityDisplayLabel(String raw) {
  final key = raw.trim().toLowerCase();
  if (key == 'wifi' || key == 'wi-fi' || key == 'wi fi') {
    return 'Wi-Fi';
  }
  if (key == 'ac' ||
      key == 'air conditioning' ||
      key.contains('air condition')) {
    return 'AC';
  }
  if (key == 'power backup') {
    return 'Power Backup';
  }
  if (key == 'parking' || key == 'covered parking') {
    return 'Parking';
  }
  if (key == 'gym' || key.contains('fitness')) {
    return 'Gym';
  }
  return raw.trim();
}

IconData amenityIcon(String label) {
  final key = label.toLowerCase();
  if (key.contains('wi-fi') || key.contains('wifi')) {
    return Icons.wifi;
  }
  if (key == 'ac' || key.contains('air')) {
    return Icons.ac_unit;
  }
  if (key.contains('lift') || key.contains('elevator')) {
    return Icons.elevator;
  }
  if (key.contains('parking')) {
    return Icons.local_parking;
  }
  if (key.contains('gym') || key.contains('fitness')) {
    return Icons.fitness_center;
  }
  if (key.contains('power')) {
    return Icons.bolt;
  }
  if (key.contains('wash')) {
    return Icons.local_laundry_service;
  }
  if (key.contains('balcony')) {
    return Icons.balcony;
  }
  if (key.contains('security')) {
    return Icons.security;
  }
  if (key.contains('water')) {
    return Icons.water_drop;
  }
  if (key.contains('kitchen')) {
    return Icons.kitchen;
  }
  return Icons.check_circle_outline;
}

typedef CommuteMeasured = void Function(int? minutes, int? maxMinutes);

class ListingPlaceCards extends StatelessWidget {
  const ListingPlaceCards({
    required this.listing,
    required this.point,
    required this.onCommute,
    super.key,
  });

  final Listing listing;
  final GeoPoint? point;
  final CommuteMeasured onCommute;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListingOfficeCommute(
            point: point,
            place: listingPlaceLine(listing.locality, listing.city),
            onMeasured: onCommute,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ListingNearbyMini(listing: listing, point: point),
        ),
      ],
    );
  }
}

class ListingOfficeCommute extends ConsumerStatefulWidget {
  const ListingOfficeCommute({
    required this.point,
    required this.place,
    required this.onMeasured,
    super.key,
  });

  final GeoPoint? point;
  final String place;
  final CommuteMeasured onMeasured;

  @override
  ConsumerState<ListingOfficeCommute> createState() =>
      _ListingOfficeCommuteState();
}

class _ListingOfficeCommuteState extends ConsumerState<ListingOfficeCommute> {
  OfficeLocation? _office;
  String? _line;
  var _waiting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant ListingOfficeCommute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point?.latitude != widget.point?.latitude ||
        oldWidget.point?.longitude != widget.point?.longitude) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(officeRepositoryProvider).load();
    } on Object {
      // Tests and a missing store keep the add-office prompt.
    }
    if (!mounted) {
      return;
    }
    final office = ref.read(officeRepositoryProvider).primary;
    final point = widget.point;
    if (office == null || !office.hasCoordinates || point == null) {
      setState(() {
        _office = office;
        _line = null;
        _waiting = false;
      });
      widget.onMeasured(null, office?.maxCommuteMinutes);
      return;
    }
    setState(() {
      _office = office;
      _waiting = true;
    });
    // Web: LocationService.commute calls Maps JavaScript DistanceMatrixService.
    // A referrer-restricted key rejects the legacy Distance Matrix REST URL.
    final estimate = await ref
        .read(locationServiceProvider)
        .commute(
          origin: office.endpoint,
          destination: PlaceEndpoint(
            label: widget.place,
            latitude: point.latitude,
            longitude: point.longitude,
          ),
          mode: TransportMode.car,
        );
    if (!mounted) {
      return;
    }
    final seconds = estimate.durationSeconds;
    final minutes = estimate.available && seconds != null && seconds > 0
        ? (seconds / 60).round()
        : null;
    setState(() {
      _line = formatOfficeCommute(estimate);
      _waiting = false;
    });
    widget.onMeasured(
      minutes != null && minutes > 0 ? minutes : null,
      office.maxCommuteMinutes,
    );
  }

  Future<void> _addOffice() async {
    await context.push(RoutePaths.office);
    if (!mounted) {
      return;
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final office = _office;
    final canMeasure = office != null && office.hasCoordinates;
    return Container(
      key: const Key('listing-office-commute'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'Commute from Office'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.directions_car_outlined,
                color: HomiziColors.logoOrange,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(child: _commuteBody(context, canMeasure)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commuteBody(BuildContext context, bool canMeasure) {
    if (!canMeasure) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('listing-add-office'),
          style: TextButton.styleFrom(
            foregroundColor: HomiziColors.logoOrange,
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => unawaited(_addOffice()),
          child: Text(
            homiziText(context, 'Add office'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    if (_waiting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(
      homiziText(context, _line ?? distanceUnavailableLabel),
      key: const Key('listing-office-minutes'),
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class ListingNearbyMini extends ConsumerStatefulWidget {
  const ListingNearbyMini({
    required this.listing,
    required this.point,
    super.key,
  });

  final Listing listing;
  final GeoPoint? point;

  @override
  ConsumerState<ListingNearbyMini> createState() => _ListingNearbyMiniState();
}

class _ListingNearbyMiniState extends ConsumerState<ListingNearbyMini> {
  List<NearbyCommuteRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(nearbyPlacesServiceProvider)
        .peek(
          cacheKey: widget.listing.id,
          latitude: widget.point?.latitude,
          longitude: widget.point?.longitude,
        );
    _rows = cached ?? const [];
    if (cached == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final rows = await ref
        .read(nearbyPlacesServiceProvider)
        .load(
          cacheKey: widget.listing.id,
          city: widget.listing.city,
          locality: widget.listing.locality,
          latitude: widget.point?.latitude,
          longitude: widget.point?.longitude,
        );
    if (!mounted) {
      return;
    }
    setState(() => _rows = rows);
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NearbyPlacesPage(
          cacheKey: widget.listing.id,
          city: widget.listing.city,
          locality: widget.listing.locality,
          latitude: widget.point?.latitude,
          longitude: widget.point?.longitude,
          listing: widget.listing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picks = _nearbyPicks(_rows);
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('listing-nearby-places'),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'Nearby Places'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (picks.isEmpty)
                Text(
                  homiziText(context, 'Looking up places…'),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 12,
                  ),
                )
              else
                for (final row in picks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      homiziText(
                        context,
                        row.kmLabel.isEmpty
                            ? _nearbyShort(row.kind)
                            : '${_nearbyShort(row.kind)} ${row.kmLabel}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListingAreaMap(
                  listing: widget.listing,
                  height: 84,
                  showPin: true,
                  showCaption: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<NearbyCommuteRow> _nearbyPicks(List<NearbyCommuteRow> rows) {
  const wanted = ['metro', 'mall', 'hospital'];
  final picks = <NearbyCommuteRow>[];
  for (final kind in wanted) {
    for (final row in rows) {
      if (row.kind == kind) {
        picks.add(row);
        break;
      }
    }
  }
  if (picks.isNotEmpty) {
    return picks;
  }
  return rows.take(3).toList();
}

String _nearbyShort(String kind) {
  return switch (kind) {
    'metro' => 'Metro',
    'mall' => 'Mall',
    'hospital' => 'Hospital',
    'train' => 'Train',
    'bus' => 'Bus',
    'airport' => 'Airport',
    'supermarket' => 'Grocery',
    'movie' => 'Cinema',
    'gym' => 'Gym',
    _ => nearbyKindLabel(kind),
  };
}

class ListingHostRow extends ConsumerWidget {
  const ListingHostRow({
    required this.listing,
    required this.verifiedHost,
    required this.replyLabel,
    super.key,
  });

  final Listing listing;
  final bool verifiedHost;
  final String? replyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(discoveryProvider).listings.where((item) {
      return item.hostUserId == listing.hostUserId;
    }).length;
    final count = homes == 0 ? 1 : homes;
    final listingsWord = count == 1 ? 'Listing' : 'Listings';
    return Column(
      key: const Key('listing-host'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HostAvatar(
              name: listing.hostDisplayName,
              photoRef: listing.hostAvatarUrl,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.hostDisplayName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (verifiedHost) ...[
                    const SizedBox(height: 4),
                    const _VerifiedHostBadge(),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    homiziText(
                      context,
                      '${listing.hostKind} • $count $listingsWord',
                    ),
                    key: const Key('listing-host-meta'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: HomiziColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const Key('listing-view-profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.ink,
              backgroundColor: HomiziColors.white,
              side: const BorderSide(color: HomiziColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(48, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ListingHostPage(listing: listing),
                ),
              );
            },
            child: Text(
              homiziText(context, 'View Profile >'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        if (listing.hostOccupation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, listing.hostOccupation),
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
        ],
        if (replyLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, replyLabel!),
            key: const Key('owner-reply-badge'),
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
        ],
      ],
    );
  }
}

class _VerifiedHostBadge extends StatelessWidget {
  const _VerifiedHostBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listing-verified-host'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HomiziColors.success,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: HomiziColors.onSuccess),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              homiziText(context, 'Verified Host'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomiziColors.onSuccess,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ListingHostPage extends ConsumerWidget {
  const ListingHostPage({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = [
      for (final home in ref.watch(discoveryProvider).listings)
        if (home.hostUserId == listing.hostUserId) home,
    ];
    final shown = homes.isEmpty ? [listing] : homes;
    return Scaffold(
      key: const Key('listing-host-page'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, listing.hostDisplayName)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              HostAvatar(
                name: listing.hostDisplayName,
                photoRef: listing.hostAvatarUrl,
                radius: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, listing.hostDisplayName),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    if (listing.hostOccupation.isNotEmpty)
                      Text(
                        homiziText(context, listing.hostOccupation),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                    Text(
                      homiziText(context, listing.hostKind),
                      style: const TextStyle(color: HomiziColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Listings'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          for (final home in shown)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                homiziText(context, home.title),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                homiziText(
                  context,
                  '${listingPlaceLine(home.locality, home.city)} · ${formatInr(home.rentInr)}/mo',
                ),
                style: const TextStyle(color: HomiziColors.muted),
              ),
              onTap: () {
                final router = GoRouter.maybeOf(context);
                if (router == null) {
                  return;
                }
                router.push(RoutePaths.listing(home.id));
              },
            ),
        ],
      ),
    );
  }
}

class ListingWhyMatch extends StatelessWidget {
  const ListingWhyMatch({
    required this.listing,
    required this.match,
    this.commuteMinutes,
    this.maxCommuteMinutes,
    super.key,
  });

  final Listing listing;
  final ListingMatch match;
  final int? commuteMinutes;
  final int? maxCommuteMinutes;

  @override
  Widget build(BuildContext context) {
    final lines = whyThisMatches(
      match: match,
      listing: listing,
      commuteMinutes: commuteMinutes,
      maxCommuteMinutes: maxCommuteMinutes,
    );
    return Column(
      key: const Key('listing-why-match'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Why this matches?'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (lines.isEmpty)
          Text(
            homiziText(
              context,
              'Set your priorities to see why this home matches.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft),
          )
        else
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: HomiziColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      homiziText(context, line),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
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

class ListingCostSection extends StatelessWidget {
  const ListingCostSection({
    required this.cost,
    required this.detailed,
    super.key,
  });

  final RentingCost cost;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: HomiziColors.clear),
      child: ExpansionTile(
        key: const Key('listing-cost-section'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        iconColor: HomiziColors.ink,
        collapsedIconColor: HomiziColors.ink,
        title: Text(
          homiziText(context, 'Cost of renting'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          homiziText(context, 'Move-in ${formatInr(cost.moveInTotal)}'),
          style: const TextStyle(color: HomiziColors.muted),
        ),
        children: [
          RentCostBreakdown(cost: cost, detailed: detailed, showIntro: false),
        ],
      ),
    );
  }
}

class ListingActionBar extends StatelessWidget {
  const ListingActionBar({
    required this.saved,
    required this.busy,
    required this.note,
    required this.onSkip,
    required this.onSave,
    required this.onInterested,
    super.key,
  });

  final bool saved;
  final bool busy;
  final String? note;
  final VoidCallback? onSkip;
  final VoidCallback? onSave;
  final VoidCallback? onInterested;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      elevation: 8,
      shadowColor: HomiziColors.shadow,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null) ...[
                Text(
                  homiziText(context, note!),
                  key: const Key('interest-note'),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  _BarButton(
                    key: const Key('listing-skip'),
                    icon: Icons.close,
                    label: 'Skip',
                    onPressed: busy ? null : onSkip,
                  ),
                  const SizedBox(width: 8),
                  _BarButton(
                    key: const Key('listing-save'),
                    icon: saved ? Icons.bookmark : Icons.bookmark_border,
                    label: 'Save',
                    onPressed: busy ? null : onSave,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InterestButton(
                      busy: busy,
                      onPressed: busy ? null : onInterested,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: HomiziColors.ink,
        side: const BorderSide(color: HomiziColors.line),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: HomiziColors.ink),
          const SizedBox(width: 4),
          Text(
            homiziText(context, label),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestButton extends StatelessWidget {
  const _InterestButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = busy ? 'Saving…' : "I'm Interested";
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: HomiziColors.clear,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('interested-button'),
          onTap: onPressed,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [HomiziColors.logoOrange, HomiziColors.brandDeepOrange],
              ),
            ),
            child: SizedBox(
              height: 48,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          homiziText(context, label),
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (!busy) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: HomiziColors.ink,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
