import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/auth_contact.dart';

void main() {
  test('email is used as the auth mailbox', () {
    final contact = parseAuthContact('  Ananya@Example.test ');
    expect(contact, isNotNull);
    expect(contact!.authEmail, 'Ananya@Example.test');
    expect(contact.usesSyntheticEmail, isFalse);
    expect(contact.displayContact, 'Ananya@Example.test');
  });

  test('an Indian mobile becomes a private phone and a synthetic mailbox', () {
    final contact = parseAuthContact('98765 43210');
    expect(contact!.phoneE164, '+919876543210');
    expect(contact.authEmail, '919876543210@phone.example.test');
    expect(contact.displayContact, '+919876543210');
  });

  test('synthetic mailboxes are not shown when a phone is stored', () {
    expect(
      displayContactFor(
        email: '919876543210@phone.example.test',
        phone: '+919876543210',
      ),
      '+919876543210',
    );
    expect(
      displayContactFor(email: 'ananya@example.test', phone: '+919876543210'),
      'ananya@example.test',
    );
  });

  test('rejects a short number', () {
    expect(parseAuthContact('12345'), isNull);
  });
}
