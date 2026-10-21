import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/home/home_screen.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/onboarding/welcome_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/saved/saved_heart_button.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SavedDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() {
    final listing = DemoCatalog.listings.first;
    return DiscoveryState(listings: [listing], savedIds: {listing.id});
  }
}

class _ConsentedOut extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('text scale 1.6 keeps the sign-in action visible', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    await _expectReachable(tester, find.byKey(const Key('contact-field')));
    await _expectReachable(
      tester,
      find.byKey(const Key('verify-code')),
      minHeight: 48,
    );
  });

  testWidgets('text scale 1.6 keeps the requirement action visible', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      ProviderScope(
        overrides: [
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: const MaterialApp(home: RequirementFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _expectReachable(
      tester,
      find.byKey(const Key('requirement-locality')),
    );
    await _expectReachable(
      tester,
      find.byKey(const Key('requirement-continue')),
      minHeight: 48,
    );
  });

  testWidgets('an empty contact error sits on the field and is announced', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    await _tap(tester, find.byKey(const Key('verify-code')));
    await tester.pump();

    final contact = tester.widget<TextField>(
      find.byKey(const Key('contact-field')),
    );
    expect(
      contact.decoration?.errorText,
      'Enter a valid email or a 10-digit Indian mobile number.',
    );
    _expectLive(tester, const Key('login-error'), 'valid email');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('otp-field')))
          .decoration
          ?.errorText,
      isNull,
    );
  });

  testWidgets('a rejected code is tied to the code field', (tester) async {
    await _pumpScaled(
      tester,
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ConsentedOut.new)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ada@example.test',
    );
    await _tap(tester, find.byKey(const Key('verify-code')));
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('otp-field')))
          .decoration
          ?.errorText,
      contains('code'),
    );
    _expectLive(tester, const Key('login-error'), 'code');
  });

  testWidgets('a short password error is tied to the password field', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.staging,
              supabaseUrl: 'https://staging.example.test',
              supabaseAnonKey: 'publishable-test-key',
              policyVersion: '2026-10-11-draft',
              stagingPasswordAuth: true,
            ),
          ),
          sessionProvider.overrideWith(_ConsentedOut.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ada@example.test',
    );
    await _tap(tester, find.byKey(const Key('password-field')));
    await tester.enterText(find.byKey(const Key('password-field')), 'short');
    await _tap(tester, find.byKey(const Key('password-sign-in')));
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password-field')))
          .decoration
          ?.errorText,
      contains('password'),
    );
    _expectLive(tester, const Key('login-error'), 'password');
  });

  testWidgets('an empty locality error is tied to the locality field', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      ProviderScope(
        overrides: [
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: const MaterialApp(home: RequirementFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await _tap(tester, find.byKey(const Key('requirement-continue')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('requirement-locality')))
          .decoration
          ?.errorText,
      'Add at least one locality.',
    );
    _expectLive(tester, const Key('requirement-errors'), 'locality');
    expect(find.text('Add at least one locality.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still moves the welcome slides', (tester) async {
    await _pumpScaled(
      tester,
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
      disableAnimations: true,
    );
    await tester.pump();

    final motions = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(motions, isNotEmpty);
    for (final motion in motions) {
      expect(motion.duration, Duration.zero);
    }

    await tester.tap(find.bySemanticsLabel('Slide 2 of 3').last);
    await tester.pump();
    expect(find.text('Slide 2 of 3'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNotNull,
    );
    await _expectReachable(
      tester,
      find.byKey(const Key('continue-button')),
      minHeight: 48,
    );
  });

  testWidgets('the saved heart names the list and meets 48dp', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SavedHeartButton())),
    );
    await tester.pump();
    final open = find.byTooltip('Saved homes');
    expect(open, findsOneWidget);
    expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(open).width, greaterThanOrEqualTo(48));
  });

  testWidgets('a saved home button names the saved state and meets 48dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryProvider.overrideWith(_SavedDiscovery.new)],
        child: const MaterialApp(home: SavedScreen()),
      ),
    );
    await tester.pump();
    final remove = find.ancestor(
      of: find.byTooltip('Saved. Remove'),
      matching: find.byType(IconButton),
    );
    expect(remove, findsOneWidget);
    expect(tester.widget<IconButton>(remove).isSelected, isTrue);
    expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
  });

  testWidgets('the chat composer stays usable at text scale 1.6', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      ProviderScope(
        overrides: [
          threadGatewayProvider.overrideWith((ref) => DemoThreadGateway()),
        ],
        child: const MaterialApp(
          home: ChatScreen(matchId: 'match-1', otherName: 'Rohan M.'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await _expectReachable(tester, find.byKey(const Key('chat-body')));
    await _expectReachable(
      tester,
      find.byKey(const Key('chat-send')),
      minHeight: 48,
    );
  });

  testWidgets('home status stays usable at text scale 1.6', (tester) async {
    await _pumpScaled(
      tester,
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();
    await _expectReachable(tester, find.text('Find a place.'));
    await _expectReachable(tester, find.text('Create Your Profile'));
    await _expectReachable(tester, find.byKey(const Key('home-card-roomie')));
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.byTooltip('Chat'), findsOneWidget);
    expect(find.byKey(const Key('home-profile')), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Menu')).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('Chat')).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScaled(
  WidgetTester tester,
  Widget app, {
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: const TextScaler.linear(1.6),
        disableAnimations: disableAnimations,
      ),
      child: app,
    ),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _bringIn(tester, finder);
  await tester.tap(finder);
}

Future<void> _expectReachable(
  WidgetTester tester,
  Finder finder, {
  double minHeight = 1,
}) async {
  await _bringIn(tester, finder);
  expect(finder, findsOneWidget);
  expect(tester.takeException(), isNull);
  final rect = tester.getRect(finder);
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThanOrEqualTo(minHeight));
  expect(rect.top, greaterThanOrEqualTo(-0.5));
  expect(rect.left, greaterThanOrEqualTo(-0.5));
  expect(rect.bottom, lessThanOrEqualTo(view.height + 0.5));
  expect(rect.right, lessThanOrEqualTo(view.width + 0.5));
}

Future<void> _bringIn(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate((widget) {
    return widget is Scrollable && widget.axisDirection == AxisDirection.down;
  });
  if (finder.evaluate().isEmpty) {
    expect(vertical, findsWidgets);
    await tester.scrollUntilVisible(finder, 240, scrollable: vertical.first);
  }
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var attempt = 0; attempt < 8; attempt++) {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
    final rect = tester.getRect(finder);
    final onScreen =
        rect.top >= -0.5 &&
        rect.left >= -0.5 &&
        rect.bottom <= view.height + 0.5 &&
        rect.right <= view.width + 0.5;
    if (onScreen || vertical.evaluate().isEmpty) {
      return;
    }
    await tester.drag(vertical.first, const Offset(0, -80));
    await tester.pump();
  }
}

void _expectLive(WidgetTester tester, Key key, String snippet) {
  final handle = tester.ensureSemantics();
  final node = tester.getSemantics(find.byKey(key));
  expect(node.flagsCollection.isLiveRegion, isTrue);
  expect(node.label.toLowerCase(), contains(snippet.toLowerCase()));
  handle.dispose();
}
