import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

/// After sign-in, a pending tenant profile chooses the tenant role once.
class TenantJourneyResume extends ConsumerStatefulWidget {
  const TenantJourneyResume({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TenantJourneyResume> createState() =>
      _TenantJourneyResumeState();
}

class _TenantJourneyResumeState extends ConsumerState<TenantJourneyResume> {
  var _applying = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      unawaited(_resume());
    });
    ref.listen(tenantIntentProvider, (previous, next) {
      unawaited(_resume());
    });
    return widget.child;
  }

  Future<void> _resume() async {
    if (_applying) {
      return;
    }
    if (ref.read(tenantIntentProvider) != TenantIntent.profile) {
      return;
    }
    final session = ref.read(sessionProvider);
    if (session.phase != SessionPhase.needsRole) {
      return;
    }
    if (session.homiziWire != null && session.homiziWire != 'tenant') {
      return;
    }
    _applying = true;
    try {
      await ref.read(sessionProvider.notifier).selectPrimaryRole('tenant');
    } finally {
      _applying = false;
    }
  }
}
