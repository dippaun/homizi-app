import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/supabase_kyc_gateway.dart';

KycSnapshot _toSnapshot(Map<String, dynamic> row) => KycSnapshot(
  status: row['verification_status'] as String? ?? 'not_started',
  aadhaarStatus: kycCheckStateFromWire(row['aadhaar_status'] as String?),
  faceStatus: kycCheckStateFromWire(row['face_status'] as String?),
  maskedLast4: row['masked_last4'] as String?,
  message: '',
);

void main() {
  group('Digio not configured', () {
    test('a not_configured answer is recognised', () {
      expect(
        kycNotConfigured({
          'ok': false,
          'error': 'verification_unavailable',
          'reason': 'not_configured',
        }),
        isTrue,
      );
      expect(
        kycNotConfigured({
          'ok': true,
          'available': false,
          'reason': 'not_configured',
        }),
        isTrue,
      );
      expect(kycNotConfigured({'ok': false, 'error': 'start_failed'}), isFalse);
      expect(kycNotConfigured(null), isFalse);
    });

    test('a refresh without keys keeps the stored row', () {
      expect(
        kycRefreshSnapshot({
          'ok': false,
          'error': 'verification_unavailable',
          'reason': 'not_configured',
        }, _toSnapshot),
        isNull,
      );
      expect(kycRefreshSnapshot('oops', _toSnapshot), isNull);
      expect(
        kycRefreshSnapshot({'ok': true, 'verification': null}, _toSnapshot),
        isNull,
      );
    });
  });

  group('Digio refresh', () {
    test('a verified result from the server becomes a verified snapshot', () {
      final snapshot = kycRefreshSnapshot({
        'ok': true,
        'changed': true,
        'verification': {
          'verification_status': 'verified',
          'aadhaar_status': 'verified',
          'face_status': 'verified',
          'masked_last4': '4321',
        },
      }, _toSnapshot);
      expect(snapshot, isNotNull);
      expect(snapshot!.isVerified, isTrue);
      expect(snapshot.maskedLast4, '4321');
    });

    test('an unchanged pending result stays pending', () {
      final snapshot = kycRefreshSnapshot({
        'ok': true,
        'changed': false,
        'verification': {
          'verification_status': 'pending',
          'aadhaar_status': 'in_progress',
          'face_status': 'in_progress',
        },
      }, _toSnapshot);
      expect(snapshot!.isPending, isTrue);
      expect(snapshot.isVerified, isFalse);
    });
  });
}
