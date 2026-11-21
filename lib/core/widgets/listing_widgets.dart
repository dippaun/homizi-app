import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/avatar_ref.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    this.asset,
    this.semanticLabel,
    this.fallbackAsset,
    this.alignment = Alignment.center,
    super.key,
  });

  final String? asset;

  /// Spoken name for this frame. A caption, or the room type when it is empty.
  final String? semanticLabel;

  /// Real bundled photo used when [asset] is missing or fails to load.
  final String? fallbackAsset;

  /// Face photos use [Alignment.topCenter] so the crop keeps the face.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = _image(context);
    final label = semanticLabel?.trim();
    if (label == null || label.isEmpty) {
      return image;
    }
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: image),
    );
  }

  Widget _image(BuildContext context) {
    final path = photoRefForDisplay(asset);
    final kind = photoKind(path);
    if (kind == PhotoKind.empty || path == null) {
      return _standIn();
    }
    if (kind == PhotoKind.network) {
      final shown = listingThumbnailUrl(path);
      // One cache dimension. Width and height together force the decoded
      // bitmap into that box and stretch a face into a thin band.
      final cacheWidth = listingPhotoCacheWidth(context);
      return Image.network(
        shown,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: _frame,
        errorBuilder: (context, error, stackTrace) {
          if (shown == path) {
            return _standIn();
          }
          return Image.network(
            path,
            fit: BoxFit.cover,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            frameBuilder: _frame,
            errorBuilder: (context, error, stackTrace) => _standIn(),
          );
        },
      );
    }
    if (kind == PhotoKind.dataUrl) {
      final bytes = dataUrlBytes(path);
      if (bytes == null) {
        return _standIn();
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        frameBuilder: _frame,
        errorBuilder: (context, error, stackTrace) => _standIn(),
      );
    }
    return _assetFrame(context, path);
  }

  Widget _assetFrame(BuildContext context, String path) {
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
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          frameBuilder: _frame,
          errorBuilder: (context, error, stackTrace) => _standIn(),
        );
      },
    );
  }

  Widget _frame(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      return child;
    }
    return _standIn();
  }

  /// A real photo when one was supplied. Otherwise a bundled home frame.
  Widget _standIn() {
    final supplied = fallbackAsset?.trim();
    final fallback = supplied != null && photoKind(supplied) == PhotoKind.asset
        ? supplied
        : fallbackHomePhoto((asset ?? fallbackAsset).hashCode);
    return Image.asset(
      fallback,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: HomiziColors.soft),
    );
  }
}

/// Initials stand in for a photo so the face matches the name.
class InitialsPortrait extends StatelessWidget {
  const InitialsPortrait({required this.name, required this.gender, super.key});

  final String name;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    final woman = gender == 'woman' || gender == 'female';
    return ColoredBox(
      color: woman ? HomiziColors.accentWash : HomiziColors.mist,
      child: Center(
        child: Text(
          initials(name),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Decode width shared by the swipe card and [precacheImage] so the next
/// cards hit the same cache entry.
///
/// Pass this alone. A second cache dimension resizes the bitmap to that exact
/// box and stretches the photo.
int listingPhotoCacheWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final logical = size.width < 640 ? size.width : 480.0;
  return (logical * MediaQuery.devicePixelRatioOf(context)).round().clamp(
    64,
    720,
  );
}

ImageProvider<Object> listingPhotoImage(String ref, {required int cacheWidth}) {
  final displayed = photoRefForDisplay(ref) ?? ref;
  if (photoKind(displayed) == PhotoKind.asset) {
    return ResizeImage.resizeIfNeeded(cacheWidth, null, AssetImage(displayed));
  }
  final shown = listingThumbnailUrl(displayed);
  return ResizeImage.resizeIfNeeded(cacheWidth, null, NetworkImage(shown));
}

/// Static wash shown until a listing photo has a frame.
class PhotoShimmer extends StatelessWidget {
  const PhotoShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HomiziColors.mist,
            HomiziColors.accentWash,
            HomiziColors.mist,
          ],
        ),
      ),
      child: Center(child: HomiziMark(size: 36)),
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
    // Home and Explore both keep their cards in the shell's indexed stack.
    // Only the visible branch may register a hero, or the flight throws.
    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Hero(tag: tag, child: labeled),
    );
  }
}

