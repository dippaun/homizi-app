import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';

const partnerPostedKey = 'flutter.homizi.partner_posted';

/// True after a property partner has posted a property.
///
/// Their bar is then only Home, Chat, and Profile.
class PartnerShellController extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    String? raw;
    try {
      raw = await readDeviceString(partnerPostedKey);
    } on Object {
      raw = null;
    }
    if (raw == '1' && ref.mounted) {
      state = true;
    }
  }

  Future<void> markPosted() async {
    state = true;
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    try {
      await writeDeviceString(partnerPostedKey, '1');
    } on Object {
      // The in-memory flag still switches the bar for this session.
    }
  }
}

final partnerShellProvider = NotifierProvider<PartnerShellController, bool>(
  PartnerShellController.new,
);
