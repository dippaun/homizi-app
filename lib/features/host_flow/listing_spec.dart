import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/host_flow/host_flow_chrome.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

/// Spec page 4 numbers location and nearby both as 2/8, then living as 4/8.
const listingFlowBadges = <String>[
  '1/8',
  '2/8',
  '2/8',
  '4/8',
  '5/8',
  '6/8',
  '7/8',
  '8/8',
];

const listingFlowTitles = <String>[
  'Start Listing Your Property',
  'Add Property Location',
  'Nearby Places (Auto-detected)',
  'Property & Living Details',
  'House Rules & Tenant Preference',
  'Services, Flatmates & Availability',
  'Rent & Charges',
  'Upload Property Photos',
];

const listingFlowSubtitles = <String>[
  'Choose what you want to list',
  'Enter the exact location and nearby details. We also detect nearby places automatically.',
  'We show estimated nearby places automatically. You can edit if needed.',
  'Add important details about your property.',
  'Set your preferences to find the right tenants.',
  'Add more details about services and availability.',
  'Be transparent about all costs.',
  'Minimum 3 photos required. Follow the sequence.',
];

const listingFlowSection = <String>[
  'I want to list',
  'Location Details',
  'Nearby places',
  'Property Details',
  'House Rules & Preferences',
  'Additional Details',
  'Rent & Charges',
  'Property Photos',
];

class ListingIntroPage extends StatelessWidget {
  const ListingIntroPage({
    required this.onBack,
    required this.onContinue,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const points = <(IconData, Color, String, String)>[
      (
        Icons.verified_outlined,
        HomiziColors.accent,
        'Build Trust',
        'Verified listings get more inquiries.',
      ),
      (
        Icons.groups_outlined,
        HomiziColors.success,
        'Find the Right Tenants',
        'Clear details help you get matched quickly.',
      ),
      (
        Icons.schedule_outlined,
        HomiziColors.ink,
        'Faster Renting',
        'Well-detailed listings get matched quickly.',
      ),
      (
        Icons.shield_outlined,
        HomiziColors.accent,
        'Safe & Transparent',
        'Everyone knows what to expect.',
      ),
    ];
    return FlowPage(
      pageKey: const Key('listing-intro'),
      backKey: const Key('listing-flow-back'),
      onBack: onBack,
      title: 'List Your Property in Just a Few Steps',
      subtitle: 'Add complete details and photos to attract the right tenants.',
      footer: FlowContinueButton(
        buttonKey: const Key('listing-intro-continue'),
        label: 'Continue',
        onPressed: onContinue,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(point.$1, color: point.$2, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    homiziText(context, point.$3),
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontWeight: FontWeight.w800,
                                      color: HomiziColors.ink,
                                    ),
                                  ),
                                  Text(
                                    homiziText(context, point.$4),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: HomiziColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/photos/exterior_01.webp',
                  width: 116,
                  height: 168,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const FlowBanner(lines: ['List with Confidence', 'Rent Faster']),
        ],
      ),
    );
  }
}

class ListingPhotoBoard extends StatelessWidget {
  const ListingPhotoBoard({required this.draft, super.key});

  final ListingDraft draft;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        for (var index = 0; index < photoSequence.length; index++)
          _PhotoTile(
            index: index + 1,
            label: photoSequence[index],
            photo: _match(draft, photoSequence[index]),
          ),
      ],
    );
  }

  PhotoSlot? _match(ListingDraft draft, String label) {
    for (final photo in draft.photos) {
      if (photo.label == label) {
        return photo;
      }
    }
    return null;
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.label,
    required this.photo,
  });

  final int index;
  final String label;
  final PhotoSlot? photo;

  @override
  Widget build(BuildContext context) {
    final slot = photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (slot == null)
            const ColoredBox(color: HomiziColors.white)
          else
            Image.asset(assetForPhoto(slot), fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: HomiziColors.night,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  homiziText(context, '$index. $label'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: HomiziColors.nightInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ListingReviewPage extends StatelessWidget {
  const ListingReviewPage({
    required this.draft,
    required this.gaps,
    required this.busy,
    required this.note,
    required this.onBack,
    required this.onDraft,
    required this.onPreview,
    required this.onPublish,
    super.key,
  });

  final ListingDraft draft;
  final List<String> gaps;
  final bool busy;
  final String? note;
  final VoidCallback onBack;
  final VoidCallback onDraft;
  final VoidCallback onPreview;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final rent = draft.rentInr;
    final photo = draft.photos.isEmpty ? null : draft.photos.first;
    final place = [
      draft.locality.trim(),
      draft.city.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final title = draft.title.trim().isEmpty
        ? 'Your listing'
        : draft.title.trim();
    return FlowPage(
      pageKey: const Key('listing-review'),
      backKey: const Key('listing-flow-back'),
      onBack: onBack,
      title: 'Review & Publish',
      subtitle: 'Check all details before publishing.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.7,
              child: photo == null
                  ? const ColoredBox(
                      color: HomiziColors.white,
                      child: Icon(
                        Icons.photo_outlined,
                        color: HomiziColors.muted,
                      ),
                    )
                  : Image.asset(assetForPhoto(photo), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rent == null
                ? homiziText(context, 'Add a rent')
                : '₹ ${formatIndianDigits(rent)}',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          Text(
            homiziText(context, '/ month'),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: HomiziColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(context, title),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              color: HomiziColors.ink,
              fontSize: 16,
            ),
          ),
          if (place.isNotEmpty)
            Text(
              homiziText(context, place),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: HomiziColors.inkSoft,
              ),
            ),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'Publish stays off until these are filled:'),
              key: const Key('listing-missing'),
            ),
            for (final gap in gaps) Text(homiziText(context, '• $gap')),
          ],
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              homiziText(context, note!),
              key: const Key('listing-save-note'),
            ),
          ],
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowContinueButton(
            buttonKey: const Key('listing-publish'),
            label: 'Publish Listing',
            busy: busy,
            onPressed: busy || gaps.isNotEmpty ? null : onPublish,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('listing-draft'),
                  onPressed: busy ? null : onDraft,
                  child: Text(homiziText(context, 'Draft')),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('listing-preview'),
                  onPressed: onPreview,
                  child: Text(homiziText(context, 'Preview')),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('listing-review-publish'),
                  onPressed: busy || gaps.isNotEmpty ? null : onPublish,
                  child: Text(homiziText(context, 'Publish')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
