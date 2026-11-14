import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/auth/auth_contact_mode.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

void main() {
  test('digits are a mobile and an @ sign is an email', () {
    expect(readAuthContact('').mode, AuthContactMode.unknown);
    expect(readAuthContact('9876543210').isPhone, isTrue);
    expect(readAuthContact('9876543210').phoneE164, '+919876543210');
    expect(readAuthContact('meera.nair@homizi.in').isEmail, isTrue);
    expect(readAuthContact('98a').mode, AuthContactMode.unknown);
  });

  testWidgets('the unified field shows +91 for a mobile and email copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Find the place which you deserve'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const Key('auth-phone-prefix')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      '9876543210',
    );
    await tester.pump();

    expect(find.byKey(const Key('auth-phone-prefix')), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Send code to email'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'meera.nair@homizi.in',
    );
    await tester.pump();

    expect(find.byKey(const Key('auth-phone-prefix')), findsNothing);
    expect(find.text('Send code to email'), findsOneWidget);
    expect(find.text('+91'), findsNothing);
  });

  testWidgets('a signed-out home lists flats without search or match scores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedOut.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('home-guest-flats')), findsOneWidget);
    expect(find.text('Available flats'), findsOneWidget);
    expect(find.byKey(const Key('home-rentals')), findsOneWidget);
    expect(find.text('Search Properties'), findsNothing);
    expect(find.text('Priorities'), findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(find.textContaining('% Match'), findsNothing);
    expect(find.text('Best matches for you'), findsNothing);
    expect(find.byKey(const Key('home-card-search')), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });
}
