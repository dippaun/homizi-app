import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

class PricePin extends StatelessWidget {
  const PricePin({required this.rentInr, this.onTap, this.count, super.key});

  final int rentInr;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final clustered = count != null && count! > 1;
    final label = clustered ? '$count' : formatInr(rentInr);
    return Material(
      color: clustered ? HomiziColors.accent : HomiziColors.white,
      elevation: 2,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.accent, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: const Color(0xF2FFFFFF),
        child: Text(
          '© OpenStreetMap contributors',
          key: const Key('osm-attribution'),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: HomiziColors.ink),
        ),
      ),
    );
  }
}
