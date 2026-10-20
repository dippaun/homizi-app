import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen>
    with WidgetsBindingObserver {
  KycDocumentKind _kind = KycDocumentKind.digilocker;
  var _consent = false;
  var _busy = false;
  KycSnapshot _snapshot = KycSnapshot.notStarted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final snapshot = await ref.read(kycGatewayProvider).current();
    if (!mounted) {
      return;
    }
    if (_snapshot.unavailable &&
        snapshot.aadhaarStatus == KycCheckState.notStarted &&
        snapshot.faceStatus == KycCheckState.notStarted) {
      return;
    }
    final keepUrl =
        snapshot.gatewayUrl == null &&
        _snapshot.gatewayUrl != null &&
        (snapshot.aadhaarStatus == KycCheckState.inProgress ||
            snapshot.faceStatus == KycCheckState.inProgress);
    setState(() {
      _snapshot = keepUrl
          ? KycSnapshot(
              status: snapshot.status,
              aadhaarStatus: snapshot.aadhaarStatus,
              faceStatus: snapshot.faceStatus,
              message: snapshot.message,
              documentKind: snapshot.documentKind,
              providerReference: snapshot.providerReference,
              maskedLast4: snapshot.maskedLast4,
              gatewayUrl: _snapshot.gatewayUrl,
            )
          : snapshot;
    });
  }

  Future<void> _start() async {
    final needsConsent = _snapshot.status == 'not_started';
    if (needsConsent && !_consent) {
      setState(
        () => _snapshot = const KycSnapshot(
          status: 'not_started',
          aadhaarStatus: KycCheckState.notStarted,
          faceStatus: KycCheckState.notStarted,
          message: 'Consent is required before verification.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final gateway = ref.read(kycGatewayProvider);
      if (needsConsent) {
        await gateway.giveConsent(_kind);
      }
      final next = await gateway.start(_kind);
      if (mounted) {
        setState(() => _snapshot = next);
      }
    } on KycFailure catch (error) {
      if (mounted) {
        setState(
          () => _snapshot = KycSnapshot(
            status: _snapshot.status,
            aadhaarStatus: _snapshot.aadhaarStatus,
            faceStatus: _snapshot.faceStatus,
            maskedLast4: _snapshot.maskedLast4,
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

  Future<void> _openDigio() async {
    final gateway = _snapshot.gatewayUrl;
    if (gateway == null) {
      return;
    }
    final uri = kycGatewayUri(gateway, returnUrl: kycReturnUrl());
    if (uri == null) {
      return;
    }
    final opened = await ref.read(kycLauncherProvider).open(uri);
    if (!opened && mounted) {
      setState(
        () => _snapshot = KycSnapshot(
          status: _snapshot.status,
          aadhaarStatus: _snapshot.aadhaarStatus,
          faceStatus: _snapshot.faceStatus,
          gatewayUrl: _snapshot.gatewayUrl,
          maskedLast4: _snapshot.maskedLast4,
          message: 'Verification could not be opened. Try again.',
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(homiziText(context, 'Delete verification data')),
        content: Text(homiziText(context, kycDeleteCopy)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(homiziText(context, 'Cancel')),
          ),
          TextButton(
            key: const Key('kyc-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(homiziText(context, 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await ref.read(kycGatewayProvider).deleteMine();
      if (mounted) {
        setState(() {
          _snapshot = next;
          _consent = false;
        });
      }
    } on KycFailure catch (error) {
      if (mounted) {
        setState(
          () => _snapshot = KycSnapshot(
            status: _snapshot.status,
            aadhaarStatus: _snapshot.aadhaarStatus,
            faceStatus: _snapshot.faceStatus,
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Verify identity')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_snapshot.unavailable) ...[
            Text(
              homiziText(context, kycComingSoonCopy),
              key: const Key('kyc-coming-soon'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _StatusLine(
              label: aadhaarStatusLabel(KycCheckState.notStarted),
              lineKey: const Key('kyc-aadhaar-status'),
            ),
            const SizedBox(height: 8),
            _StatusLine(
              label: faceStatusLabel(KycCheckState.notStarted),
              lineKey: const Key('kyc-face-status'),
            ),
          ] else if (_snapshot.gatewayUrl != null) ...[
            Text(
              homiziText(context, 'Face scan'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, kycFaceStepCopy),
              key: const Key('kyc-face-step'),
            ),
            const SizedBox(height: 16),
            _StatusLine(
              label: aadhaarStatusLabel(_snapshot.aadhaarStatus),
              lineKey: const Key('kyc-aadhaar-status'),
            ),
            const SizedBox(height: 8),
            _StatusLine(
              label: faceStatusLabel(_snapshot.faceStatus),
              lineKey: const Key('kyc-face-status'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('kyc-open-digio'),
              onPressed: _busy ? null : () => unawaited(_openDigio()),
              child: Text(homiziText(context, 'Continue')),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('kyc-refresh'),
              onPressed: _busy ? null : () => unawaited(_load()),
              child: Text(homiziText(context, 'Check status')),
            ),
          ] else if (_snapshot.status == 'not_started' ||
              _snapshot.status == 'consent_given') ...[
            Text(
              homiziText(context, 'Consent'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, kycConsentCopy),
              key: const Key('kyc-consent-copy'),
            ),
            const SizedBox(height: 20),
            SegmentedButton<KycDocumentKind>(
              segments: [
                ButtonSegment(
                  value: KycDocumentKind.digilocker,
                  label: Text(homiziText(context, 'DigiLocker')),
                ),
                ButtonSegment(
                  value: KycDocumentKind.aadhaarOffline,
                  label: Text(homiziText(context, 'Aadhaar offline')),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (next) => setState(() => _kind = next.first),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('kyc-consent'),
              contentPadding: EdgeInsets.zero,
              value: _consent || _snapshot.status == 'consent_given',
              onChanged: _snapshot.status == 'not_started'
                  ? (value) => setState(() => _consent = value ?? false)
                  : null,
              title: Text(homiziText(context, kycConsentCheckbox)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('kyc-continue'),
              onPressed: _busy ? null : () => unawaited(_start()),
              child: Text(homiziText(context, 'Continue')),
            ),
          ] else ...[
            Text(
              homiziText(context, 'Verification'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _StatusLine(
              label: aadhaarStatusLabel(_snapshot.aadhaarStatus),
              lineKey: const Key('kyc-aadhaar-status'),
            ),
            const SizedBox(height: 8),
            _StatusLine(
              label: faceStatusLabel(_snapshot.faceStatus),
              lineKey: const Key('kyc-face-status'),
            ),
            if (_snapshot.canRetry) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('kyc-retry'),
                onPressed: _busy ? null : () => unawaited(_start()),
                child: Text(homiziText(context, 'Try again')),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            homiziText(context, _snapshot.message),
            key: const Key('kyc-status'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (_snapshot.maskedLast4 != null) ...[
            const SizedBox(height: 8),
            Text(
              '${homiziText(context, 'Aadhaar ending')} ${_snapshot.maskedLast4}',
              key: const Key('kyc-mask'),
            ),
          ],
          if (_snapshot.status != 'not_started' && !_snapshot.unavailable) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              key: const Key('kyc-delete'),
              onPressed: _busy ? null : () => unawaited(_delete()),
              child: Text(homiziText(context, 'Delete verification data')),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.lineKey});

  final String label;
  final Key lineKey;

  @override
  Widget build(BuildContext context) {
    return Text(homiziText(context, label), key: lineKey);
  }
}
