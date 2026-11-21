import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';

/// Face portrait. Cover is clipped to a circle and anchored at the top
/// so the face stays in frame. The ring is the Homizi orange-purple mark.
class HomiziPortrait extends StatelessWidget {
  const HomiziPortrait({
    required this.photo,
    this.verified = false,
    this.size = 168,
    this.semanticLabel = '',
    super.key,
  });

  final String photo;
  final bool verified;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 14,
      height: size + 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 10,
            height: size + 10,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomiziColors.logoOrange, HomiziColors.homiziPurple],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: HomiziColors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: ListingPhoto(
                    asset: photo,
                    semanticLabel: semanticLabel,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
          if (verified)
            Positioned(
              right: 6,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomiziColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: HomiziColors.success, width: 2),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.verified,
                    color: HomiziColors.success,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
