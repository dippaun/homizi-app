import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      const _Tool(
        keyName: 'tool-receipt',
        icon: Icons.receipt_long_outlined,
        title: 'Rent receipt',
        body:
            'Write a receipt for rent you already paid, then download the PDF.',
        path: RoutePaths.rentReceipt,
      ),
      const _Tool(
        keyName: 'tool-split',
        icon: Icons.groups_outlined,
        title: 'Rent split',
        body: 'Split rent, deposit, maintenance, and utilities by room.',
        path: RoutePaths.rentSplit,
      ),
      const _Tool(
        keyName: 'tool-agreement',
        icon: Icons.description_outlined,
        title: 'Agreement draft',
        body: 'Fill an 11-month leave-and-licence draft. It is not stamped.',
        path: RoutePaths.rentAgreement,
      ),
      const _Tool(
        keyName: 'tool-checklist',
        icon: Icons.checklist,
        title: 'Move-in checklist',
        body: 'Note each room, its condition, and an optional photo.',
        path: RoutePaths.moveInChecklist,
      ),
      const _Tool(
        keyName: 'tool-deposit',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Deposit tracker',
        body:
            'Track the deposit, deductions, and a refund reminder in the app.',
        path: RoutePaths.depositTracker,
      ),
    ];
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Tools')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Paperwork for a rental. HOMIZI does not collect rent or stamp an agreement.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          for (final tool in tools) ...[
            Card.outlined(
              child: InkWell(
                key: Key(tool.keyName),
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(tool.path),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: HomiziColors.accentWash,
                        foregroundColor: HomiziColors.ink,
                        child: Icon(tool.icon),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homiziText(context, tool.title),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(homiziText(context, tool.body)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
    required this.path,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String body;
  final String path;
}
