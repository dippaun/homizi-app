import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/auth/client_test_login.dart';

/// On-device copy of the staging demo session (`test5@homizi.in` / `000000`).
///
/// The code itself is never stored. A reload reads this record when Supabase
/// has no auth session. Sign-out deletes it.
const demoSessionPrefsKey = 'homizi.client_demo_session';

class PersistedDemoSession {
  const PersistedDemoSession({
    required this.contact,
    this.policyVersion,
    this.roleWire,
    this.homiziWire,
  });

  final String contact;
  final String? policyVersion;
  final String? roleWire;
  final String? homiziWire;

  String encode() {
    return jsonEncode({
      'contact': contact,
      'policy': policyVersion,
      'role': roleWire,
      'wire': homiziWire,
    });
  }

  static PersistedDemoSession? decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map) {
        return null;
      }
      final contact = value['contact'];
      if (contact is! String) {
        return null;
      }
      final trimmed = contact.trim();
      if (trimmed.toLowerCase() != clientTestDemoEmail) {
        return null;
      }
      return PersistedDemoSession(
        contact: trimmed,
        policyVersion: _string(value['policy']),
        roleWire: _string(value['role']),
        homiziWire: _string(value['wire']),
      );
    } on Object {
      return null;
    }
  }
}

String? _string(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

abstract class DemoSessionStore {
  Future<PersistedDemoSession?> read();

  Future<void> write(PersistedDemoSession session);

  Future<void> clear();
}

/// shared_preferences via the same channels the rest of the app already uses.
class DeviceDemoSessionStore implements DemoSessionStore {
  const DeviceDemoSessionStore();

  /// Widget tests forward an unknown channel to the engine and never get a
  /// reply, so a boot that waits on it never leaves the splash. Tests that
  /// care about the record pass [MemoryDemoSessionStore].
  bool get _answers {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return !name.contains('Test');
  }

  @override
  Future<PersistedDemoSession?> read() async {
    if (!_answers) {
      return null;
    }
    final raw = await readDeviceString(demoSessionPrefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return PersistedDemoSession.decode(raw);
  }

  @override
  Future<void> write(PersistedDemoSession session) async {
    if (!_answers) {
      return;
    }
    await writeDeviceString(demoSessionPrefsKey, session.encode());
  }

  @override
  Future<void> clear() async {
    if (!_answers) {
      return;
    }
    await removeDeviceString(demoSessionPrefsKey);
  }
}

/// Test double. One instance can be shared across provider containers.
class MemoryDemoSessionStore implements DemoSessionStore {
  PersistedDemoSession? value;

  @override
  Future<PersistedDemoSession?> read() async => value;

  @override
  Future<void> write(PersistedDemoSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final demoSessionStoreProvider = Provider<DemoSessionStore>(
  (ref) => const DeviceDemoSessionStore(),
);