class ListingGallery extends StatelessWidget {
  const ListingGallery({
    required this.assets,
    required this.heroTag,
    this.labels = const [],
    super.key,
  });

  final List<String> assets;
  final String heroTag;

  /// One label per [assets] entry. Empty falls back to "Photo".
  final List<String> labels;

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
        children: [
          for (var index = 0; index < photos.length; index++)
            _GalleryFrame(
              asset: photos[index],
              label: _labelAt(index),
              index: index,
            ),
        ],
      ),
    );
  }

  String _labelAt(int index) {
    if (index < labels.length && labels[index].trim().isNotEmpty) {
      return labels[index].trim();
    }
    return 'Photo';
  }
}

class _GalleryFrame extends StatelessWidget {
  const _GalleryFrame({
    required this.asset,
    required this.label,
    required this.index,
  });

  final String asset;
  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ListingPhoto(asset: asset.isEmpty ? null : asset, semanticLabel: label),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: HomiziColors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  key: Key('listing-gallery-caption-$index'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: HomiziColors.ink),
                ),
              ),
            ),
          ),
        ),
      ],
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
      for (final tag in listing.friendlyTags) listingFriendlyTagLabel(tag),
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
            side: BorderSide.none,
            backgroundColor: HomiziColors.mist,
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
      side: BorderSide.none,
      backgroundColor: showCheck ? HomiziColors.accentWash : HomiziColors.mist,
    );
  }
}

class HostAvatar extends StatelessWidget {
  const HostAvatar({
    required this.name,
    this.photoRef,
    this.radius = 22,
    super.key,
  });

  final String name;
  final String? photoRef;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return PersonPhoto(name: name, photoRef: photoRef, diameter: radius * 2);
  }
}

/// Circular portrait. Own bytes or a person photo only — never a listing
/// frame, and never both cache width and cache height (that stretches).
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({
    required this.name,
    this.photoRef,
    this.bytes,
    this.diameter,
    this.personOnly = true,
    super.key,
  });

  final String name;
  final String? photoRef;
  final Uint8List? bytes;
  final double? diameter;
  final bool personOnly;

  @override
  Widget build(BuildContext context) {
    final side = diameter;
    if (side == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 96.0;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : width;
          final box = width < height ? width : height;
          return _oval(context, box);
        },
      );
    }
    return _oval(context, side);
  }

  Widget _oval(BuildContext context, double side) {
    return ClipOval(
      child: SizedBox(
        width: side,
        height: side,
        child: ColoredBox(
          color: HomiziColors.accentWash,
          child: _image(context, side),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, double side) {
    final photo = bytes;
    if (photo != null && photo.isNotEmpty) {
      final cacheWidth = (side * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(48, 960);
      return Image(
        image: ResizeImage(MemoryImage(photo), width: cacheWidth),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: side,
        height: side,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _initials(side),
      );
    }
    final path = displayAvatarRef(photoRef) ?? '';
    if (path.isEmpty || (personOnly && isListingPhotoPath(path))) {
      return _initials(side);
    }
    final kind = photoKind(path);
    if (kind == PhotoKind.empty) {
      return _initials(side);
    }
    final cacheWidth = (side * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 960);
    final ImageProvider<Object> provider;
    if (kind == PhotoKind.asset) {
      provider = ResizeImage(AssetImage(path), width: cacheWidth);
    } else if (kind == PhotoKind.dataUrl) {
      final raw = dataUrlBytes(path);
      if (raw == null || raw.isEmpty) {
        return _initials(side);
      }
      provider = ResizeImage(MemoryImage(raw), width: cacheWidth);
    } else {
      provider = ResizeImage(
        NetworkImage(
          path.contains('/avatars/') ? path : listingThumbnailUrl(path),
        ),
        width: cacheWidth,
      );
    }
    return Image(
      image: provider,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      width: side,
      height: side,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _initials(side),
    );
  }

  Widget _initials(double side) {
    return Center(
      child: Text(
        initials(name),
        style: TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: side * 0.34,
        ),
      ),
    );
  }
}

/// Home frames must not stand in for a person's display photo.
bool isListingPhotoPath(String path) {
  final value = path.toLowerCase();
  return value.contains('assets/images/') ||
      value.contains('/listings/') ||
      value.contains('listing-photo');
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
