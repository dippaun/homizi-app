import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

class ListingPhoto extends StatelessWidget {
  const ListingPhoto({this.asset, super.key});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null || path.isEmpty) {
      return const PhotoFallback();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (logical * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(48, 1280);
        return Image.asset(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const PhotoFallback(),
        );
      },
    );
  }
}

class PhotoFallback extends StatelessWidget {
  const PhotoFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: HomiziColors.mist,
      child: Center(child: HomiziMark()),
    );
  }
}

/// Horizontal photo carousel with a page label and optional hero flight.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({
    required this.assets,
    this.heroTag,
    this.onTap,
    this.indicatorBottom = 10,
    super.key,
  });

  final List<String> assets;
  final String? heroTag;
  final VoidCallback? onTap;
  final double indicatorBottom;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.assets.where((asset) => asset.isNotEmpty).toList();
    final frames = photos.isEmpty ? const <String>[''] : photos;
    final scheme = Theme.of(context).colorScheme;
    final strip = Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: frames.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            final asset = frames[index];
            return GestureDetector(
              onTap: widget.onTap,
              child: ListingPhoto(asset: asset.isEmpty ? null : asset),
            );
          },
        ),
        if (frames.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.indicatorBottom,
            child: ExcludeSemantics(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < frames.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: i == _index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? HomiziColors.accent
                                  : scheme.onSurfaceVariant,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final labeled = Semantics(
      label: homiziText(context, 'Photo ${_index + 1} of ${frames.length}'),
      child: strip,
    );
    final tag = widget.heroTag;
    if (tag == null) {
      return labeled;
    }
    return Hero(tag: tag, child: labeled);
  }
}

class ListingGallery extends StatelessWidget {
  const ListingGallery({
    required this.assets,
    required this.heroTag,
    super.key,
  });

  final List<String> assets;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final photos = assets.isEmpty ? const <String>[''] : assets;
    final width = MediaQuery.sizeOf(context).width;
    return Hero(
      tag: heroTag,
      child: CarouselView(
        itemExtent: width < 48 ? 48 : width * 0.86,
        itemSnapping: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        children: [for (final asset in photos) ListingPhoto(asset: asset)],
      ),
    );
  }
}

class RentBlock extends StatelessWidget {
  const RentBlock({required this.listing, this.large = false, super.key});

  final Listing listing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, '${formatInr(listing.rentInr)}/mo'),
          style:
              (large
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          homiziText(context, 'Deposit ${formatInr(listing.depositInr)}'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (large && listing.maintenanceInr > 0)
          Text(
            homiziText(
              context,
              'Maintenance ${formatInr(listing.maintenanceInr)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (large && listing.brokerageInr > 0)
          Text(
            homiziText(context, 'Charges ${formatInr(listing.brokerageInr)}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class MetaChips extends StatelessWidget {
  const MetaChips({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      listing.bhkLabel,
      listing.furnishingLabel,
      if (listing.propertyTypeLabel != listing.bhkLabel)
        listing.propertyTypeLabel,
    ];
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Chip(
            label: Text(homiziText(context, label)),
            labelStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
            side: BorderSide(color: scheme.outline),
            backgroundColor: scheme.surface,
          ),
      ],
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({required this.label, this.showCheck = false, super.key});

  final String label;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: showCheck
          ? const Icon(Icons.verified, size: 18, color: HomiziColors.accent)
          : null,
      label: Text(homiziText(context, label)),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      side: BorderSide(color: showCheck ? HomiziColors.accent : scheme.outline),
      backgroundColor: scheme.surface,
    );
  }
}

class HostAvatar extends StatelessWidget {
  const HostAvatar({required this.name, this.radius = 22, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: HomiziColors.accentWash,
      child: Text(
        homiziText(context, initials(name)),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: HomiziColors.ink),
      ),
    );
  }
}

String initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'H';
  }
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class LocationBlock extends StatelessWidget {
  const LocationBlock({required this.locality, required this.city, super.key});

  final String locality;
  final String city;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final place = [locality, city].where((part) => part.isNotEmpty).join(', ');
    final km = aboutKmFromCityCentre(locality);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card.outlined(
          key: const Key('map-preview'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 188,
            child: Semantics(
              label: homiziText(context, 'Map preview'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _MapPainter(
                      ground: dark ? HomiziColors.night : HomiziColors.mist,
                      block: dark
                          ? HomiziColors.nightRaised
                          : HomiziColors.white,
                      road: dark ? HomiziColors.nightLine : HomiziColors.line,
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.place,
                      size: 36,
                      color: HomiziColors.accent,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          homiziText(context, 'Map preview'),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          homiziText(context, place),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (km != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'About $km km'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'The street address stays off this map until a visit is agreed.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.ground,
    required this.block,
    required this.road,
  });

  final Color ground;
  final Color block;
  final Color road;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final fill = Paint()..color = block;
    final rects = <Rect>[
      Rect.fromLTWH(16, 18, size.width * 0.22, size.height * 0.28),
      Rect.fromLTWH(
        size.width * 0.52,
        16,
        size.width * 0.34,
        size.height * 0.24,
      ),
      Rect.fromLTWH(
        18,
        size.height * 0.62,
        size.width * 0.28,
        size.height * 0.26,
      ),
      Rect.fromLTWH(
        size.width * 0.58,
        size.height * 0.66,
        size.width * 0.3,
        size.height * 0.22,
      ),
    ];
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fill,
      );
    }
    final paint = Paint()
      ..color = road
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.36, 0),
      Offset(size.width * 0.36, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, 0),
      Offset(size.width * 0.74, size.height),
      paint..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.ground != ground ||
        oldDelegate.block != block ||
        oldDelegate.road != road;
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, label),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
