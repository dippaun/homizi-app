import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/l10n/app_localizations.dart';

class HomiziApp extends ConsumerWidget {
  const HomiziApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'HOMIZI',
      theme: HomiziTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
