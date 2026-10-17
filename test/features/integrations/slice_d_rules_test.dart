import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/agreements/domain/agreement_rules.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/payments/demo_payment_gateway.dart';
import 'package:homizi/features/payments/domain/payment_rules.dart';
import 'package:homizi/features/push/domain/push_rules.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

void main() {
  test('every demo listing has a public locality point', () {
    for (final listing in DemoCatalog.listings) {
      final pin = publicPin(
        city: listing.city,
        locality: listing.locality,
        salt: listing.id,
      );
      expect(pin, isNotNull, reason: '${listing.city} ${listing.locality}');
      expect(pin!.inIndia, isTrue);
    }
  });

  test('jitter stays near the centroid and does not use a building point', () {
    const centroid = GeoPoint(12.935, 77.624);
    final shifted = jitterLocality(centroid, 'lst_koramangala');
    expect((shifted.latitude - centroid.latitude).abs(), lessThan(0.004));
    expect((shifted.longitude - centroid.longitude).abs(), lessThan(0.004));
    expect(
      publicPin(
        storedLatitude: 12.935,
        storedLongitude: 77.624,
        city: 'Bengaluru',
        locality: 'Koramangala',
        salt: 'same',
      )!.latitude,
      12.935,
    );
  });

  test('clusters group nearby pins and split when zoomed in', () {
    final pins = [
      const MapPin(
        listingId: 'a',
        rentInr: 22000,
        title: 'A',
        point: GeoPoint(12.935, 77.624),
      ),
      const MapPin(
        listingId: 'b',
        rentInr: 18000,
        title: 'B',
        point: GeoPoint(12.936, 77.625),
      ),
    ];
    expect(clusterPins(pins, cellDegrees: 0.8).single.isCluster, isTrue);
    expect(clusterPins(pins, cellDegrees: 0.0001), hasLength(2));
    expect(clusterCellForZoom(5), 0.8);
    expect(clusterCellForZoom(14), 0.02);
  });

  test('a tile URL must be https and include the z x y placeholders', () {
    expect(validOsmTileUrl(AppConfigTile.sample), isTrue);
    expect(
      validOsmTileUrl('http://tile.openstreetmap.org/{z}/{x}/{y}.png'),
      isFalse,
    );
  });

  test(
    'payment amounts and demo results stay in the server vocabulary',
    () async {
      expect(validatePaymentAmount(0), isNotNull);
      expect(validatePaymentAmount(22000), isNull);
      expect(isRazorpayLiveKey('rzp_live_example'), isTrue);
      expect(isRazorpayTestKey('rzp_test_example'), isTrue);
      final gateway = DemoPaymentGateway();
      final session = await gateway.start(
        matchId: 'demo-match',
        kind: PaymentKind.rent,
        amountInr: 22000,
        counterpartyName: 'Rohan M.',
      );
      expect(session.payment.status, 'pending');
      expect(session.mode, 'demo');
      final paid = await gateway.completeDemo(
        paymentId: session.payment.id,
        success: true,
      );
      expect(paid.isPaid, isTrue);
      final failedStart = await gateway.start(
        matchId: 'demo-match',
        kind: PaymentKind.deposit,
        amountInr: 80000,
        counterpartyName: 'Rohan M.',
      );
      final failed = await gateway.completeDemo(
        paymentId: failedStart.payment.id,
        success: false,
      );
      expect(failed.isFailed, isTrue);
    },
  );

  test('demo signatures follow the agreement status machine', () {
    expect(
      demoStatusAfterSign(
        current: AgreementStatus.sent,
        role: 'tenant',
        provider: 'demo',
      ),
      AgreementStatus.tenantSigned,
    );
    expect(
      demoStatusAfterSign(
        current: AgreementStatus.tenantSigned,
        role: 'owner',
        provider: 'demo',
      ),
      AgreementStatus.completed,
    );
    expect(
      demoStatusAfterSign(
        current: AgreementStatus.sent,
        role: 'tenant',
        provider: 'digio',
      ),
      isNull,
    );
    expect(
      validateAgreementDraft(
        title: 'Koramangala leave and licence',
        body: 'Rent for the term. Number 123456789012 is refused.',
        rentInr: 22000,
        termMonths: 11,
      ),
      isNotNull,
    );
  });

  test('a raw Aadhaar number is not stored as a mask', () {
    expect(looksLikeRawAadhaar('1234 5678 9012'), isTrue);
    expect(maskedLast4OrNull('123456789012'), isNull);
    expect(maskedLast4OrNull('4821'), '4821');
    expect(maskedLast4OrNull('ab'), isNull);
  });

  test('a service lead needs consent and refuses a phone in the note', () {
    final day = DateTime.now().add(const Duration(days: 3));
    expect(
      validateServiceLead(
        ServiceLeadDraft(
          kind: ServiceKind.cleaning,
          fromLocality: 'Koramangala',
          city: 'Bengaluru',
          requestedOn: day,
          contactConsent: false,
        ),
      ),
      isNotNull,
    );
    expect(
      validateServiceLead(
        ServiceLeadDraft(
          kind: ServiceKind.packersMovers,
          fromLocality: 'Koramangala',
          toLocality: 'Indiranagar',
          city: 'Bengaluru',
          requestedOn: day,
          notes: 'Call 9876543210',
          contactConsent: true,
        ),
      ),
      isNotNull,
    );
    expect(
      validateServiceLead(
        ServiceLeadDraft(
          kind: ServiceKind.cleaning,
          fromLocality: 'Koramangala',
          city: 'Bengaluru',
          requestedOn: day,
          contactConsent: true,
        ),
      ),
      isNull,
    );
  });

  test('push categories cover matches, chat, and visits only', () {
    expect(pushCategoryForType('match'), 'matches');
    expect(pushCategoryForType('message'), 'chat');
    expect(pushCategoryForType('visit_accepted'), 'visits');
    expect(pushCategoryForType('billing'), isNull);
    expect(
      pushConfigured(apiKey: 'a', appId: 'b', senderId: 'c', projectId: 'd'),
      isTrue,
    );
    expect(
      pushConfigured(apiKey: '', appId: 'b', senderId: 'c', projectId: 'd'),
      isFalse,
    );
  });
}

abstract final class AppConfigTile {
  static const sample = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
