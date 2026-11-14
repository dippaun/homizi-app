import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_catalog.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

/// Server stand-in. [tables] false acts like the migration is not applied.
class _Remote extends SkippingSharedHomeRemote {
  _Remote({this.tables = false});

  final bool tables;
  final sent = <JoinRequest>[];
  final statuses = <String, JoinStatus>{};

  @override
  Future<bool> sendRequest({
    required JoinRequest request,
    required String firstName,
  }) async {
    sent.add(request);
    return tables;
  }

  @override
  Future<Map<String, JoinStatus>?> myStatuses() async =>
      tables ? statuses : null;

  @override
  Future<List<HostJoinRequest>?> hostRequests() async => tables
      ? [
          HostJoinRequest(
            id: 'req-1',
            listingId: 'l1',
            firstName: 'Amit',
            mode: JoinMode.individual,
            people: 1,
            shareInr: 12000,
            status: JoinStatus.pending,
            createdAt: DateTime(2026, 11, 14),
          ),
        ]
      : null;

  @override
  Future<bool> setStatus(String requestId, JoinStatus status) async => tables;
}

const _andheri = '${sampleSharedHomePrefix}andheri-3bhk';
const _powai = '${sampleSharedHomePrefix}powai-2bhk';

Future<({GoRouter router, MemorySharedHomeLocal local, _Remote remote})> _pump(
  WidgetTester tester, {
  bool tables = false,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final local = MemorySharedHomeLocal();
  final remote = _Remote(tables: tables);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_ReadySession.new),
        sharedHomeRepositoryProvider.overrideWithValue(
          SharedHomeRepository(local: local, remote: remote),
        ),
        ownerListingsProvider.overrideWith(
          (ref) async => const [
            OwnerListing(
              id: 'l1',
              title: '3 BHK in Andheri East',
              locality: 'Andheri East',
              city: 'Mumbai',
              rentInr: 36000,
              status: 'published',
              chip: 'live',
              views: 0,
              saves: 0,
              interests: 0,
              visitRequests: 0,
            ),
          ],
        ),
      ],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final router = GoRouter.of(
    tester.element(find.byKey(const Key('home-screen'))),
  );
  return (router: router, local: local, remote: remote);
}

