import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/ui/kit/real_life_icons.dart';

/// One like, match, or saved-home row: circle photo, details, highlights.
class EngagementRow extends StatelessWidget {
  const EngagementRow({
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.price = '',
    this.photoRef,
    this.thumbnailRef,
    this.person = false,
    this.highlights = const [],
    this.preview,
    this.qualities = const [],
    this.matchLabel,
    this.uniform = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String price;
  final String? photoRef;
  final String? thumbnailRef;
  final bool person;
  final List<(IconData, String)> highlights;

  final String? preview;

  /// Roommate quality icons, strongest painted on the right.
  final List<(IconData, String)> qualities;

  /// Match percent or another short trailing label, aligned with the icons.
  final String? matchLabel;

  /// One height for every Matches row so cards line up.
  final bool uniform;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HomiziColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SizedBox(
              height: uniform ? 72 : null,
              child: Row(
                children: [
                  PersonPhoto(
                    name: title,
                    photoRef: photoRef,
                    diameter: 52,
                    personOnly: person,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle.trim().isNotEmpty)
                          Text(
                            homiziText(context, subtitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomiziColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        if (price.trim().isNotEmpty)
                          Text(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        if (preview != null && preview!.trim().isNotEmpty)
                          Text(
                            homiziText(context, preview!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomiziColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        if (highlights.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final item in highlights.take(4))
                                _Highlight(icon: item.$1, label: item.$2),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((matchLabel != null && matchLabel!.trim().isNotEmpty) ||
                      qualities.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (matchLabel != null &&
                              matchLabel!.trim().isNotEmpty)
                            Text(
                              matchLabel!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomiziColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          if (qualities.isNotEmpty)
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                for (final item in qualities.take(4))
                                  Tooltip(
                                    message: homiziText(context, item.$2),
                                    child: Icon(
                                      item.$1,
                                      size: 16,
                                      color: HomiziColors.logoOrange,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (thumbnailRef != null &&
                      thumbnailRef!.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ListingPhoto(asset: thumbnailRef),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: HomiziColors.logoOrange),
            const SizedBox(width: 3),
            Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<(IconData, String)> homeHighlightIcons({
  required String bhk,
  required String furnishing,
  required bool parking,
  required bool pets,
  required bool vegOnly,
}) {
  return [
    if (bhk.trim().isNotEmpty) (RealLifeIcons.house, bhk),
    if (furnishing.trim().isNotEmpty) (RealLifeIcons.furnished, furnishing),
    if (vegOnly) (RealLifeIcons.veg, 'Veg'),
    if (pets) (RealLifeIcons.pets, 'Pets'),
    if (parking) (RealLifeIcons.parking, 'Parking'),
  ];
}
