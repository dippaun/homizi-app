import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// One back chevron, a scrolling body, and a single footer action.
class BrokerFlowChrome extends StatelessWidget {
  const BrokerFlowChrome({
    required this.pageKey,
    required this.onBack,
    required this.children,
    this.step,
    this.headline,
    this.headlineWidget,
    this.subtitle,
    this.error,
    this.footer,
    super.key,
  });

  final Key pageKey;
  final VoidCallback onBack;
  final String? step;
  final String? headline;
  final Widget? headlineWidget;
  final String? subtitle;
  final String? error;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepText = step;
    final headlineCopy = headline;
    final subtitleCopy = subtitle;
    final errorCopy = error;
    final stepLabel = stepText == null
        ? null
        : Text(
            homiziText(context, stepText),
            key: const Key('broker-flow-step'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.accent,
              fontWeight: FontWeight.w800,
            ),
          );
    final headlineText = headlineCopy == null
        ? null
        : Text(
            homiziText(context, headlineCopy),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          );
    final subtitleText = subtitleCopy == null
        ? null
        : Text(
            homiziText(context, subtitleCopy),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          );
    final errorText = errorCopy == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              homiziText(context, errorCopy),
              key: const Key('broker-flow-error'),
              style: const TextStyle(color: HomiziColors.error),
            ),
          );
    return RepaintBoundary(
      key: const Key('broker-flow-shot'),
      child: Scaffold(
        key: pageKey,
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          leading: HomiziBackButton(
            key: const Key('broker-flow-back'),
            onPressed: onBack,
          ),
          title: const Row(
            children: [
              HomiziMark(size: 28),
              SizedBox(width: 8),
              Text(
                'HOMIZI',
                style: TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  ?stepLabel,
                  if (stepLabel != null) const SizedBox(height: 6),
                  ?headlineWidget,
                  ?headlineText,
                  if (subtitleText != null) ...[
                    const SizedBox(height: 6),
                    subtitleText,
                  ],
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
            if (error != null || footer != null)
              Material(
                color: HomiziColors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [?errorText, ?footer],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BrokerContinueButton extends StatelessWidget {
  const BrokerContinueButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('broker-flow-continue'),
      onPressed: busy ? null : onPressed,
      child: Text(homiziText(context, busy ? 'Please wait…' : label)),
    );
  }
}
