import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/safety/domain/contact_visibility_policy.dart';

void main() {
  const phone = '+910000000001';
  const email = 'host@example.test';

  ContactVisibilityDecision evaluate({
    String? callerId = 'tenant',
    bool matchActive = true,
    bool blocked = false,
    bool otherConsented = false,
    ContactScope? scope,
  }) {
    return evaluateContactVisibility(
      callerId: callerId,
      participantA: 'tenant',
      participantB: 'host',
      matchActive: matchActive,
      blocked: blocked,
      otherConsented: otherConsented,
      consentScope: scope,
      otherPhone: phone,
      otherEmail: email,
    );
  }

  test('a stranger never receives contact fields', () {
    final decision = evaluate(
      callerId: 'stranger',
      otherConsented: true,
      scope: ContactScope.phoneAndEmail,
    );
    expect(decision.visible, isFalse);
    expect(decision.reason, ContactDenyReason.notParticipant);
    expect(decision.phone, isNull);
    expect(decision.email, isNull);
  });

  test('a match without consent returns no contact fields', () {
    final decision = evaluate();
    expect(decision.reason, ContactDenyReason.consentRequired);
    expect(decision.phone, isNull);
    expect(decision.email, isNull);
  });

  test('phone consent does not include email', () {
    final decision = evaluate(otherConsented: true, scope: ContactScope.phone);
    expect(decision.visible, isTrue);
    expect(decision.phone, phone);
    expect(decision.email, isNull);
  });

  test('a block hides contact even after consent', () {
    final decision = evaluate(
      blocked: true,
      otherConsented: true,
      scope: ContactScope.phoneAndEmail,
    );
    expect(decision.reason, ContactDenyReason.blocked);
    expect(decision.phone, isNull);
    expect(decision.email, isNull);
  });
}
