import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';

class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Home services')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'A HOMIZI partner will contact you. This request is not a confirmed booking.',
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              for (final kind in ServiceKind.values)
                _ServiceCard(
                  kind: kind,
                  onTap: () => context.push(
                    '${RoutePaths.serviceRequest}?kind=${kind.wire}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('service-my-requests'),
            onPressed: () =>
                context.push('${RoutePaths.serviceRequest}?kind=cleaning'),
            child: Text(homiziText(context, 'Your requests')),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.kind, required this.onTap});

  final ServiceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HomiziColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon(kind), color: HomiziColors.accent),
              const Spacer(),
              Text(
                homiziText(context, kind.label),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(ServiceKind kind) {
    return switch (kind) {
      ServiceKind.packersMovers => Icons.local_shipping_outlined,
      ServiceKind.cleaning => Icons.cleaning_services_outlined,
      ServiceKind.painting => Icons.format_paint_outlined,
      ServiceKind.acRepair => Icons.ac_unit,
      ServiceKind.plumbing => Icons.plumbing,
      ServiceKind.electrician => Icons.electrical_services_outlined,
      ServiceKind.carpentry => Icons.carpenter_outlined,
    };
  }
}
