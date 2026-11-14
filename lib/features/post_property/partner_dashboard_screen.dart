import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/partner_enquiries.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(partnerApplicationProvider);
    final name = application.contact.fullName.trim().isEmpty
        ? 'there'
        : application.contact.fullName.trim().split(' ').first;
    final listings = ref
        .watch(demoListingMemoryProvider)
        .homes
        .values
        .where(
          (home) =>
              home.status == 'published' && !home.id.startsWith('demo-own-'),
        );
    return PostPropertyPage(
      pageKey: const Key('post-partner-dashboard'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            homiziText(context, 'Hello, $name'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          const PostChip(label: 'Property Partner'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  statKey: const Key('post-stat-listings'),
                  label: 'My Listings',
                  value: '${listings.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  statKey: const Key('post-stat-enquiries'),
                  label: 'Total Enquiries',
                  value: '${partnerEnquiries.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Banner(onAdd: () => context.push(RoutePaths.postOwner)),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Recent Enquiries'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const PostChip(label: 'Sample'),
          const SizedBox(height: 8),
          for (final enquiry in partnerEnquiries) ...[
            _EnquiryTile(enquiry: enquiry),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class PartnerListingsScreen extends ConsumerWidget {
  const PartnerListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = [
      for (final home in ref.watch(demoListingMemoryProvider).homes.values)
        if (!home.id.startsWith('demo-own-')) home,
    ];
    return PostPropertyPage(
      pageKey: const Key('post-partner-listings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            homiziText(context, 'My Listings'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12),
          if (homes.isEmpty)
            Text(
              homiziText(
                context,
                'No listings yet. Add a property to start receiving enquiries.',
              ),
              style: const TextStyle(color: HomiziColors.inkSoft),
            )
          else
            for (final home in homes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.home_work_outlined,
                  color: HomiziColors.logoOrange,
                ),
                title: Text(
                  home.draft.title.trim().isEmpty
                      ? 'Untitled home'
                      : home.draft.title,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  home.draft.locality,
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
              ),
          const SizedBox(height: 12),
          PostGradientButton(
            buttonKey: const Key('post-add-property'),
            label: 'Add Property',
            onPressed: () => context.push(RoutePaths.postOwner),
          ),
        ],
      ),
    );
  }
}

class PartnerEnquiriesScreen extends StatelessWidget {
  const PartnerEnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PostPropertyPage(
      pageKey: const Key('post-partner-enquiries'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            homiziText(context, 'Enquiries'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          const PostChip(label: 'Sample'),
          const SizedBox(height: 12),
          for (final enquiry in partnerEnquiries) ...[
            _EnquiryTile(enquiry: enquiry),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: postPropertyGradient),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'List More Properties'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(
                  context,
                  'Add another home with the same listing steps.',
                ),
                style: const TextStyle(color: HomiziColors.ink, height: 1.3),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('post-add-property'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.white,
                  foregroundColor: HomiziColors.ink,
                ),
                onPressed: onAdd,
                child: Text(homiziText(context, 'Add Property')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.statKey,
    required this.label,
    required this.value,
  });

  final Key statKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: statKey,
      decoration: BoxDecoration(
        color: HomiziColors.homiziLavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            Text(
              homiziText(context, label),
              style: const TextStyle(color: HomiziColors.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({required this.enquiry});

  final PartnerEnquiry enquiry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: HomiziColors.homiziLavender,
              child: Text(
                enquiry.name.isEmpty ? '?' : enquiry.name[0],
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enquiry.name,
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    enquiry.place,
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    enquiry.ask,
                    style: const TextStyle(
                      color: HomiziColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
