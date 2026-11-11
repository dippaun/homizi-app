import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Stand-in for a flow another agent owns. One back control.
class FlowPlaceholderScreen extends StatelessWidget {
  const FlowPlaceholderScreen({required this.flow, super.key});

  final String flow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('flow-placeholder-${flow.toLowerCase()}'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, flow)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            homiziText(context, 'The $flow steps open on this screen.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.4,
              color: HomiziColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
