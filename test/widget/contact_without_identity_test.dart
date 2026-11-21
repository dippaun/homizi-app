import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  testWidgets('a verified phone messages without the sheet', (tester) async {
    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    await tester.pumpWidget(_app(acted: acted, session: _PhoneOtp.new));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify to continue'), findsNothing);
    expect(acted.value, isTrue);
  });

  testWidgets('a verified email messages without the sheet', (tester) async {
    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    await tester.pumpWidget(_app(acted: acted, session: _EmailOtp.new));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();

    expect(find.text('Verify to continue'), findsNothing);
    expect(acted.value, isTrue);
  });

  testWidgets('the strict flag still asks for identity', (tester) async {
    final acted = ValueNotifier(false);
    addTearDown(acted.dispose);
    await tester.pumpWidget(
      _app(acted: acted, session: _PhoneOtp.new, strict: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-to-continue-sheet')), findsOneWidget);
    expect(find.text('Verify now'), findsOneWidget);
    expect(acted.value, isFalse);
  });

  testWidgets(
    'a signed-in person with no verified contact still sees the sheet',
    (tester) async {
      final acted = ValueNotifier(false);
      addTearDown(acted.dispose);
      await tester.pumpWidget(
        _app(acted: acted, session: _ReadyUnverified.new),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('interested-button')));
      await tester.pumpAndSettle();

      expect(find.text('Verify to continue'), findsOneWidget);
      expect(acted.value, isFalse);
    },
  );
}

Widget _app({
  required ValueNotifier<bool> acted,
  required SessionController Function() session,
  bool strict = false,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          environment: AppEnvironment.dev,
          supabaseUrl: '',
          supabaseAnonKey: '',
          policyVersion: '2026-10-11-draft',
          requireIdentityForContact: strict,
        ),
      ),
      sessionProvider.overrideWith(session),
    ],
    child: MaterialApp(
      theme: HomiziTheme.light(),
      home: _InterestProbe(acted: acted),
    ),
  );
}

class _InterestProbe extends ConsumerWidget {
  const _InterestProbe({required this.acted});

  final ValueNotifier<bool> acted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: FilledButton(
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
    );
  }
}

class _PhoneOtp extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      contact: '+919999999999',
      phoneVerified: true,
      phoneE164: '+919999999999',
    );
  }
}

class _EmailOtp extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      contact: 'meera@homizi.in',
      emailVerified: true,
    );
  }
}

class _ReadyUnverified extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      contact: 'meera@homizi.in',
    );
  }
}
