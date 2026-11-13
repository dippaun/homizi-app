import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/demo/demo_copy.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/shell/homizi_nav.dart';
import 'package:homizi/features/shell/role_nav.dart';
import 'package:homizi/features/tenant/tenant_resume.dart';
import 'package:homizi/l10n/app_localizations.dart';

class HomiziApp extends ConsumerWidget {
  const HomiziApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final hideSignIn = ref.watch(appConfigProvider).demoSkipLogin;
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(personalizationProvider);
    return MaterialApp.router(
      title: 'HOMIZI',
      theme: HomiziTheme.light(),
      darkTheme: HomiziTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: router.routeInformationProvider,
          builder: (context, _) {
            final path = router.routeInformationProvider.value.uri.path;
            final content = child ?? const SizedBox.shrink();
            return ColoredBox(
              color: HomiziColors.white,
              child: Center(
                child: _PhoneFrame(
                  hideSignIn: hideSignIn,
                  nav: showHomiziNav(path)
                      ? HomiziBottomNav(path: path, router: router)
                      : null,
                  child: content,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.hideSignIn,
    required this.child,
    required this.nav,
  });

  final bool hideSignIn;
  final Widget child;
  final Widget? nav;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width > 720 ? 720.0 : media.size.width;
    final framed = MediaQuery(
      data: media.copyWith(size: Size(width, media.size.height)),
      child: DemoCopyGuard(
        hideSignIn: hideSignIn,
        child: TenantJourneyResume(child: child),
      ),
    );
    return SizedBox(
      width: width,
      height: media.size.height,
      child: nav == null
          ? framed
          : Column(
              children: [
                Expanded(child: framed),
                nav!,
              ],
            ),
    );
  }
}
