import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/demo/demo_copy.dart';
import 'package:homizi/features/tenant/tenant_resume.dart';
import 'package:homizi/l10n/app_localizations.dart';

class HomiziApp extends ConsumerWidget {
  const HomiziApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final hideSignIn = ref.watch(appConfigProvider).demoSkipLogin;
    return MaterialApp.router(
      title: 'HOMIZI',
      theme: HomiziTheme.light(),
      darkTheme: HomiziTheme.dark(),
      themeMode: ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final width = media.size.width > 960 ? 960.0 : media.size.width;
        return ColoredBox(
          color: HomiziColors.white,
          child: Center(
            child: MediaQuery(
              data: media.copyWith(size: Size(width, media.size.height)),
              child: SizedBox(
                width: width,
                height: media.size.height,
                child: DemoCopyGuard(
                  hideSignIn: hideSignIn,
                  child: TenantJourneyResume(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
