import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';

enum HomiziPropertyCardVariant { full, compact }

enum HomiziDetailIcon { room, bhk, area, floor }

class HomiziPropertyPhoto {
  const HomiziPropertyPhoto({required this.ref, required this.caption});

  final String ref;
  final String caption;
}

class HomiziPropertyDetail {
  const HomiziPropertyDetail({required this.icon, required this.label});

  final HomiziDetailIcon icon;
  final String label;
}

class HomiziNearbyPlace {
  const HomiziNearbyPlace({
    required this.kind,
    required this.label,
    required this.distanceLabel,
  });

  final String kind;
  final String label;
  final String distanceLabel;
}

/// Data for the one property card used on the swipe deck and in lists.
class HomiziPropertyCardData {
  const HomiziPropertyCardData({
    required this.id,
    required this.title,
    required this.place,
    required this.rentLabel,
    required this.photos,
    required this.details,
    required this.amenities,
    required this.topReasons,
    required this.hostName,
    required this.nearby,
    this.matchPercent,
    this.verifiedListing = false,
    this.saved = false,
    this.hostAvatarRef,
    this.hostVerified = false,
    this.hostRole = '',
    this.responseLabel,
    this.commuteLabel,
  });

  final String id;
  final String title;
  final String place;
  final String rentLabel;
  final int? matchPercent;
  final bool verifiedListing;
  final bool saved;
  final List<HomiziPropertyPhoto> photos;
  final List<HomiziPropertyDetail> details;
  final List<String> amenities;
  final List<String> topReasons;
  final String hostName;
  final String? hostAvatarRef;
  final bool hostVerified;
  final String hostRole;
  final String? responseLabel;
  final List<HomiziNearbyPlace> nearby;

  /// A line from the maps provider. Null hides the commute row.
  final String? commuteLabel;
}

/// Full swipe card, or the shorter card lists reuse.
class HomiziPropertyCard extends StatefulWidget {
  const HomiziPropertyCard({
    required this.data,
    super.key,
    this.variant = HomiziPropertyCardVariant.full,
    this.onTap,
    this.onSave,
    this.onSkip,
    this.onInterested,
    this.onWhy,
    this.busy = false,
  });

  final HomiziPropertyCardData data;
  final HomiziPropertyCardVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onSkip;
  final VoidCallback? onInterested;
  final VoidCallback? onWhy;
  final bool busy;

  @override
  State<HomiziPropertyCard> createState() => _HomiziPropertyCardState();
}

class _HomiziPropertyCardState extends State<HomiziPropertyCard> {
  var _photo = 0;

  @override
  void didUpdateWidget(covariant HomiziPropertyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _photo = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.variant == HomiziPropertyCardVariant.compact;
    return Material(
      key: Key('property-card-${widget.data.id}'),
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: HomiziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: compact ? _compact(context) : _full(context),
    );
  }

