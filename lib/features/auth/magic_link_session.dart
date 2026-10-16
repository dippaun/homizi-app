import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

StreamSubscription<AuthState>? _magicLinkSubscription;

/// Adopts a session when an email contains a link and the app opens it.
///
/// [Supabase.initialize] already watches incoming links and calls
/// `getSessionFromUrl`. This listener turns that auth session into the
/// app session (consent plus profile). It does not parse the URL itself.
void listenForMagicLinkSession(ProviderContainer container) {
  _magicLinkSubscription?.cancel();
  final auth = Supabase.instance.client.auth;
  _magicLinkSubscription = auth.onAuthStateChange.listen((data) {
    if (data.event != AuthChangeEvent.signedIn || data.session == null) {
      return;
    }
    unawaited(container.read(sessionProvider.notifier).adoptMagicLinkSession());
  });
  if (auth.currentSession != null) {
    unawaited(container.read(sessionProvider.notifier).adoptMagicLinkSession());
  }
}
