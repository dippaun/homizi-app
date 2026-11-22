import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/homizi_portrait.dart';
import 'package:homizi/features/discovery/poster_badge.dart';
import 'package:homizi/shared/widgets/homizi_match_card.dart';

enum HomiziPropertyCardVariant { full, compact }

enum HomiziDetailIcon { room, bhk, area, floor, person, work, calendar }

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
    this.hostIdentityVerified = false,
    this.hostRole = '',
    this.responseLabel,
    this.commuteLabel,
    this.placesTitle = 'Nearby Places',
    this.person = false,
    this.badge,
    this.cityNote,
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

  /// Aadhaar and face confirmed by Digio (server badges only).
  final bool hostIdentityVerified;
  final String hostRole;
  final String? responseLabel;
  final List<HomiziNearbyPlace> nearby;

  /// A line from the maps provider. Null hides the commute row.
  final String? commuteLabel;

  /// Title above [nearby]. Roommate cards use this for lifestyle icons.
  final String placesTitle;

  /// A roommate seeker, not a home. The photo is a portrait, not a listing.
  final bool person;

  /// Short label such as Shared room. Null hides the chip.
  final String? badge;

  /// "Different city · Mumbai" when the home is outside the viewer's city.
  final String? cityNote;
}

/// Full swipe card, or the shorter card lists reuse.
class HomiziPropertyCard extends StatefulWidget {
  const HomiziPropertyCard({
    required this.data,
    super.key,
    this.variant = HomiziPropertyCardVariant.full,
    this.onTap,
    this.onSave,
    this.onContact,
    this.onSkip,
    this.onInterested,
    this.onWhy,
    this.onNearby,
    this.scrollController,
    this.busy = false,
    this.photoAlignment = Alignment.center,
  });

  final HomiziPropertyCardData data;
  final HomiziPropertyCardVariant variant;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onContact;
  final VoidCallback? onSkip;
  final VoidCallback? onInterested;
  final VoidCallback? onWhy;

  /// Opens the full nearby list. The icon row stays in this card.
  final VoidCallback? onNearby;
  final ScrollController? scrollController;
  final bool busy;

