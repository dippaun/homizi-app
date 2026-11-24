import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';

/// Latest testing profile. The code is never stored.
const demoLoginPrefsKey = 'homizi.demo_login_profile';

class DemoLoginRecord {
  const DemoLoginRecord({
    required this.aliasEmail,
    required this.userId,
    this.displayName,
    this.homiziWire,
    this.enteredAs,
  });

  final String aliasEmail;
  final String userId;
  final String? displayName;
  final String? homiziWire;

  /// Email or phone the person typed. The profile shows this, not [aliasEmail].
  final String? enteredAs;

  DemoLoginRecord copyWith({
    String? aliasEmail,
    String? userId,
    String? displayName,
    String? homiziWire,
    String? enteredAs,
  }) {
    return DemoLoginRecord(
      aliasEmail: aliasEmail ?? this.aliasEmail,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      homiziWire: homiziWire ?? this.homiziWire,
      enteredAs: enteredAs ?? this.enteredAs,
    );
  }

  String encode() {
    return jsonEncode({
      'alias': aliasEmail,
      'userId': userId,
      'name': displayName,
      'wire': homiziWire,
      'entered': enteredAs,
    });
  }

  static DemoLoginRecord? decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map) {
        return null;
      }
      final alias = value['alias'];
      final userId = value['userId'];
      if (alias is! String || userId is! String) {
        return null;
      }
      final email = alias.trim().toLowerCase();
      final id = userId.trim();
      if (email.isEmpty || id.isEmpty) {
        return null;
      }
      return DemoLoginRecord(
        aliasEmail: email,
        userId: id,
        displayName: _text(value['name']),
        homiziWire: _text(value['wire']),
        enteredAs: _text(value['entered']),
      );
    } on Object {
      return null;
    }
  }
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

abstract class DemoLoginStore {
  Future<DemoLoginRecord?> read();

  Future<void> write(DemoLoginRecord record);

  Future<void> clear();
}

/// Device copy plus an in-memory record for this process.
class DeviceDemoLoginStore implements DemoLoginStore {
  DemoLoginRecord? memory;

  bool get _answers {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return !name.contains('Test');
  }

  @override
  Future<DemoLoginRecord?> read() async {
    if (memory != null) {
      return memory;
    }
    if (!_answers) {
      return null;
    }
    final raw = await readDeviceString(demoLoginPrefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    memory = DemoLoginRecord.decode(raw);
    return memory;
  }

  @override
  Future<void> write(DemoLoginRecord record) async {
    memory = record;
    if (!_answers) {
      return;
    }
    await writeDeviceString(demoLoginPrefsKey, record.encode());
  }

  @override
  Future<void> clear() async {
    memory = null;
    if (!_answers) {
      return;
    }
    await removeDeviceString(demoLoginPrefsKey);
  }
}

final demoLoginStoreProvider = Provider<DemoLoginStore>(
  (ref) => DeviceDemoLoginStore(),
);
