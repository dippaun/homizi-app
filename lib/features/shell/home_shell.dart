import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Indexed shell for the main tabs. The bottom bar lives in the app chrome
/// so the same bar can sit on routes outside this shell. Home hides it.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => navigationShell;
}
