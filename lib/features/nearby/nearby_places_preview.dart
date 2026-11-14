import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/nearby/nearby_models.dart';
import 'package:homizi/features/nearby/nearby_places_page.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';
import 'package:homizi/features/nearby/nearby_row.dart';

/// The first few nearby rows on a listing, plus See all.
class NearbyPlacesPreview extends ConsumerStatefulWidget {
  const NearbyPlacesPreview({
    required this.cacheKey,
    required this.city,
    required this.locality,
    this.latitude,
    this.longitude,
    this.listing,
    this.count = 4,
    super.key,
  });

  final String cacheKey;
  final String city;
  final String locality;
  final double? latitude;
  final double? longitude;
  final Listing? listing;
  final int count;

  @override
  ConsumerState<NearbyPlacesPreview> createState() =>
      _NearbyPlacesPreviewState();
}

class _NearbyPlacesPreviewState extends ConsumerState<NearbyPlacesPreview> {
  List<NearbyCommuteRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(nearbyPlacesServiceProvider)
        .peek(
          cacheKey: widget.cacheKey,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
    _rows = cached ?? const [];
    if (cached == null) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant NearbyPlacesPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.locality != widget.locality) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final rows = await ref
        .read(nearbyPlacesServiceProvider)
        .load(
          cacheKey: widget.cacheKey,
          city: widget.city,
          locality: widget.locality,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
    if (!mounted) {
      return;
    }
    setState(() => _rows = rows);
  }

  void _seeAll() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NearbyPlacesPage(
          cacheKey: widget.cacheKey,
          city: widget.city,
          locality: widget.locality,
          latitude: widget.latitude,
          longitude: widget.longitude,
          listing: widget.listing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = _rows.take(widget.count).toList();
    return Column(
      key: const Key('listing-nearby-places'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                homiziText(context, 'Nearby places'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              key: const Key('listing-nearby-see-all'),
              onPressed: _seeAll,
              child: Text(
                homiziText(context, 'See all'),
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        for (final row in shown) NearbyCommuteTile(row: row),
      ],
    );
  }
}
