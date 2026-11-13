import 'package:flutter/material.dart';
import 'package:homizi/features/roommates/finder/roommate_finder_screen.dart';

/// Roommate tab. The finder replaces the old list and swipe screen.
class RoommateScreen extends StatelessWidget {
  const RoommateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoommateFinderScreen();
  }
}
