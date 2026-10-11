import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identity checks are a mock until gate G-03 is approved.
/// Implementations must not collect Aadhaar, passport, or face data.
enum VerificationStatus { notStarted, mockPending, mockVerified }

class VerificationSnapshot {
  const VerificationSnapshot({required this.status, required this.message});

  final VerificationStatus status;
  final String message;
}

abstract interface class IdentityVerificationGateway {
  Future<VerificationSnapshot> startMockCheck({required String userId});
}

class MockIdentityVerificationGateway implements IdentityVerificationGateway {
  @override
  Future<VerificationSnapshot> startMockCheck({required String userId}) async {
    return const VerificationSnapshot(
      status: VerificationStatus.mockPending,
      message: 'Mock check queued. No identity document, photo, or government ID was collected.',
    );
  }
}

final verificationGatewayProvider = Provider<IdentityVerificationGateway>(
  (ref) => MockIdentityVerificationGateway(),
);
