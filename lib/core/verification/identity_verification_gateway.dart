import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identity checks are a mock until gate G-03 is approved.
/// Implementations must not collect Aadhaar, passport, or face data.
enum VerificationStatus { notStarted, mockPending, mockVerified, rejected }

VerificationStatus verificationStatusFromWire(String? value) {
  return switch (value) {
    'mock_pending' => VerificationStatus.mockPending,
    'mock_verified' => VerificationStatus.mockVerified,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.notStarted,
  };
}

extension VerificationStatusLabel on VerificationStatus {
  String get label => switch (this) {
    VerificationStatus.notStarted => 'Not started',
    VerificationStatus.mockPending => 'Mock pending',
    VerificationStatus.mockVerified => 'Mock verified',
    VerificationStatus.rejected => 'Rejected',
  };
}

const mockVerificationMessage =
    'Mock check queued. No identity document, photo, or government ID was collected.';

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
      message: mockVerificationMessage,
    );
  }
}

final verificationGatewayProvider = Provider<IdentityVerificationGateway>(
  (ref) => MockIdentityVerificationGateway(),
);