Future<void> _go(WidgetTester tester, GoRouter router, String path) async {
  unawaited(router.push(path));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    // Back to the top without a pull-to-refresh.
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search a home → match → choose → request → accepted → move in', (
    tester,
  ) async {
    final app = await _pump(tester);
    await _go(tester, app.router, SharedHomePaths.search);
    expect(find.text('Search a home'), findsOneWidget);
    expect(find.byKey(const Key('occ-sample-note')), findsOneWidget);
    await _tap(tester, 'occ-find');
    expect(find.text('Matching homes for you'), findsOneWidget);
    expect(find.byKey(const Key('shared-tabs')), findsNothing);

    final card = tester.widget<ShMatchPill>(
      find.ancestor(
        of: find.byKey(const Key('shared-match-$_andheri')),
        matching: find.byType(ShMatchPill),
      ),
    );
    await _tap(tester, 'shared-room-$_andheri');
    expect(find.text('Home & housemate details'), findsOneWidget);
    expect(find.text('Rohit S. (Existing tenant)'), findsOneWidget);
    final detail = tester.widget<ShMatchPill>(
      find.ancestor(
        of: find.byKey(const Key('shared-detail-match')),
        matching: find.byType(ShMatchPill),
      ),
    );
    // One scorer: the card and the detail always agree.
    expect(detail.match.score, card.match.score);

    await _tap(tester, 'shared-request-join');
    expect(find.text('Choose your match'), findsOneWidget);
    expect(find.text('Join as a group (2 people)'), findsOneWidget);
    await _tap(tester, 'join-continue');
    expect(find.text('Send join request'), findsWidgets);
    expect(find.text('Budget match (₹12K)'), findsOneWidget);
    expect(find.byKey(const Key('join-sample-note')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-first-name')), 'Amit');
    await _tap(tester, 'join-send');

    expect(find.byKey(const Key('join-sent')), findsOneWidget);
    expect(app.remote.sent, isEmpty, reason: 'samples send nothing');
    expect(decodeJoinRequests(app.local.values[joinRequestsKey]), hasLength(1));
    await _tap(tester, 'join-sample-reply');
    expect(find.text('You & Rohit S. are a match!'), findsOneWidget);
    expect(find.byKey(const Key('join-chat-note')), findsOneWidget);
    await _tap(tester, 'join-continue-home');
    expect(find.text('Your shared home'), findsOneWidget);
    expect(find.text('₹12,000 / month'), findsOneWidget);
    await _tap(tester, 'join-move-in');
    expect(find.byKey(const Key('join-moved-in')), findsOneWidget);
    final saved = decodeJoinRequests(app.local.values[joinRequestsKey]).single;
    expect(saved.status, JoinStatus.movedIn);
  });

  testWidgets('discuss & finalize opens the rent split with the housemate', (
    tester,
  ) async {
    final app = await _pump(tester);
    await _go(tester, app.router, SharedHomePaths.join(_andheri));
    await _tap(tester, 'join-continue');
    await _tap(tester, 'join-send');
    await _tap(tester, 'join-sample-reply');
    await _tap(tester, 'join-discuss');
    expect(find.text('Set up rent split'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('split-people'))).data,
      '2',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('split-rent')))
          .controller!
          .text,
      '36000',
    );
    expect(find.text('Andheri East, Mumbai'), findsWidgets);
  });

  testWidgets('a group asking for double occupancy finds room sharing', (
    tester,
  ) async {
    final app = await _pump(tester);
    await _go(tester, app.router, '${SharedHomePaths.search}?mode=group');
    expect(find.byKey(const Key('occ-group-size')), findsOneWidget);
    await _tap(tester, 'occ-occupancy-double');
    await _tap(tester, 'occ-find');
    expect(
      tester.widget<Text>(find.byKey(const Key('shared-fit-$_powai'))).data,
      '3 places free for your group of 2.',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-others')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('shared-others')), findsOneWidget);
    await _tap(tester, 'shared-room-$_powai');
    await _tap(tester, 'shared-request-join');
    await _tap(tester, 'join-group');
    expect(find.byKey(const Key('join-group-size')), findsOneWidget);
    await _tap(tester, 'join-group-plus');
    expect(find.text('Join as a group (3 people)'), findsOneWidget);
  });

  testWidgets('bad budget stays on the search with a message', (tester) async {
    final app = await _pump(tester);
    await _go(tester, app.router, SharedHomePaths.search);
    await tester.enterText(find.byKey(const Key('occ-budget-min')), '50000');
    await _tap(tester, 'occ-find');
    expect(find.byKey(const Key('occ-note')), findsOneWidget);
    expect(find.text('Search a home'), findsOneWidget);
  });

  testWidgets('find your roomie shows shared homes and new roomies', (
    tester,
  ) async {
    final app = await _pump(tester);
    await _go(tester, app.router, SharedHomePaths.roomie);
    expect(find.text('Find your roomie'), findsOneWidget);
    await _tap(tester, 'roomie-find');
    expect(find.text('Room options for you'), findsOneWidget);
    expect(find.byKey(const Key('shared-tab-homes')), findsOneWidget);
    await _tap(tester, 'shared-tab-roomies');
    expect(find.byKey(const Key('shared-roomies-list')), findsOneWidget);
  });

  testWidgets('a real home sends interest and reads the host answer', (
    tester,
  ) async {
    final app = await _pump(tester, tables: true);
    await _go(tester, app.router, SharedHomePaths.results());
    const home = 'lst_baner';
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-room-lst_baner')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('shared-fit-lst_baner'))).data,
      'The host has not shared which rooms are free yet.',
    );
    await _go(tester, app.router, SharedHomePaths.home(home));
    expect(find.byKey(const Key('shared-full-listing')), findsOneWidget);
    await _tap(tester, 'shared-request-join');
    await _tap(tester, 'join-continue');
    await _tap(tester, 'join-send');
    expect(find.byKey(const Key('join-check')), findsOneWidget);
    expect(app.remote.sent, hasLength(1));
    expect(
      find.text(
        'Saved to your HOMIZI account. The host also sees your interest under Interested seekers.',
      ),
      findsOneWidget,
    );
    app.remote.statuses[app.remote.sent.single.id] = JoinStatus.accepted;
    await _tap(tester, 'join-check');
    expect(find.byKey(const Key('join-accepted')), findsOneWidget);
    expect(find.byKey(const Key('join-chat')), findsOneWidget);
  });

  testWidgets('host adds shared home details and sees join requests', (
    tester,
  ) async {
    final app = await _pump(tester);
    await _go(tester, app.router, SharedHomePaths.host);
    expect(find.text('Add complete details'), findsOneWidget);
    await _tap(tester, 'host-save');
    expect(find.byKey(const Key('host-problem')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('host-mate-name')), 'Rohit');
    await tester.pumpAndSettle();
    expect(find.text('Full home match (total 3 persons)'), findsOneWidget);
    await _tap(tester, 'host-save');
    expect(find.byKey(const Key('host-done')), findsOneWidget);
    expect(find.textContaining('Saved on this device'), findsOneWidget);
    expect(app.local.values[sharedHomeDetailsKey], contains('Rohit'));
    await _tap(tester, 'host-see-requests');
    expect(find.byKey(const Key('host-requests-unavailable')), findsOneWidget);
  });

  testWidgets('host accepts a join request when the tables exist', (
    tester,
  ) async {
    final app = await _pump(tester, tables: true);
    await _go(tester, app.router, SharedHomePaths.hostRequests);
    expect(find.text('Amit'), findsOneWidget);
    await _tap(tester, 'host-accept-req-1');
    expect(find.byKey(const Key('host-status-req-1')), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
  });
}
