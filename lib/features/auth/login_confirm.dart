import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the sign-in screen in place after a successful code so the
/// confirmation can be read. The router leaves once this is released.
class LoginConfirmHold extends Notifier<bool> {
  @override
  bool build() => false;

  void hold() => state = true;

  void release() => state = false;
}

final loginConfirmHoldProvider = NotifierProvider<LoginConfirmHold, bool>(
  LoginConfirmHold.new,
);