  Widget _full(BuildContext context) {
    final data = widget.data;
    return Column(
      children: [
        _photos(context, height: 210),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _titleRow(context),
              const SizedBox(height: 12),
              _details(context),
              if (data.amenities.isNotEmpty) ...[
                const SizedBox(height: 12),
                _amenityWrap(context),
              ],
              if (data.topReasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                _why(context),
              ],
              if (data.hostName.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _host(context),
              ],
              if (data.nearby.isNotEmpty) ...[
                const SizedBox(height: 16),
                _nearby(context),
              ],
              if (data.commuteLabel != null) ...[
                const SizedBox(height: 12),
                Text(
                  homiziText(context, data.commuteLabel!),
                  key: const Key('property-commute'),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compact(BuildContext context) {
    final data = widget.data;
    return InkWell(
      onTap: widget.onTap,
      // Same white face on every card: no hover tint on web.
      hoverColor: HomiziColors.clear,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _photos(context, height: 168),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _compactInfo(context),
                if (data.details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _details(context),
                ],
                if (data.amenities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _amenityWrap(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact text block: title (1 line), price, then location on its own
  /// full-width row (max 2 lines) so it never breaks mid-word.
  Widget _compactInfo(BuildContext context) {
    final data = widget.data;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('property-card-compact-info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          homiziText(context, data.title),
          key: const Key('property-card-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(context, data.rentLabel),
          key: const Key('property-card-rent'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall?.copyWith(
            color: HomiziColors.logoOrange,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.location_on_outlined,
                size: 16,
                color: HomiziColors.muted,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                homiziText(context, data.place),
                key: const Key('property-card-place'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomiziColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _photos(BuildContext context, {required double height}) {
    final photos = widget.data.photos;
    final index = photos.isEmpty ? 0 : _photo.clamp(0, photos.length - 1);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            const ColoredBox(
              color: HomiziColors.soft,
              child: Icon(Icons.apartment, color: HomiziColors.muted, size: 48),
            )
          else
            PageView.builder(
              key: Key('property-photos-${widget.data.id}'),
              itemCount: photos.length,
              onPageChanged: (next) => setState(() => _photo = next),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: widget.onTap,
                  child: ListingPhoto(
                    asset: photos[i].ref,
                    semanticLabel: photos[i].caption,
                  ),
                );
              },
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.data.matchPercent != null)
                  _MatchBadge(percent: widget.data.matchPercent!),
                if (widget.data.verifiedListing) const _VerifiedListing(),
              ],
            ),
          ),
          if (photos.length > 1)
            Positioned(
              left: 12,
              bottom: widget.data.matchPercent == null ? 12 : 48,
              child: _PhotoCount(
                index: index + 1,
                total: photos.length,
                caption: photos[index].caption,
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: _SaveButton(
              saved: widget.data.saved,
              busy: widget.busy,
              onPressed: widget.onSave,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, widget.data.title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: HomiziColors.muted,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        homiziText(context, widget.data.place),
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              homiziText(context, widget.data.rentLabel),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: HomiziColors.logoOrange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final detail in widget.data.details)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_detailIcon(detail.icon), size: 16, color: HomiziColors.ink),
              const SizedBox(width: 4),
              Text(
                homiziText(context, detail.label),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _amenityWrap(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in widget.data.amenities)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomiziColors.successWash,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_amenityIcon(name), size: 14, color: HomiziColors.success),
                const SizedBox(width: 4),
                Text(
                  homiziText(context, name),
                  style: const TextStyle(
                    color: HomiziColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _why(BuildContext context) {
    final reasons = widget.data.topReasons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Why this is a great match for you (Top 5)'),
          style: const TextStyle(
            color: HomiziColors.success,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: Key('property-why-${widget.data.id}'),
            onPressed: widget.onWhy ?? widget.onTap,
            style: TextButton.styleFrom(
              foregroundColor: HomiziColors.logoOrange,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(homiziText(context, 'View Match Details >')),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < reasons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: HomiziColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: HomiziColors.onSuccess,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    homiziText(context, reasons[i]),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _host(BuildContext context) {
    final data = widget.data;
    final initial = data.hostName.trim().isEmpty
        ? '?'
        : data.hostName.trim()[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: HomiziColors.soft,
          child: _avatar(data.hostAvatarRef, initial),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, data.hostName),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (data.hostVerified)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: HomiziColors.success,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Verified Host',
                          style: TextStyle(
                            color: HomiziColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (data.hostRole.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomiziColors.line),
                      ),
                      child: Text(
                        homiziText(context, data.hostRole),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (data.responseLabel != null)
                Text(
                  homiziText(context, data.responseLabel!),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String? ref, String initial) {
    final kind = photoKind(ref);
    if (kind == PhotoKind.asset && ref != null) {
      return ClipOval(
        child: Image.asset(ref, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    if (kind == PhotoKind.network && ref != null) {
      return ClipOval(
        child: Image.network(ref, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Text(
      initial,
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _nearby(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Nearby Places'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final place in widget.data.nearby)
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      _nearbyIcon(place.kind),
                      size: 22,
                      color: HomiziColors.inkSoft,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        place.distanceLabel,
                        maxLines: 1,
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        homiziText(context, place.label),
                        maxLines: 1,
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('match-skip'),
            onPressed: widget.busy ? null : widget.onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.logoOrange,
              side: const BorderSide(
                color: HomiziColors.logoOrange,
                width: 1.5,
              ),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: const Icon(Icons.close),
            label: Text(homiziText(context, 'Skip')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            key: const Key('match-interested'),
            onPressed: widget.busy ? null : widget.onInterested,
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.logoOrange,
              foregroundColor: HomiziColors.ink,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: const Icon(Icons.favorite),
            label: Text(homiziText(context, "I'm Interested")),
          ),
        ),
      ],
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('property-match-$percent'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HomiziColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        homiziText(context, '$percent% Match'),
        style: const TextStyle(
          color: HomiziColors.onSuccess,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _VerifiedListing extends StatelessWidget {
  const _VerifiedListing();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: HomiziColors.success),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Verified Listing',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCount extends StatelessWidget {
  const _PhotoCount({
    required this.index,
    required this.total,
    required this.caption,
  });

  final int index;
  final int total;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.night,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        homiziText(context, '$index/$total  $caption'),
        style: const TextStyle(
          color: HomiziColors.nightInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saved,
    required this.busy,
    required this.onPressed,
  });

  final bool saved;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shape: const CircleBorder(),
      child: IconButton(
        key: const Key('property-save'),
        tooltip: homiziText(context, saved ? 'Remove save' : 'Save'),
        onPressed: busy ? null : onPressed,
        icon: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: HomiziColors.logoOrange,
        ),
      ),
    );
  }
}

IconData _detailIcon(HomiziDetailIcon icon) => switch (icon) {
  HomiziDetailIcon.room => Icons.bed_outlined,
  HomiziDetailIcon.bhk => Icons.apartment_outlined,
  HomiziDetailIcon.area => Icons.square_foot,
  HomiziDetailIcon.floor => Icons.stairs_outlined,
};

IconData _amenityIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('furnish')) {
    return Icons.chair_outlined;
  }
  if (lower == 'ac') {
    return Icons.ac_unit;
  }
  if (lower.contains('wifi') || lower.contains('wi-fi')) {
    return Icons.wifi;
  }
  if (lower.contains('smok')) {
    return Icons.smoke_free;
  }
  if (lower.contains('bachelor')) {
    return Icons.person_outline;
  }
  if (lower.contains('lift')) {
    return Icons.elevator_outlined;
  }
  return Icons.check_circle_outline;
}

IconData _nearbyIcon(String kind) => switch (kind) {
  'metro' => Icons.subway_outlined,
  'station' || 'train' => Icons.train_outlined,
  'supermarket' => Icons.local_grocery_store_outlined,
  'hospital' => Icons.local_hospital_outlined,
  'gym' => Icons.fitness_center,
  _ => Icons.place_outlined,
};
