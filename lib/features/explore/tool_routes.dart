import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ToolLink {
  const ToolLink({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}

const toolLabels = <String, String>{
  '/tools/receipt': 'Rent receipts',
  '/tools/receipts': 'Rent receipts',
  '/tools/agreement': 'Agreement draft',
  '/tools/split': 'Rent split',
  '/tools/checklist': 'Move-in checklist',
  '/tools/deposit': 'Deposit tracker',
};

const toolIcons = <String, IconData>{
  '/tools/receipt': Icons.receipt_long_outlined,
  '/tools/receipts': Icons.receipt_long_outlined,
  '/tools/agreement': Icons.description_outlined,
  '/tools/split': Icons.groups_outlined,
  '/tools/checklist': Icons.checklist_outlined,
  '/tools/deposit': Icons.account_balance_wallet_outlined,
};

/// Paths under `/tools` registered by the tools slice. Empty when that
/// slice has not added routes yet.
List<ToolLink> toolLinksIn(GoRouter router) {
  final paths = <String>[];
  void walk(List<RouteBase> routes, String parent) {
    for (final route in routes) {
      if (route is GoRoute) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$parent/${route.path}'.replaceAll('//', '/');
        if (path.startsWith('/tools/') && path.length > '/tools/'.length) {
          paths.add(path);
        }
        walk(route.routes, path);
      } else if (route is StatefulShellRoute) {
        for (final branch in route.branches) {
          walk(branch.routes, parent);
        }
      } else if (route is ShellRoute) {
        walk(route.routes, parent);
      }
    }
  }

  walk(router.configuration.routes, '');
  final unique = <String>{...paths}.toList()..sort();
  return [
    for (final path in unique)
      ToolLink(
        path: path,
        label: toolLabels[path] ?? _title(path),
        icon: toolIcons[path] ?? Icons.handyman_outlined,
      ),
  ];
}

String _title(String path) {
  final slug = path.split('/').last.replaceAll('-', ' ');
  if (slug.isEmpty) {
    return 'Tool';
  }
  return slug[0].toUpperCase() + slug.substring(1);
}
