import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/post_property/post_property_choice.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/roles/role_provider.dart';

class PostPropertyChooserScreen extends ConsumerStatefulWidget {
  const PostPropertyChooserScreen({super.key});

  @override
  ConsumerState<PostPropertyChooserScreen> createState() =>
      _PostPropertyChooserScreenState();
}

class _PostPropertyChooserScreenState
    extends ConsumerState<PostPropertyChooserScreen> {
  PostPropertyChoice? _choice;

  @override
  void initState() {
    super.initState();
    _choice = choiceForRole(ref.read(currentRoleProvider));
  }

  void _continue() {
    final choice = _choice;
    if (choice == null) {
      return;
    }
    final path = switch (choice) {
      PostPropertyChoice.owner => RoutePaths.postOwner,
      PostPropertyChoice.partner => RoutePaths.postPartner,
      PostPropertyChoice.shared => RoutePaths.postShared,
    };
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    return PostPropertyPage(
      pageKey: const Key('post-property-chooser'),
      footer: PostGradientButton(
        buttonKey: const Key('post-property-continue'),
        label: 'Continue',
        onPressed: _choice == null ? null : _continue,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, 'Post Property'),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(
                        context,
                        'Choose how you want to list your property on HOMIZI.',
                      ),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/home/house.webp',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ChoiceCard(
            cardKey: const Key('post-choice-owner'),
            asset: 'assets/images/home/house.webp',
            icon: Icons.home_outlined,
            title: 'Post as Owner',
            description:
                'List your own property (House, Apartment, Villa, etc.)',
            chips: const ['Your Property', 'Direct Listing', 'Full Control'],
            selected: _choice == PostPropertyChoice.owner,
            onTap: () => setState(() => _choice = PostPropertyChoice.owner),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            cardKey: const Key('post-choice-partner'),
            asset: 'assets/images/home/apartment.webp',
            icon: Icons.apartment_outlined,
            title: 'Post as Property Partner',
            description:
                'List properties on behalf of a builder, developer or real-estate agency.',
            chips: const [
              'Multiple Listings',
              'Business Growth',
              'Verified Partner',
            ],
            selected: _choice == PostPropertyChoice.partner,
            onTap: () => setState(() => _choice = PostPropertyChoice.partner),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            cardKey: const Key('post-choice-shared'),
            asset: 'assets/images/home/roomies.jpg',
            icon: Icons.groups_outlined,
            title: 'Post as Shared Room / Full House',
            description:
                'List a shared room vacancy or full house (without owner or broker).',
            chips: const ['Roommates', 'Shared Space', 'No Broker'],
            selected: _choice == PostPropertyChoice.shared,
            onTap: () => setState(() => _choice = PostPropertyChoice.shared),
          ),
          const SizedBox(height: 20),
          const PostTrustPill(
            text:
                'Your listing will be verified for genuine and trusted matches.',
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.cardKey,
    required this.asset,
    required this.icon,
    required this.title,
    required this.description,
    required this.chips,
    required this.selected,
    required this.onTap,
  });

  final Key cardKey;
  final String asset;
  final IconData icon;
  final String title;
  final String description;
  final List<String> chips;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.homiziLavender : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? HomiziColors.homiziPurple : HomiziColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: cardKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        asset,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: HomiziColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            icon,
                            size: 16,
                            color: HomiziColors.logoOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, description),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final chip in chips) PostChip(label: chip),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? HomiziColors.homiziPurple
                    : HomiziColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
