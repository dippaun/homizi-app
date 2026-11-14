import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

StreamSubscription<AuthState>? _magicLinkSubscription;

/// Feeds the Supabase auth stream into the one sign-in source.
///
/// [Supabase.initialize] already watches incoming links and calls
/// `getSessionFromUrl`. This listener turns that auth session into the
/// app session (consent plus profile) and drops it on sign-out. The staging
/// demo session is the other input. Header, nav, and Profile watch
/// `signedInProvider`, not this stream. It does not parse the URL itself.
void listenForMagicLinkSession(ProviderContainer container) {
  _magicLinkSubscription?.cancel();
  final auth = Supabase.instance.client.auth;
  _magicLinkSubscription = auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      container.read(sessionProvider.notifier).noteRemoteSignOut();
      return;
    }
    if (data.event != AuthChangeEvent.signedIn || data.session == null) {
      return;
    }
    unawaited(container.read(sessionProvider.notifier).adoptMagicLinkSession());
  });
  if (auth.currentSession != null) {
    unawaited(container.read(sessionProvider.notifier).adoptMagicLinkSession());
  }
}
