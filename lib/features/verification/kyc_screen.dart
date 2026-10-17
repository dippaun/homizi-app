import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  KycDocumentKind _kind = KycDocumentKind.digilocker;
  var _consent = false;
  var _busy = false;
  KycSnapshot _snapshot = KycSnapshot.notStarted;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final snapshot = await ref.read(kycGatewayProvider).current();
    if (mounted) {
      setState(() => _snapshot = snapshot);
    }
  }

  Future<void> _start() async {
    if (!_consent && _snapshot.status == 'not_started') {
      setState(
        () => _snapshot = const KycSnapshot(
          status: 'not_started',
          provider: 'demo',
          message: 'Consent is required before a sandbox check.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final gateway = ref.read(kycGatewayProvider);
      if (_snapshot.status == 'not_started') {
        await gateway.giveConsent(_kind);
      }
      final next = await gateway.startSandbox(_kind);
      if (mounted) {
        setState(() => _snapshot = next);
      }
    } on KycFailure catch (error) {
      if (mounted) {
        setState(
          () => _snapshot = KycSnapshot(
            status: _snapshot.status,
            provider: _snapshot.provider,
            message: error.message,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = _snapshot.maskedLast4;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Verify identity'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            homiziText(context, kycConsentCopy),
            key: const Key('kyc-consent-copy'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<KycDocumentKind>(
            segments: [
              for (final kind in KycDocumentKind.values)
                ButtonSegment(
                  value: kind,
                  label: Text(homiziText(context, kind.label)),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: _snapshot.isVerified
                ? null
                : (next) => setState(() => _kind = next.first),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('kyc-consent'),
            contentPadding: EdgeInsets.zero,
            value: _consent || _snapshot.status != 'not_started',
            onChanged: _snapshot.status == 'not_started'
                ? (value) => setState(() => _consent = value ?? false)
                : null,
            title: Text(
              homiziText(context, 'I consent to a sandbox identity check.'),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            key: const Key('kyc-continue'),
            onPressed: _busy || _snapshot.isVerified
                ? null
                : () => unawaited(_start()),
            child: Text(homiziText(context, 'Continue')),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, _snapshot.message),
            key: const Key('kyc-status'),
          ),
          if (masked != null) ...[
            const SizedBox(height: 8),
            Text('••••$masked', key: const Key('kyc-mask')),
          ],
          if (_snapshot.providerReference != null) ...[
            const SizedBox(height: 4),
            Text(_snapshot.providerReference!),
          ],
        ],
      ),
    );
  }
}
