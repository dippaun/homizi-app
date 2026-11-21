import 'package:flutter/material.dart';
import 'package:homizi/features/seekers/host_match_deck.dart';

/// Host Matches tab. Live seekers only, in the roommate swipe card.
class SeekersScreen extends StatelessWidget {
  const SeekersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HostMatchDeck(key: Key('seekers-screen'));
  }
}
