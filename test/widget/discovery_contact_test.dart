import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';

class _GrantedMatches extends DiscoveryController {
  @override
  DiscoveryState build() {
    return const DiscoveryState(
      matches: [
        MatchSummary(
          matchId: 'm1',
          otherUserId: 'host-1',
          otherDisplayName: 'Rohan Mehta',
          listingTitle: 'Sunlit 2BHK in Koramangala',
          contact: ContactGate.granted(phone: '+919800000000'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('a granted gate shows only the returned phone', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryProvider.overrideWith(_GrantedMatches.new)],
        child: const MaterialApp(home: MatchesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('+919800000000'), findsOneWidget);
    expect(find.byKey(const Key('contact-phone-m1')), findsOneWidget);
    expect(find.byKey(const Key('contact-email-m1')), findsNothing);
    expect(find.textContaining('Contact stays hidden'), findsNothing);
  });

  testWidgets('listing detail stays hidden until the server returns contact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ListingDetailScreen(listingId: 'lst_koramangala'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('interest-note')), findsOneWidget);
    expect(find.textContaining('did not share a phone'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.byKey(const Key('contact-phone')), findsNothing);
  });

  testWidgets('demo share and stop do not reveal contact details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoDiscoveryGateway();
    await gateway.likeListing(DemoCatalog.byId('lst_koramangala')!);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: MatchesScreen()),
      ),
    );
    await tester.pump();

    const shareKey = Key('share-own-contact-demo-match-lst_koramangala');
    await tester.ensureVisible(find.byKey(shareKey));
    await tester.tap(find.byKey(shareKey));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('The server did not share your contact'),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing was sent'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(
      find.byKey(const Key('contact-phone-demo-match-lst_koramangala')),
      findsNothing,
    );

    const stopKey = Key('stop-own-contact-demo-match-lst_koramangala');
    await tester.ensureVisible(find.byKey(stopKey));
    await tester.tap(find.byKey(stopKey));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('The server was not asked'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}
