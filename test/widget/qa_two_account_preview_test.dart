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
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/host/host_leads_screen.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/l10n/app_localizations.dart';

const _seeker = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _host = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _homeId = 'home-vastrapur';

class _Board {
  final leads = <OwnerLead>[
    OwnerLead(
      id: 'lead-like',
      propertyId: _homeId,
      kind: 'interest',
      status: 'new',
      personUserId: _seeker,
      displayName: 'Account A',
      createdAt: DateTime.utc(2026, 11, 12, 0, 30),
    ),
    OwnerLead(
      id: 'lead-visit',
      propertyId: _homeId,
      kind: 'visit',
      status: 'new',
      personUserId: _seeker,
      displayName: 'Account A',
      createdAt: DateTime.utc(2026, 11, 12, 0, 31),
    ),
  ];
}

class _Gateway implements OwnerGateway {
  _Gateway(this.board, {required this.asHost});

  final _Board board;
  final bool asHost;

  @override
  Future<List<OwnerListing>> myListings() async {
    if (!asHost) {
      return const [];
    }
    return const [
      OwnerListing(
        id: _homeId,
        title: 'Studio in Vastrapur',
        locality: 'Vastrapur',
        city: 'Ahmedabad',
        rentInr: 18000,
        status: 'published',
        chip: 'live',
        views: 3,
        saves: 1,
        interests: 1,
        visitRequests: 1,
      ),
    ];
  }

  @override
  Future<List<OwnerLead>> leads(String propertyId) async {
    return [
      for (final lead in board.leads)
        if (lead.propertyId == propertyId) lead,
    ];
  }

  @override
  Future<OwnerLead> decideRequest(String leadId, String decision) async {
    final index = board.leads.indexWhere((lead) => lead.id == leadId);
    final updated = board.leads[index].copyWith(
      decision: decision,
      status: 'replied',
      matchId: decision == 'accepted' ? 'match-ab' : null,
      keepMatchId: decision == 'accepted',
    );
    board.leads[index] = updated;
    return updated;
  }

  @override
  Future<List<RequestOutcome>> myRequestOutcomes() async {
    if (asHost) {
      return const [];
    }
    return [
      for (final lead in board.leads)
        RequestOutcome(
          leadId: lead.id,
          propertyId: lead.propertyId,
          title: 'Studio in Vastrapur',
          locality: 'Vastrapur',
          city: 'Ahmedabad',
          kind: lead.kind,
          decision: lead.decision,
          hostName: 'Account B',
        ),
    ];
  }

  @override
  Future<List<IncomingLike>> incomingLikes() async {
    if (!asHost) {
      return const [];
    }
    return const [
      IncomingLike(
        actorUserId: _seeker,
        displayName: 'Account A',
        targetType: 'property',
      ),
    ];
  }

  @override
  Future<OwnerLead> setLeadStatus(String leadId, String status) async {
    final index = board.leads.indexWhere((lead) => lead.id == leadId);
    final updated = board.leads[index].copyWith(status: status);
    board.leads[index] = updated;
    return updated;
  }

  @override
  Future<String> act(String propertyId, String action) async => '';

  @override
  Future<UserBadges> badgesFor(String userId) async => const UserBadges();

  @override
  Future<List<InterestedTenant>> interestedTenants(String propertyId) async =>
      const [];

  @override
  Future<ListingDraft?> loadOwnedDraft(String id) async => null;

  @override
  Future<UserBadges> myBadges() async => const UserBadges();

  @override
  Future<void> recordView(String propertyId) async {}

  @override
  Future<int?> replyHours(String hostUserId) async => null;

  @override
  Future<UserBadges> setDemoIdVerified({required bool enabled}) async =>
      const UserBadges();

  @override
  Future<ListingStats> stats(String propertyId) async {
    return ListingStats(
      propertyId: propertyId,
      days: const [],
      saves: 0,
      interests: 1,
      visitRequests: 1,
    );
  }
}

