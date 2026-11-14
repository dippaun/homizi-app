import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host_flow/listing_flow.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/partner_dashboard_screen.dart';
import 'package:homizi/features/post_property/partner_enquiries.dart';
import 'package:homizi/features/post_property/partner_flow_screen.dart';
import 'package:homizi/features/post_property/pg_listing.dart';
import 'package:homizi/features/post_property/post_confirm_screen.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/shared_home/host_shared_home_screen.dart';

const _config = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

class _SavedPartner extends PartnerApplicationController {
  @override
  PartnerApplication build() {
    return const PartnerApplication(
      applicationId: 'PP20261115-4587',
      partnerType: 'builder',
      contact: PostContact(
        fullName: 'Meera Krishnan',
        mobile: '9876543210',
        email: 'meera@example.com',
        mobileVerified: true,
        emailVerified: true,
      ),
      businessName: 'Krishnan Estates',
      address: '12, 4th Cross, Indiranagar, Bengaluru',
      operatingArea: 'Indiranagar, Bengaluru',
      about: 'Homes across Bengaluru for working professionals.',
      savedLocally: true,
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_POST_SHOTS'];
  if (dir == null || dir.isEmpty) {
    test('post property screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_POST_SHOTS'), isFalse);
    });
    return;
  }

  setUpAll(() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final file in files) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await family('PlusJakartaSans', const [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await family('Inter', const [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
    ]);
    final noto = File('/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf');
    if (noto.existsSync()) {
      final loader = FontLoader('Noto Sans');
      loader.addFont(
        Future.value(ByteData.sublistView(await noto.readAsBytes())),
      );
      await loader.load();
    }
    final root =
        Platform.environment['FLUTTER_ROOT'] ??
        '${Platform.environment['HOME']}/sdk/flutter';
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      final bytes = await icons.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  Future<void> shoot(WidgetTester tester, String name) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget app(Widget child, {bool savedPartner = false}) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        inventoryGatewayProvider.overrideWith((ref) => DemoInventoryGateway()),
        if (savedPartner)
          partnerApplicationProvider.overrideWith(_SavedPartner.new),
      ],
      child: MaterialApp(
        theme: HomiziTheme.light(),
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: const Key('shot-frame'), child: child),
      ),
    );
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('chooser', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const PostPropertyChooserScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-choice-owner')));
    await tester.pump();
    await shoot(tester, '01-chooser');
  });

  testWidgets('owner basic info', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(const ListingFlow(postFlow: true, showMarketing: false)),
    );
    await shoot(tester, '02-owner-basic');
  });

  testWidgets('partner type', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const PartnerFlowScreen()));
    await shoot(tester, '03-partner-type');
  });

  testWidgets('partner confirmation', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(const PartnerSuccessScreen(), savedPartner: true),
    );
    await shoot(tester, '04-partner-confirmation');
  });

  testWidgets('partner dashboard', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(const PartnerDashboardScreen(), savedPartner: true),
    );
    await shoot(tester, '05-partner-dashboard');
  });

  testWidgets('shared room', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const HostSharedHomeScreen(postChrome: true)));
    await shoot(tester, '06-shared-room');
  });

  testWidgets('chooser shows post as PG owner', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const PostPropertyChooserScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('post-choice-pg')),
      200,
    );
    await tester.pump();
    await shoot(tester, '07-chooser-pg');
  });

  testWidgets('pg fields', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: PgListingFields(
                details: PgListingDetails(
                  singlePrice: '12000',
                  doublePrice: '8000',
                  triplePrice: '6500',
                  meals: true,
                  gender: 'coliving',
                  curfew: '10:30 pm',
                  rules: 'No loud music after 10.',
                ),
                amenities: ['wifi', 'ac'],
                onChanged: _ignorePg,
                onAmenity: _ignoreAmenity,
              ),
            ),
          ),
        ),
      ),
    );
    await shoot(tester, '08-pg-fields');
  });

  testWidgets('live cost of renting', (tester) async {
    phone(tester);
    const draft = ListingDraft(
      rentText: '22000',
      depositText: '44000',
      brokerageText: '22000',
      oneTimeChargesText: '2000',
      maintenanceText: '2500',
      electricityText: '800',
      waterChargeText: '300',
      wifiChargeText: '500',
      otherMonthlyText: '400',
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ChargesStep(
                draft: draft,
                rent: TextEditingController(text: draft.rentText),
                deposit: TextEditingController(text: draft.depositText),
                brokerage: TextEditingController(text: draft.brokerageText),
                oneTime: TextEditingController(text: draft.oneTimeChargesText),
                maintenance: TextEditingController(text: draft.maintenanceText),
                electricity: TextEditingController(text: draft.electricityText),
                water: TextEditingController(text: draft.waterChargeText),
                wifi: TextEditingController(text: draft.wifiChargeText),
                other: TextEditingController(text: draft.otherMonthlyText),
                brokerageTerms: TextEditingController(),
                showBroker: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await shoot(tester, '09-live-cost');
  });

  testWidgets('recent enquiries', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(const PartnerDashboardScreen(), savedPartner: true),
    );
    await tester.pump();
    final context = tester.element(find.byType(PartnerDashboardScreen));
    for (final enquiry in partnerEnquiries) {
      await tester.runAsync(
        () => precacheImage(AssetImage(enquiry.avatar), context),
      );
    }
    await tester.pump();
    await shoot(tester, '10-recent-enquiries');
  });
}

void _ignorePg(PgListingDetails _) {}

void _ignoreAmenity(String _, bool _) {}
