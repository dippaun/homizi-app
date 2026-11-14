import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

class RoleFlowScaffold extends StatelessWidget {
  const RoleFlowScaffold({
    required this.screenKey,
    required this.title,
    required this.body,
    super.key,
  });

  final Key screenKey;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, title)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: body,
        ),
      ),
    );
  }
}

class RoleFlowIntro extends StatelessWidget {
  const RoleFlowIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.4,
        color: HomiziColors.inkSoft,
      ),
    );
  }
}

class RoleFlowLabel extends StatelessWidget {
  const RoleFlowLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: HomiziColors.ink,
      ),
    );
  }
}

class RoleFlowChips extends StatelessWidget {
  const RoleFlowChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.keyFor,
    super.key,
  });

  final Map<String, String> options;
  final bool Function(String id) selected;
  final ValueChanged<String> onSelected;
  final Key Function(String id)? keyFor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          FilterChip(
            key: keyFor?.call(entry.key),
            label: Text(homiziText(context, entry.value)),
            selected: selected(entry.key),
            onSelected: (_) => onSelected(entry.key),
            selectedColor: HomiziColors.accentWash,
            checkmarkColor: HomiziColors.ink,
            labelStyle: const TextStyle(color: HomiziColors.ink),
          ),
      ],
    );
  }
}

class RoleFlowContinue extends StatelessWidget {
  const RoleFlowContinue({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShGradientButton(
      buttonKey: buttonKey,
      label: label,
      onPressed: onPressed,
    );
  }
}

class RoleFlowError extends StatelessWidget {
  const RoleFlowError({
    required this.message,
    required this.errorKey,
    super.key,
  });

  final String? message;
  final Key errorKey;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        key: errorKey,
        homiziText(context, text),
        style: const TextStyle(color: HomiziColors.error),
      ),
    );
  }
}
