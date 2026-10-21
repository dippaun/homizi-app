import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';

void main() {
  testWidgets('an unverified interest shows Verify to continue', (
    tester,
  ) async {
    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    await tester.pumpWidget(_app(acted: acted));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-to-continue-sheet')), findsOneWidget);
    expect(find.text('Verify to continue'), findsOneWidget);
    expect(acted.value, isFalse);
    expect(find.text('Interest sent'), findsNothing);

    await tester.tap(find.byKey(const Key('verify-later')));
    await tester.pumpAndSettle();
    expect(find.text('Verify to continue'), findsNothing);
    expect(find.byKey(const Key('interested-button')), findsOneWidget);
    expect(acted.value, isFalse);
  });

  testWidgets('finishing verification returns to the interest', (tester) async {
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        step: 4,
        firstName: 'Priya',
        lastName: 'Shah',
        nickname: 'Asha',
        age: 26,
        gender: 'Woman',
        occupation: 'Student',
        mobileVerified: true,
        emailVerified: true,
        aadhaarVerified: true,
        selfieVerified: true,
        livenessPassed: true,
      );

    await tester.pumpWidget(_app(acted: acted, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verify-now')));
    await tester.pumpAndSettle();

    expect(find.text('Profile Completed!'), findsOneWidget);
    expect(find.text('Priya'), findsNothing);
    expect(find.text('Shah'), findsNothing);

    await tester.tap(find.text('Start Exploring'));
    await tester.pumpAndSettle();

    expect(find.text('Interest sent'), findsOneWidget);
    expect(acted.value, isTrue);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Interest sent')),
    );
    final profile = container.read(ownVerificationProvider);
    expect(profile.isVerified, isTrue);
    expect(profile.publicName, 'Asha');
    expect(profile.legalFirstName, 'Priya');
    expect(find.text('Priya'), findsNothing);
  });

  testWidgets('a verified person runs the action without the sheet', (
    tester,
  ) async {
    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    await tester.pumpWidget(_app(acted: acted, verified: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify to continue'), findsNothing);
    expect(find.text('Interest sent'), findsOneWidget);
    expect(acted.value, isTrue);
  });
}

class _RouterHost extends StatefulWidget {
  const _RouterHost({required this.acted});

  final ValueNotifier<bool> acted;

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/gate',
    routes: [
      GoRoute(
        path: '/gate',
        builder: (context, state) => _InterestProbe(acted: widget.acted),
      ),
      GoRoute(
        path: RoutePaths.profileCreate,
        builder: (context, state) => const ProfileCreateScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const Scaffold(body: Text('Home reached')),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: HomiziTheme.light(),
      routerConfig: _router,
    );
  }
}

Widget _app({
  required ValueNotifier<bool> acted,
  ProfileCreateStore? store,
  bool verified = false,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.dev,
          supabaseUrl: '',
          supabaseAnonKey: '',
          policyVersion: '2026-10-11-draft',
          demoSkipLogin: true,
        ),
      ),
      if (store != null)
        profileCreateStoreProvider.overrideWith((ref) => store),
      if (verified) ownVerificationProvider.overrideWith(VerifiedSession.new),
    ],
    child: _RouterHost(acted: acted),
  );
}

class _InterestProbe extends ConsumerWidget {
  const _InterestProbe({required this.acted});

  final ValueNotifier<bool> acted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: acted,
        builder: (context, sent, child) {
          return Column(
            children: [
              FilledButton(
                key: const Key('interested-button'),
                onPressed: () {
                  guardVerifiedAction(
                    context,
                    ref,
                    action: () async {
                      acted.value = true;
                    },
                  );
                },
                child: const Text('Interested'),
              ),
              if (sent) const Text('Interest sent'),
            ],
          );
        },
      ),
    );
  }
}
