import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/session/session_controller.dart';

const pgOwnerModeKey = 'flutter.homizi.pg_owner';

/// The person chose Post as PG Owner. It stays with their account.
class PgOwnerMode extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.watch(sessionProvider.select((session) => session.userId));
    final raw = await readDeviceString(pgOwnerModeKey);
    return raw == '1';
  }

  Future<void> enable() async {
    state = const AsyncData(true);
    await writeDeviceString(pgOwnerModeKey, '1');
  }
}

final pgOwnerModeProvider = AsyncNotifierProvider<PgOwnerMode, bool>(
  PgOwnerMode.new,
);

bool pgOwnerActive(AsyncValue<bool> mode) => mode.value == true;
