import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/roles/role_selection_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/l10n/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;

class _SignedOut extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _NeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'qa+a1111@homizi.in',
      policyVersion: '2026-10-11-draft',
      userId: '11111111-1111-4111-8111-111111111111',
    );
  }
}

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'qa+a1111@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
      userId: '11111111-1111-4111-8111-111111111111',
    );
  }
}

Listing _home({
  required String id,
  required String title,
  required String host,
}) {
  return Listing(
    id: id,
    hostUserId: host,
    title: title,
    city: 'Ahmedabad',
    locality: 'Vastrapur',
    rentInr: 18000,
    depositInr: 36000,
    furnishing: 'semi_furnished',
    propertyType: 'apartment',
    hostDisplayName: 'Account B',
    amenities: const ['wifi'],
    summary: 'A bright room near the lake.',
    photoAssets: const ['assets/avatars/mira_shah.webp'],
  );
}

class _AccountA extends DiscoveryController {
  @override
  DiscoveryState build() {
    final home = _home(
      id: 'home-vastrapur',
      title: 'Studio in Vastrapur',
      host: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    return DiscoveryState(
      listings: [home],
      savedIds: {home.id},
      matches: [
        MatchSummary(
          matchId: 'match-ab',
          otherUserId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          otherDisplayName: 'Account B',
          listingTitle: home.title,
          contact: const ContactGate.hidden('not_shared'),
        ),
      ],
    );
  }
}

class _AccountB extends DiscoveryController {
  @override
  DiscoveryState build() {
    final home = _home(
      id: 'home-bodakdev',
      title: 'Room in Bodakdev',
      host: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    return DiscoveryState(
      listings: [home],
      savedIds: {home.id},
      matches: [
        const MatchSummary(
          matchId: 'match-ab',
          otherUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          otherDisplayName: 'Account A',
          listingTitle: 'Studio in Vastrapur',
          contact: ContactGate.hidden('not_shared'),
        ),
      ],
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('persist capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  testWidgets('capture signup, otp, onboarding, saved, and matches', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    Future<void> shoot(String name) async {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot-frame')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> show(
      Widget screen, {
      List<Override> overrides = const [],
    }) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [GoRoute(path: '/', builder: (context, state) => screen)],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: overrides,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) {
              return RepaintBoundary(
                key: const Key('shot-frame'),
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    final raw =
        jsonDecode(File('config/staging.json').readAsStringSync())
            as Map<String, dynamic>;
    final staging = AppConfig.parse(
      rawEnvironment: 'staging',
      supabaseUrl: raw['SUPABASE_URL'] as String,
      supabaseAnonKey: raw['SUPABASE_PUBLISHABLE_KEY'] as String,
      policyVersion: raw['POLICY_VERSION'] as String,
    );
    final configOverride = appConfigProvider.overrideWithValue(staging);

    await show(
      const LoginScreen(),
      overrides: [configOverride, sessionProvider.overrideWith(_SignedOut.new)],
    );
    await shoot('signup');

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'friend@example.com',
    );
    await tester.enterText(find.byKey(const Key('otp-field')), '482913');
    await tester.pump();
    await shoot('otp');

    await show(
      const RoleSelectionScreen(),
      overrides: [configOverride, sessionProvider.overrideWith(_NeedsRole.new)],
    );
    await shoot('onboarding');

    await show(
      const SavedScreen(),
      overrides: [
        configOverride,
        sessionProvider.overrideWith(_Ready.new),
        discoveryProvider.overrideWith(_AccountA.new),
      ],
    );
    await shoot('saved-account-a');

    await show(
      const MatchesScreen(),
      overrides: [
        configOverride,
        sessionProvider.overrideWith(_Ready.new),
        discoveryProvider.overrideWith(_AccountA.new),
      ],
    );
    await shoot('matches-account-a');

    await show(
      const SavedScreen(),
      overrides: [
        configOverride,
        sessionProvider.overrideWith(_Ready.new),
        discoveryProvider.overrideWith(_AccountB.new),
      ],
    );
    await shoot('saved-account-b');

    await show(
      const MatchesScreen(),
      overrides: [
        configOverride,
        sessionProvider.overrideWith(_Ready.new),
        discoveryProvider.overrideWith(_AccountB.new),
      ],
    );
    await shoot('matches-account-b');
  });
}

Future<void> _loadFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    root != null && root.isNotEmpty
        ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        : '${File(Platform.resolvedExecutable).parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final material = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
    await material.load();
  }
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
}
