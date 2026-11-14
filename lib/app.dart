import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        return _Chrome(
          router: router,
          hideSignIn: hideSignIn,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Keeps the bottom bar on the route that is actually showing.
///
/// The app builder runs before the launch redirect, and
/// [GoRouter.routeInformationProvider] does not notify for that redirect.
/// The delegate does, sometimes while the frame is still building, so the
/// path update waits until the frame has finished.
class _Chrome extends StatefulWidget {
  const _Chrome({
    required this.router,
    required this.hideSignIn,
    required this.child,
  });

  final GoRouter router;
  final bool hideSignIn;
  final Widget child;

  @override
  State<_Chrome> createState() => _ChromeState();
}

class _ChromeState extends State<_Chrome> {
  late String _path;
  var _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _path = _pathNow();
    _listen(widget.router);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant _Chrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      _ignore(oldWidget.router);
      _listen(widget.router);
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    _ignore(widget.router);
    super.dispose();
  }

  void _listen(GoRouter router) {
    router.routerDelegate.addListener(_onRoute);
    router.routeInformationProvider.addListener(_onRoute);
  }

  void _ignore(GoRouter router) {
    router.routerDelegate.removeListener(_onRoute);
    router.routeInformationProvider.removeListener(_onRoute);
  }

  void _onRoute() {
    if (_pathNow() == _path) {
      return;
    }
    final phase = WidgetsBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (building) {
      _scheduleSync();
      return;
    }
    _applyPath();
  }

  void _scheduleSync() {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      _applyPath();
    });
  }

  void _applyPath() {
    final next = _pathNow();
    if (next == _path) {
      return;
    }
    setState(() => _path = next);
  }

  String _pathNow() {
    final matches = widget.router.routerDelegate.currentConfiguration;
    if (matches.isEmpty) {
      return widget.router.routeInformationProvider.value.uri.path;
    }
    // Imperative pushes (Search, Priorities) stay off [RouteMatchList.uri].
    // [GoRouter.state] is the page actually on screen.
    final full = widget.router.state.uri.path;
    if (full.isNotEmpty) {
      return full;
    }
    return matches.uri.path;
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return ColoredBox(
      color: HomiziColors.white,
      child: Center(
        child: _PhoneFrame(
          hideSignIn: widget.hideSignIn,
          nav: showHomiziNav(path)
              ? HomiziBottomNav(path: path, router: widget.router)
              : null,
          child: widget.child,
        ),
      ),
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
