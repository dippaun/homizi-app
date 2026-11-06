import 'package:flutter/material.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';

/// Host shell Seekers tab. Reuses the same board as `/host/seekers`.
class SeekersScreen extends StatelessWidget {
  const SeekersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SeekerMatchesScreen(
      key: Key('seekers-screen'),
      title: 'See what seekers need',
    );
  }
}
