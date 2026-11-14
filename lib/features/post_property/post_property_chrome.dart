import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/flow_accent.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Orange blended into purple. Ink sits on it. White is not used, because
/// the orange end is too light for white type.
const postPropertyGradient = LinearGradient(
  colors: [HomiziColors.logoOrange, HomiziColors.homiziPurple],
);

/// Round back, centred Homizi mark, round home. One back control per page.
class PostPropertyBar extends StatelessWidget implements PreferredSizeWidget {
  const PostPropertyBar({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: HomiziColors.white,
      surfaceTintColor: HomiziColors.white,
      elevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _RoundIconButton(
          buttonKey: const Key('post-property-back'),
          tooltip: 'Back',
          icon: Icons.arrow_back,
          onPressed: onBack ?? () => HomiziBackButton.leave(context),
        ),
      ),
      title: const _CenteredMark(),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _RoundIconButton(
            buttonKey: const Key('post-property-home'),
            tooltip: 'Home',
            icon: Icons.home_outlined,
            onPressed: () {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.go(RoutePaths.home);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _CenteredMark extends StatelessWidget {
  const _CenteredMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziMark(size: 28, color: HomiziColors.logoOrange),
        const SizedBox(width: 8),
        Text(
          homiziText(context, 'HOMIZI'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: HomiziColors.white,
        shape: const CircleBorder(side: BorderSide(color: HomiziColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: buttonKey,
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Tooltip(
            message: homiziText(context, tooltip),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: HomiziColors.ink, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class PostPropertyPage extends StatelessWidget {
  const PostPropertyPage({
    required this.body,
    this.footer,
    this.pageKey,
    this.onBack,
    super.key,
  });

  final Widget body;
  final Widget? footer;
  final Key? pageKey;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return FlowAccentScope(
      child: Scaffold(
        key: pageKey,
        backgroundColor: HomiziColors.white,
        appBar: PostPropertyBar(onBack: onBack),
        body: body,
        bottomNavigationBar: footer == null
            ? null
            : Material(
                color: HomiziColors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: footer,
                  ),
                ),
              ),
      ),
    );
  }
}

class PostGradientButton extends StatelessWidget {
  const PostGradientButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.busy = false,
    this.showArrow = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool busy;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? postPropertyGradient : null,
        color: enabled ? null : HomiziColors.line,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        color: HomiziColors.clear,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          key: buttonKey,
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HomiziColors.ink,
                      ),
                    )
                  else ...[
                    Flexible(
                      child: Text(
                        homiziText(context, label),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: HomiziColors.ink,
                        size: 20,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostChip extends StatelessWidget {
  const PostChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.homiziLavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          homiziText(context, label),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class PostStepper extends StatelessWidget {
  const PostStepper({required this.labels, required this.index, super.key});

  final List<String> labels;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= index
                    ? HomiziColors.homiziPurple
                    : HomiziColors.line,
              ),
            ),
          _StepDot(
            label: labels[i],
            number: i + 1,
            done: i < index,
            active: i == index,
            stepKey: Key('post-step-$i'),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.number,
    required this.done,
    required this.active,
    required this.stepKey,
  });

  final String label;
  final int number;
  final bool done;
  final bool active;
  final Key stepKey;

  @override
  Widget build(BuildContext context) {
    final fill = done
        ? HomiziColors.success
        : active
        ? HomiziColors.homiziPurple
        : HomiziColors.white;
    final ink = done || active ? HomiziColors.white : HomiziColors.muted;
    return SizedBox(
      key: stepKey,
      width: 92,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: done
                    ? HomiziColors.success
                    : active
                    ? HomiziColors.homiziPurple
                    : HomiziColors.line,
              ),
            ),
            child: SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: done
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: HomiziColors.onSuccess,
                      )
                    : Text(
                        '$number',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(context, label),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? HomiziColors.ink : HomiziColors.inkSoft,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class PostTrustPill extends StatelessWidget {
  const PostTrustPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.homiziLavender,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: HomiziColors.homiziPurple,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                homiziText(context, text),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled field used by this flow. Leading icon stays orange.
InputDecoration postFieldDecoration(
  BuildContext context,
  String label,
  IconData icon, {
  String? hint,
  String? helper,
  String? error,
  Widget? prefix,
}) {
  return InputDecoration(
    labelText: homiziText(context, label),
    hintText: hint == null ? null : homiziText(context, hint),
    helperText: helper == null ? null : homiziText(context, helper),
    errorText: error == null ? null : homiziText(context, error),
    prefixIcon: prefix ?? Icon(icon, color: HomiziColors.logoOrange),
    filled: true,
    fillColor: HomiziColors.white,
    labelStyle: const TextStyle(color: HomiziColors.inkSoft),
    hintStyle: const TextStyle(color: HomiziColors.muted),
  );
}

class PropertyPhotoUploadCard extends StatelessWidget {
  const PropertyPhotoUploadCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.homiziLavender,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('post-photo-upload'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomiziColors.homiziPurple),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                color: HomiziColors.logoOrange,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(context, 'Upload Property Photos'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(
                  context,
                  'Tap to upload or drag and drop. JPG/PNG up to 10MB.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
