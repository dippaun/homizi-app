import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/otp_code_field.dart';
import 'package:homizi/features/auth/otp/otp_confirmation.dart';
import 'package:homizi/features/auth/otp/otp_visuals.dart';

BoxDecoration _boxDecoration(WidgetTester tester, int index) {
  final box = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.byKey(Key('otp-box-$index')),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return box.decoration! as BoxDecoration;
}

Color _border(WidgetTester tester, int index) =>
    (_boxDecoration(tester, index).border! as Border).top.color;

Future<void> _pumpField(
  WidgetTester tester,
  TextEditingController code, {
  String? error,
  bool verified = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: OtpCodeField(
            controller: code,
            showBoxes: true,
            errorText: error,
            verified: verified,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('the resend clock reads mm:ss', () {
    expect(otpClock(60), '01:00');
    expect(otpClock(55), '00:55');
    expect(otpClock(5), '00:05');
    expect(otpClock(0), '00:00');
    expect(otpClock(-3), '00:00');
  });

  testWidgets('the box being typed into is orange with a caret', (
    tester,
  ) async {
    final code = TextEditingController();
    addTearDown(code.dispose);
    await _pumpField(tester, code);

    expect(find.byKey(const Key('otp-caret')), findsNothing);
    await tester.tap(find.byKey(const Key('otp-field')));
    await tester.pumpAndSettle();
    expect(_border(tester, 0), HomiziColors.logoOrange);
    expect(find.byKey(const Key('otp-caret')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otp-field')), '00');
    await tester.pumpAndSettle();
    expect(_border(tester, 0), HomiziColors.ink);
    expect(_border(tester, 1), HomiziColors.ink);
    expect(_border(tester, 2), HomiziColors.logoOrange);
    expect(_border(tester, 3), HomiziColors.line);
    expect(tester.widget<Text>(find.byKey(const Key('otp-box-1'))).data, '0');
  });

  testWidgets('a paste fills all six boxes and drops non-digits', (
    tester,
  ) async {
    final code = TextEditingController();
    addTearDown(code.dispose);
    await _pumpField(tester, code);
    await tester.enterText(find.byKey(const Key('otp-field')), '00-00 00');
    await tester.pumpAndSettle();
    expect(code.text, '000000');
    for (var i = 0; i < 6; i++) {
      expect(tester.widget<Text>(find.byKey(Key('otp-box-$i'))).data, '0');
    }
  });

  testWidgets('a wrong code turns every box red and shakes the row', (
    tester,
  ) async {
    final code = TextEditingController(text: '857837');
    addTearDown(code.dispose);
    await _pumpField(tester, code);
    await _pumpField(tester, code, error: 'Wrong code. Try again.');
    await tester.pump(const Duration(milliseconds: 60));

    final shaken = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('otp-box-0')),
            matching: find.byType(Transform),
          )
          .last,
    );
    expect(shaken.transform.getTranslation().x, isNot(0));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      expect(_border(tester, i), HomiziColors.error);
    }
    expect(find.text('Wrong code. Try again.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('otp-field')))
          .decoration
          ?.errorText,
      'Wrong code. Try again.',
    );
  });

  testWidgets('an accepted code turns the boxes green', (tester) async {
    final code = TextEditingController(text: '000000');
    addTearDown(code.dispose);
    await _pumpField(tester, code, verified: true);
    await tester.pumpAndSettle();
    expect(_border(tester, 5), HomiziColors.success);
    expect(_boxDecoration(tester, 5).color, HomiziColors.successWash);
  });

  testWidgets('the header shows the badge and where the code went', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OtpHeader(title: 'Check your email', sentTo: 'test5@homizi.in'),
              OtpResendLine(remaining: 55),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp-hero-badge')), findsOneWidget);
    expect(find.byKey(const Key('otp-hero-bubble')), findsOneWidget);
    expect(
      find.textContaining('test5@homizi.in', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Resend code in 00:55', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('resend becomes a link at zero, or hides with no action', (
    tester,
  ) async {
    var resent = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OtpResendLine(remaining: 0, onResend: () => resent += 1),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('otp-resend-now')));
    expect(resent, 1);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OtpResendLine(remaining: 0))),
    );
    expect(find.byKey(const Key('otp-resend-now')), findsNothing);
    expect(find.byKey(const Key('otp-resend-clock')), findsNothing);
  });

  testWidgets('the verifying veil shows wave dots and still settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Text('behind'),
              Positioned.fill(child: OtpVerifyingVeil()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('otp-wave-dots')), findsOneWidget);
    expect(find.text('Verifying…'), findsOneWidget);
    expect(find.text('behind'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('confirmation turns the lock into a green tick', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpConfirmation(
            title: 'Email verified',
            detail: 'test5@homizi.in',
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byKey(const Key('otp-confirmed')), findsOneWidget);
    expect(find.text('test5@homizi.in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('otp-continue')));
    expect(continued, isTrue);
  });
}
