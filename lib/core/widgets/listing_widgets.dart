import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
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
          '${formatInr(listing.rentInr)}/mo',
          style:
              (large
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(color: HomiziColors.ink),
        ),
        const SizedBox(height: 2),
        Text(
          'Deposit ${formatInr(listing.depositInr)}',
          style: theme.textTheme.bodySmall,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          InputChip(label: Text(label), onPressed: () {}),
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
    return InputChip(
      avatar: showCheck
          ? const Icon(Icons.verified, size: 18, color: HomiziColors.accent)
          : null,
      label: Text(label),
      onPressed: () {},
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
        initials(name),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: HomiziColors.ink),
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
    final place = [locality, city].where((part) => part.isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _MapPainter()),
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
                        place,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The street address stays off this map until a visit is agreed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F7F7),
    );
    final road = Paint()
      ..color = const Color(0xFFE3E3E3)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(size.width, size.height * 0.46),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.42, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.62, size.height),
      road..strokeWidth = 6,
    );
    final pin = Offset(size.width * 0.58, size.height * 0.42);
    canvas.drawCircle(pin, 16, Paint()..color = HomiziColors.accent);
    canvas.drawCircle(pin, 6, Paint()..color = HomiziColors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}
