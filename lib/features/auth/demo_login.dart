import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/account/auth_contact.dart';

/// Testing mailbox. It never receives an email code.
const demoLoginEmail = 'demo@homizi.in';

/// Testing mobile, stored as E.164. `9979099873` is the same number.
const demoLoginPhoneE164 = '+919979099873';

/// Fixed code for [demoLoginEmail] and [demoLoginPhoneE164].
///
/// No SMS or email is sent. This is not the `test5@homizi.in` code.
const demoLoginCode = '123456';

/// True for the testing email or the testing mobile, in any accepted shape.
bool isDemoLoginContact(String raw) {
  final trimmed = raw.trim();
  if (trimmed.toLowerCase() == demoLoginEmail) {
    return true;
  }
  final parsed = parseAuthContact(trimmed);
  return parsed?.phoneE164 == demoLoginPhoneE164;
}

/// True when [contact] is the testing identity and [code] is [demoLoginCode].
bool isDemoLoginAttempt(String contact, String code) {
  return isDemoLoginContact(contact) && code.trim() == demoLoginCode;
}

/// Mailbox created for one demo profile.
///
/// The `qa+` shape is the fresh-tester address the app already knows how to
/// open. A new timestamp is a new account. The typed `demo@homizi.in` address
/// is never registered.
String newDemoAliasEmail([int? millis]) {
  final stamp = millis ?? DateTime.now().millisecondsSinceEpoch;
  return 'qa+d$stamp@homizi.in';
}

/// Local id used when the build cannot create a hosted auth user.
String newDemoUserId([int? micros]) {
  final stamp = micros ?? DateTime.now().microsecondsSinceEpoch;
  return 'demo-$stamp';
}

/// On while the signed-in session came from the testing login.
class DemoLoginActive extends Notifier<bool> {
  @override
  bool build() => false;

  void on() => state = true;

  void off() => state = false;
}

final demoLoginActiveProvider = NotifierProvider<DemoLoginActive, bool>(
  DemoLoginActive.new,
);

/// What the person typed on the testing login, shown instead of the qa+ alias.
class DemoEnteredContact extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value.trim();
}

final demoEnteredContactProvider = NotifierProvider<DemoEnteredContact, String>(
  DemoEnteredContact.new,
);