DiscoveryState _matched(String otherId, String otherName) {
  return DiscoveryState(
    listings: [
      const Listing(
        id: _homeId,
        hostUserId: _host,
        title: 'Studio in Vastrapur',
        city: 'Ahmedabad',
        locality: 'Vastrapur',
        rentInr: 18000,
        depositInr: 36000,
        furnishing: 'semi_furnished',
        propertyType: 'apartment',
        hostDisplayName: 'Account B',
        amenities: ['wifi'],
        summary: 'A bright room near the lake.',
      ),
    ],
    matches: [
      MatchSummary(
        matchId: 'match-ab',
        otherUserId: otherId,
        otherDisplayName: otherName,
        listingTitle: 'Studio in Vastrapur',
        contact: const ContactGate.hidden('not_shared'),
      ),
    ],
  );
}

class _SeekerMatches extends DiscoveryController {
  @override
  DiscoveryState build() => _matched(_host, 'Account B');
}

class _HostMatches extends DiscoveryController {
  @override
  DiscoveryState build() => _matched(_seeker, 'Account A');
}

void main() {
  testWidgets(
    'account A like is visible to B, then the match and host decision',
    (tester) async {
      final captureDir = Platform.environment['HOMIZI_CAPTURE_DIR'];
      if (captureDir != null && captureDir.isNotEmpty) {
        await tester.runAsync(_loadFonts);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final board = _Board();
      final staging = AppConfig.parse(
        rawEnvironment: 'staging',
        supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
        supabaseAnonKey: 'sb_publishable_example',
        policyVersion: '2026-10-11-draft',
      );

      Future<void> shoot(String name) async {
        if (captureDir == null || captureDir.isEmpty) {
          return;
        }
        await tester.pump(const Duration(milliseconds: 50));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('shot-frame')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$captureDir/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> show(
        Widget screen, {
        required OwnerGateway gateway,
        DiscoveryController Function()? discovery,
      }) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (context, state) => screen),
            GoRoute(
              path: '/matches',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/chats',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              appConfigProvider.overrideWithValue(staging),
              ownerGatewayProvider.overrideWithValue(gateway),
              if (discovery != null) discoveryProvider.overrideWith(discovery),
            ],
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
        await tester.pump();
      }

      final hostGateway = _Gateway(board, asHost: true);
      await show(const HostLeadsScreen(), gateway: hostGateway);
      expect(find.text('Account A'), findsWidgets);
      expect(find.textContaining('Pending'), findsWidgets);
      expect(
        find.byKey(const Key('host-lead-lead-like-accept')),
        findsOneWidget,
      );
      await shoot('b-incoming-like');

      await tester.tap(find.byKey(const Key('host-lead-lead-like-accept')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('host-lead-lead-visit-reject')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Accepted'), findsWidgets);
      expect(find.textContaining('Rejected'), findsWidgets);
      expect(board.leads[0].decision, 'accepted');
      expect(board.leads[0].matchId, 'match-ab');
      expect(board.leads[1].decision, 'rejected');
      await shoot('b-host-decided');

      final seekerGateway = _Gateway(board, asHost: false);
      await show(
        const MatchesScreen(),
        gateway: seekerGateway,
        discovery: _SeekerMatches.new,
      );
      expect(find.text('Your requests'), findsOneWidget);
      expect(find.textContaining('Accepted'), findsWidgets);
      expect(find.textContaining('Rejected'), findsWidgets);
      expect(find.text('Account B'), findsOneWidget);
      expect(find.text('Studio in Vastrapur'), findsWidgets);
      await shoot('a-match-and-decisions');

      await show(
        const MatchesScreen(),
        gateway: _Gateway(board, asHost: true),
        discovery: _HostMatches.new,
      );
      expect(find.text('People who liked you'), findsOneWidget);
      expect(find.text('Account A'), findsWidgets);
      expect(find.text('Studio in Vastrapur'), findsWidgets);
      await shoot('b-match');
    },
  );
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
