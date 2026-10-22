import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/rent_cost_breakdown.dart';

/// End of the listing flow. One back control. Does not claim a server publish
/// unless [serverPublished] is true.
class ListingPostedScreen extends StatelessWidget {
  const ListingPostedScreen({
    required this.draft,
    required this.serverPublished,
    super.key,
  });

  final ListingDraft draft;
  final bool serverPublished;

  @override
  Widget build(BuildContext context) {
    final photosVerified = draftPhotosVerified(draft);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('listing-posted'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Listing saved')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              serverPublished
                  ? 'Your listing is live and appears in search.'
                  : 'This home is on this device and shows in search here. The server did not publish this listing.',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(
              context,
              draft.title.trim().isEmpty ? 'Untitled home' : draft.title.trim(),
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(
              context,
              [
                if (draft.locality.trim().isNotEmpty) draft.locality.trim(),
                if (draft.city.trim().isNotEmpty) draft.city.trim(),
              ].join(', '),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VerifiedBadge(label: 'Host verified', showCheck: true),
            ],
          ),
          const SizedBox(height: 8),
          VerifiedBadge(
            label: photosVerified ? 'Photos verified' : 'Photos declared',
            showCheck: photosVerified,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              photosVerified
                  ? 'Host verified is the identity check. Photos verified means this photo set was marked reviewed. Sample photos in the demo can show as reviewed without a staff check. Rent, rules, and nearby places stay declared by the host.'
                  : 'Host verified is the identity check. Photos declared means the host uploaded them and a photo check is still pending. Rent, rules, and nearby places are declared by the host.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: HomiziColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          RentCostBreakdown(cost: RentingCost.fromDraft(draft), detailed: true),
        ],
      ),
    );
  }
}
