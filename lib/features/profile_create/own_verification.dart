import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/profile_create/public_profile.dart';

typedef VerifiedAction = Future<void> Function();

/// This device's verification flags. Unverified until the create flow finishes.
class OwnVerification extends Notifier<PublicProfile> {
  @override
  PublicProfile build() => const PublicProfile();

  void replace(PublicProfile next) => state = next;
}

final ownVerificationProvider =
    NotifierProvider<OwnVerification, PublicProfile>(OwnVerification.new);

/// Test stand-in so existing journeys can contact, chat, and post.
class VerifiedSession extends OwnVerification {
  @override
  PublicProfile build() => PublicProfile.verifiedDemo;
}

class PendingVerifiedAction extends Notifier<VerifiedAction?> {
  @override
  VerifiedAction? build() => null;

  void arm(VerifiedAction action) => state = action;

  VerifiedAction? take() {
    final current = state;
    state = null;
    return current;
  }
}

final pendingVerifiedActionProvider =
    NotifierProvider<PendingVerifiedAction, VerifiedAction?>(
      PendingVerifiedAction.new,
    );