  /// Cover crop for the photo. People use `(0, -0.3)` so the face stays visible.
  final Alignment photoAlignment;

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
    if (compact) {
      return _compact(context);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        key: Key('property-card-${widget.data.id}'),
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: _full(context),
      ),
    );
  }

  Widget _full(BuildContext context) {
    final data = widget.data;
    return Column(
      children: [
        _photos(context, height: 210),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _titleRow(context),
              if (data.cityNote != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HomiziChipView(
                    chip: HomiziCardChip(
                      data.cityNote!,
                      icon: Icons.location_city_outlined,
                      chipKey: Key('different-city-${data.id}'),
                    ),
                  ),
                ),
              ],
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
              if (!data.person && data.hostName.trim().isNotEmpty) ...[
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
              if (widget.onSkip != null || widget.onInterested != null) ...[
                const SizedBox(height: 16),
                _actions(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _compact(BuildContext context) {
    final data = widget.data;
    final frames = _frames();
    return HomiziMatchCard(
      cardKey: Key('property-card-${data.id}'),
      titleKey: const Key('property-card-title'),
      priceKey: const Key('property-card-rent'),
      placeKey: const Key('property-card-place'),
      title: data.title,
      price: data.rentLabel,
      locality: data.place,
      photos: [for (final photo in frames) photo.ref],
      photoSeed: data.id,
      verified: data.verifiedListing || data.hostVerified,
      matchPercent: data.matchPercent,
      matchKey: data.matchPercent == null
          ? null
          : Key('property-match-${data.matchPercent}'),
      onMatchTap: widget.onWhy,
      onTap: widget.onTap,
      chips: [
        if (data.cityNote != null)
          HomiziCardChip(
            data.cityNote!,
            icon: Icons.location_city_outlined,
            chipKey: Key('different-city-${data.id}'),
          ),
        if (data.verifiedListing)
          const HomiziCardChip('Verified Listing', verified: true),
        for (final detail in data.details.take(2)) HomiziCardChip(detail.label),
        for (final name in data.amenities.take(1)) HomiziCardChip(name),
      ],
      footer: data.matchPercent == null && widget.onWhy != null
          ? Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('set-preferences-for-match'),
                onPressed: widget.onWhy,
                child: Text(
                  homiziText(context, 'Set preferences to see your match'),
                ),
              ),
            )
          : null,
      actions: [
        if (widget.onSave != null)
          HomiziCardAction(
            actionKey: const Key('property-save'),
            tooltip: data.saved ? 'Remove save' : 'Save',
            icon: data.saved ? Icons.favorite : Icons.favorite_border,
            filled: data.saved,
            onPressed: widget.busy ? null : widget.onSave,
          ),
        if (widget.onContact != null)
          HomiziCardAction(
            actionKey: const Key('property-card-contact'),
            tooltip: 'Contact',
            icon: Icons.chat_bubble_outline,
            onPressed: widget.busy ? null : widget.onContact,
          ),
      ],
    );
  }

  List<HomiziPropertyPhoto> _frames() {
    final supplied = [
      for (final photo in widget.data.photos)
        if (photo.ref.trim().isNotEmpty) photo,
    ];
    if (supplied.isNotEmpty) {
      if (widget.data.person) {
        return supplied;
      }
      final homes = [
        for (final photo in supplied)
          if (!_isFace(photo.ref)) photo,
      ];
      if (homes.isNotEmpty) {
        return homes;
      }
    }
    return [
      HomiziPropertyPhoto(
        ref: homiziFallbackPhoto(widget.data.id),
        caption: 'Home',
      ),
    ];
  }

  bool _isFace(String ref) {
    final lower = ref.toLowerCase();
    return lower.contains('/avatars/') || lower.contains('avatar_');
  }

  Widget _photos(BuildContext context, {required double height}) {
    final photos = _frames();
    final index = _photo.clamp(0, photos.length - 1);
    final full = widget.variant == HomiziPropertyCardVariant.full;
    final badges = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.data.matchPercent != null)
          _MatchBadge(percent: widget.data.matchPercent!, onTap: widget.onWhy)
        else if (widget.onWhy != null)
          TextButton(
            key: const Key('set-preferences-for-match'),
            onPressed: widget.onWhy,
            child: Text(
              homiziText(context, 'Set preferences to see your match'),
            ),
          ),
        if (widget.data.verifiedListing && !widget.data.person)
          const _VerifiedListing(),
      ],
    );
    if (widget.data.person) {
      final photo = (widget.data.hostAvatarRef ?? photos.first.ref).trim();
      return ColoredBox(
        color: const Color(0xFFFFF6EE),
        child: Center(
          child: HomiziPortrait(
            photo: photo,
            verified: widget.data.hostIdentityVerified,
            semanticLabel: widget.data.title,
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: Key('property-photos-${widget.data.id}'),
            itemCount: photos.length,
            onPageChanged: (next) => setState(() => _photo = next),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: widget.onTap,
                child: ListingPhoto(
                  asset: photos[i].ref,
                  fallbackAsset: homiziFallbackPhoto(widget.data.id),
                  semanticLabel: photos[i].caption,
                  alignment: widget.photoAlignment,
                ),
              );
            },
          ),
          if (full)
            Positioned(left: 12, top: 12, right: 64, child: badges)
          else
            Positioned(left: 12, right: 12, bottom: 12, child: badges),
          if (photos.length > 1 && full)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: _FullPhotoMeta(
                index: index,
                total: photos.length,
                caption: photos[index].caption,
              ),
            ),
          if (photos.length > 1 && !full)
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
          if (widget.onContact != null)
            Positioned(
              top: 56,
              right: 8,
              child: Material(
                color: HomiziColors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('property-card-contact'),
                  tooltip: homiziText(context, 'Contact'),
                  onPressed: widget.busy ? null : widget.onContact,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: HomiziColors.ink,
                  ),
                ),
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
                  textAlign: widget.data.person
                      ? TextAlign.center
                      : TextAlign.start,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if ((widget.data.badge ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: Key('property-badge-${widget.data.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: HomiziColors.accentWash,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      homiziText(context, widget.data.badge!),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
    final reasons = <String>[];
    final seen = <String>{};
    for (final line in widget.data.topReasons) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed.toLowerCase())) {
        reasons.add(trimmed);
      }
    }
    if (widget.data.person) {
      return _personWhy(context, reasons);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            widget.data.person
                ? 'Why this match'
                : 'Why this is a great match for you (Top 5)',
          ),
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

  Widget _personWhy(BuildContext context, List<String> reasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Why this match'),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < reasons.length; index++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 220 + index * 40),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset((1 - value) * 8, 0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: Key('roommate-why-$index'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HomiziColors.successWash,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HomiziColors.success),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: HomiziColors.success,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          homiziText(context, reasons[index]),
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _host(BuildContext context) {
    final data = widget.data;
    final initial = data.hostName.trim().isEmpty
        ? '?'
        : data.hostName.trim()[0].toUpperCase();
    return InkWell(
      onTap: widget.onTap,
      child: Row(
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
                    if (data.hostIdentityVerified)
                      const Row(
                        key: Key('property-card-aadhaar-verified'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: HomiziColors.success,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Aadhaar verified',
                            style: TextStyle(
                              color: HomiziColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    else if (data.hostVerified || data.verifiedListing)
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
                      )
                    else
                      Container(
                        key: const Key('property-card-verification-pending'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HomiziColors.warningWash,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Verification pending',
                          style: TextStyle(
                            color: HomiziColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (data.person)
                      const _RoommateBadge()
                    else if (data.hostRole.isNotEmpty)
                      PosterKindBadge(kind: data.hostRole),
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
          const Icon(Icons.chevron_right, color: HomiziColors.muted),
        ],
      ),
    );
  }

  Widget _avatar(String? ref, String initial) {
    final kind = photoKind(ref);
    final cacheWidth = (44 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 256)
        .toInt();
    if (kind == PhotoKind.asset && ref != null) {
      return ClipOval(
        child: Image.asset(
          ref,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
        ),
      );
    }
    if (kind == PhotoKind.network && ref != null) {
      return ClipOval(
        child: Image.network(
          ref,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
        ),
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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, widget.data.placesTitle),
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
    final open = widget.onNearby;
    if (open == null) {
      return body;
    }
    return InkWell(
      key: Key('property-nearby-${widget.data.id}'),
      onTap: open,
      child: body,
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
  const _MatchBadge({required this.percent, this.onTap});

  final int percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
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
    final tap = onTap;
    if (tap == null) {
      return badge;
    }
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: badge,
    );
  }
}

class _RoommateBadge extends StatelessWidget {
  const _RoommateBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('roommate-seeker-badge'),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 14, color: Color(0xFF3D2E8C)),
            SizedBox(width: 4),
            Text(
              'Roommate',
              style: TextStyle(
                color: Color(0xFF3D2E8C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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

class _FullPhotoMeta extends StatelessWidget {
  const _FullPhotoMeta({
    required this.index,
    required this.total,
    required this.caption,
  });

  final int index;
  final int total;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _PhotoCount(index: index + 1, total: total, caption: caption),
        ),
        const SizedBox(height: 6),
        Row(
          key: const Key('property-photo-dots'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                width: i == index ? 7 : 5,
                height: i == index ? 7 : 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == index ? HomiziColors.white : HomiziColors.line,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ],
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
  HomiziDetailIcon.person => Icons.cake_outlined,
  HomiziDetailIcon.work => Icons.work_outline,
  HomiziDetailIcon.calendar => Icons.calendar_month_outlined,
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
  'food' => Icons.eco_outlined,
  'smoke' => Icons.smoke_free,
  'drink' => Icons.local_bar_outlined,
  'pet' => Icons.pets,
  'work' => Icons.laptop_mac_outlined,
  'sleep' => Icons.bedtime_outlined,
  'clean' => Icons.cleaning_services_outlined,
  _ => Icons.place_outlined,
};
