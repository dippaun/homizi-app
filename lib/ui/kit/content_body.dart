import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/ui/kit/page_background.dart';
import 'package:homizi/ui/kit/page_variant.dart';
import 'package:homizi/ui/kit/sticky_cta.dart';

/// Designer wash and a centred column. Drop this in as a scaffold body.
class ContentBody extends StatelessWidget {
  const ContentBody({
    required this.pageId,
    required this.child,
    this.variant,
    this.maxWidth = HomiziFrame.maxWidth,
    super.key,
  });

  final String pageId;
  final Widget child;

  /// When set, this wash is used instead of the hash for [pageId].
  final PageBackgroundVariant? variant;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return PageBackground(
      variant: variant ?? pageVariantFor(pageId),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// One back control, a distinct page wash, centred content, and a sticky
/// primary button when [primaryLabel] is set.
class ContentScaffold extends StatelessWidget {
  const ContentScaffold({
    required this.title,
    required this.pageId,
    required this.body,
    this.scaffoldKey,
    this.shotKey,
    this.onBack,
    this.primaryLabel,
    this.onPrimary,
    this.primaryKey,
    this.leadingKey,
    this.actions,
    this.maxWidth = HomiziFrame.maxWidth,
    super.key,
  });

  final String title;
  final String pageId;
  final Widget body;
  final Key? scaffoldKey;
  final Key? shotKey;
  final VoidCallback? onBack;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final Key? leadingKey;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final label = primaryLabel;
    final page = Scaffold(
      key: scaffoldKey,
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: HomiziBackButton(key: leadingKey, onPressed: onBack),
        title: Text(
          homiziText(context, title),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: actions,
      ),
      body: ContentBody(pageId: pageId, maxWidth: maxWidth, child: body),
      bottomNavigationBar: label == null
          ? null
          : StickyCta(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: primaryKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.accent,
                    foregroundColor: HomiziColors.ink,
                    disabledBackgroundColor: HomiziColors.accentDisabled,
                    disabledForegroundColor: HomiziColors.ink,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  onPressed: onPrimary,
                  child: Text(
                    homiziText(context, label),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
    );
    final boundary = shotKey;
    if (boundary == null) {
      return page;
    }
    return RepaintBoundary(key: boundary, child: page);
  }
}
