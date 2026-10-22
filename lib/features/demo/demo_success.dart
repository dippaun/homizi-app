import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// True while the staging demo is skipping login.
bool demoModeOn(WidgetRef ref) {
  return ref.read(appConfigProvider).demoSkipLogin;
}

/// Same check for a widget that is not a [Consumer].
bool demoModeHere(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(appConfigProvider).demoSkipLogin;
  } on Object {
    return false;
  }
}

/// Opens the confirmation page, then that role's home.
void openDemoSuccess(
  BuildContext context, {
  required String title,
  required String detail,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(
      Uri(
        path: RoutePaths.demoDone,
        queryParameters: {'title': title, 'detail': detail},
      ).toString(),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => DemoSuccessScreen(title: title, detail: detail),
    ),
  );
}

/// Leaves the confirmation for the role home. `/home` picks the role layout.
void leaveDemoSuccess(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(RoutePaths.home);
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class DemoSuccessScreen extends StatelessWidget {
  const DemoSuccessScreen({
    required this.title,
    required this.detail,
    super.key,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('demo-success-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: HomiziBackButton(onPressed: () => leaveDemoSuccess(context)),
        title: Text(homiziText(context, 'Done')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DemoSuccessBody(title: title, detail: detail),
        ),
      ),
    );
  }
}

class DemoSuccessBody extends StatelessWidget {
  const DemoSuccessBody({required this.title, required this.detail, super.key});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomiziColors.accentWash,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 88,
              height: 88,
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: HomiziColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          homiziText(context, title),
          key: const Key('demo-success-title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, detail),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('demo-success-home'),
          onPressed: () => leaveDemoSuccess(context),
          child: Text(homiziText(context, 'Home')),
        ),
      ],
    );
  }
}
