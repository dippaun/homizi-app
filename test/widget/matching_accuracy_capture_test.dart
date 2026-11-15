import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedIn extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya.iyer@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

/// Phone frames for the screenshots branch. No-op unless HOMIZI_CAPTURE_DIR
/// is set, so a normal `flutter test` stays green.
void main() {
  testWidgets('matching accuracy screenshots at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('A RenderFlex')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name) async {
      await tester.pump();
      final view = tester.binding.renderViews.single;
      final layer = view.debugLayer;
      if (layer is! OffsetLayer) {
        throw StateError('The view has no layer to capture.');
      }
      await tester.runAsync(() async {
        final image = await layer.toImage(
          Offset.zero & view.size,
          pixelRatio: 2,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final pending = DemoCatalog.byId('lst_pending_bopal')!;
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        discoveryProvider.overrideWith(DiscoveryController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: SizedBox(height: 844, child: ListingCard(listing: pending)),
          ),
        ),
      ),
    );
    await tester.pump();
    await shoot('01-verification-pending');

    final home = DemoCatalog.byId('lst_koramangala')!;
    final report = scoreListingForCapture(home);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: MatchBadge(
                    key: const Key('capture-score'),
                    match: report,
                    onTap: () => showMatchBreakdown(context, match: report),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture-score')));
    await tester.pumpAndSettle();
    await shoot('02-why-this-match');
    await tester.scrollUntilVisible(
      find.text('Edit preferences'),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('match-breakdown')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await shoot('03-preferences-used');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

ListingMatch scoreListingForCapture(Listing listing) {
  final now = DateTime.now();
  return listingMatchFromReport(
    scoreMatch(
      seeker: seekerFromRequirement(demoTenantRequirement),
      subject: matchSubjectFromListing(listing),
      computedAt: now.subtract(const Duration(minutes: 2)),
    ),
  );
}
