import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Indexed shell for the main tabs. The bottom bar lives in the app chrome
/// so the same bar sits on Home and on routes outside this shell.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => navigationShell;
}
