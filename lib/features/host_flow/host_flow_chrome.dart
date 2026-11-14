import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Shared chrome for the host flow and the reusable listing wizard.
class FlowWordmark extends StatelessWidget {
  const FlowWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const HomiziMark(size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'HOMIZI'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: HomiziColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                homiziText(context, 'Find the place which you deserve'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HomiziColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FlowStepPill extends StatelessWidget {
  const FlowStepPill({
    required this.label,
    this.textKey = const Key('flow-step-pill'),
    super.key,
  });

  final String label;
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          key: textKey,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// One back chevron, the Homizi wordmark, and an optional step pill.
class FlowPage extends StatelessWidget {
  const FlowPage({
    required this.onBack,
    required this.body,
    this.backKey = const Key('flow-back'),
    this.stepLabel,
    this.stepKey,
    this.title,
    this.titleKey,
    this.subtitle,
    this.footer,
    this.pageKey,
    this.scrollController,
    super.key,
  });

  final VoidCallback? onBack;
  final Key backKey;
  final String? stepLabel;
  final Key? stepKey;
  final String? title;
  final Key? titleKey;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final Key? pageKey;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final headline = title;
    final detail = subtitle;
    return Scaffold(
      key: pageKey,
      backgroundColor: HomiziColors.soft,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    key: backKey,
                    tooltip: homiziText(context, 'Back'),
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  const Expanded(child: FlowWordmark()),
                  if (stepLabel != null) ...[
                    const SizedBox(width: 8),
                    FlowStepPill(
                      label: stepLabel!,
                      textKey: stepKey ?? const Key('flow-step-pill'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (headline != null)
                    Text(
                      homiziText(context, headline),
                      key: titleKey,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        height: 1.15,
                      ),
                    ),
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, detail),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: HomiziColors.inkSoft,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  body,
                ],
              ),
            ),
            if (footer != null)
              Material(
                color: HomiziColors.soft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FlowBanner extends StatelessWidget {
  const FlowBanner({
    required this.lines,
    this.icon = Icons.home_rounded,
    super.key,
  });

  final List<String> lines;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.accent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lines.map((line) => homiziText(context, line)).join('\n'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
            ),
            Icon(icon, color: HomiziColors.ink, size: 36),
          ],
        ),
      ),
    );
  }
}

class FlowContinueButton extends StatelessWidget {
  const FlowContinueButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.gradient = false,
    this.buttonKey = const Key('host-onboard-continue'),
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Orange-to-red continue used by the listing wizard. Ink stays on the
  /// gradient so the label is never white on yellow or pale orange.
  final bool gradient;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    if (gradient) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                HomiziColors.logoOrange,
                onPressed == null
                    ? HomiziColors.accentDisabled
                    : HomiziColors.brandVermilion,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: buttonKey,
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HomiziColors.ink,
                        ),
                      )
                    : Text(
                        homiziText(context, label),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.accent,
          foregroundColor: HomiziColors.ink,
          disabledBackgroundColor: HomiziColors.accentDisabled,
          disabledForegroundColor: HomiziColors.ink,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                homiziText(context, label),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

BoxDecoration flowCard({Color? color}) {
  return BoxDecoration(
    color: color ?? HomiziColors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: HomiziColors.shadowSoft,
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  );
}
