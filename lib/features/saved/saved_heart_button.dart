import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Saved homes, moved off the bottom bar.
class SavedHeartButton extends StatelessWidget {
  const SavedHeartButton({this.style, super.key});

  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('open-saved'),
      tooltip: homiziText(context, 'Saved'),
      style: style,
      onPressed: () => context.go(RoutePaths.saved),
      icon: const Icon(Icons.favorite_border),
    );
  }
}
