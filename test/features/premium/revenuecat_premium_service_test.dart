import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/revenuecat_premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'isConfigured':
              return true;
            case 'getAppUserID':
              return r'$RCAnonymousID:anon';
            case 'logIn':
              throw PlatformException(code: '16', message: 'offline');
            default:
              throw PlatformException(code: '1', message: 'Store problem.');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('an SDK error becomes a PremiumFailure with its message', () async {
    final service = RevenueCatPremiumService(publicKey: 'test_abc123');
    await expectLater(
      service.currentStatus(),
      throwsA(
        isA<PremiumFailure>().having(
          (error) => error.message,
          'message',
          'Store problem.',
        ),
      ),
    );
    expect(calls, contains('getCustomerInfo'));
  });

  test('a signed-in account is logged in to RevenueCat', () async {
    final service = RevenueCatPremiumService(
      publicKey: 'test_abc123',
      appUserId: () => 'user-123',
    );
    await expectLater(service.currentStatus(), throwsA(isA<PremiumFailure>()));
    expect(
      calls,
      containsAllInOrder(['isConfigured', 'getAppUserID', 'logIn']),
    );
  });

  test('purchasing with no offering reports it cannot buy', () async {
    final service = RevenueCatPremiumService(publicKey: 'test_abc123');
    await expectLater(
      service.purchase(premiumDefaultPlans.first),
      throwsA(isA<PremiumFailure>()),
    );
  });
}
