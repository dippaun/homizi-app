import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

class BrokerPage extends StatelessWidget {
  const BrokerPage({
    required this.screenKey,
    required this.title,
    required this.children,
    this.actions,
    super.key,
  });

  final Key screenKey;
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, title)),
        actions: actions,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: children,
      ),
    );
  }
}

class BrokerTapCard extends StatelessWidget {
  const BrokerTapCard({
    required this.cardKey,
    required this.onTap,
    required this.child,
    super.key,
  });

  final Key cardKey;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
