import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';

/// Seeker demand, listings, and leads. Not the old broker desk.
class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(personalizationProvider).city.trim();
    final place = city.isEmpty ? 'the cities you serve' : city;
    return Scaffold(
      key: const Key('partner-dashboard'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Partner dashboard')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              RoleFlowIntro('Briefs, listings, and leads for $place.'),
              const SizedBox(height: 16),
              _Card(
                cardKey: const Key('broker-tile-briefs'),
                icon: Icons.assignment_outlined,
                title: 'Seeker demand',
                detail: 'Tenant and flatmate briefs you can answer.',
                onTap: () => context.go(RoutePaths.seekers),
              ),
              const SizedBox(height: 12),
              _Card(
                cardKey: const Key('broker-tile-listings'),
                icon: Icons.home_work_outlined,
                title: 'My listings',
                detail: 'Homes you already posted for owners.',
                onTap: () => context.go(RoutePaths.listings),
              ),
              const SizedBox(height: 12),
              _Card(
                cardKey: const Key('broker-tile-leads'),
                icon: Icons.inbox_outlined,
                title: 'Leads',
                detail: 'People who asked about a listing.',
                onTap: () => context.push(RoutePaths.brokerLeads),
              ),
              const SizedBox(height: 20),
              RoleFlowContinue(
                buttonKey: const Key('partner-list-property'),
                label: 'List a property',
                onPressed: () =>
                    context.push('${RoutePaths.listStart}?broker=1'),
              ),
              TextButton(
                key: const Key('broker-home-create-profile'),
                onPressed: () => context.push(RoutePaths.partnerSetup),
                child: Text(
                  homiziText(context, 'Edit partner details'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: HomiziColors.logoOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: HomiziColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, detail),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
