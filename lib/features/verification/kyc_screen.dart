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

/// The steps of the Aadhaar + face check. Only the server (the Digio
/// webhook) can move anyone to [verified].
enum KycPhase {
  loading,
  comingSoon,
  intro,
  method,
  consent,
  face,
  pending,
  expired,
  failed,
  verified,
}

/// How often the pending screen asks the server, and for how long.
const kycPollEvery = Duration(seconds: 5);
const kycPollFor = Duration(minutes: 3);

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key, this.now});

  /// Test clock for link expiry.
  final DateTime Function()? now;

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen>
    with WidgetsBindingObserver {
  KycPhase _phase = KycPhase.loading;
  KycDocumentKind _kind = KycDocumentKind.digilocker;
  KycSnapshot _snapshot = KycSnapshot.notStarted;
  var _available = false;
  var _consent = false;
  var _busy = false;
  String? _error;
  Timer? _poll;
  DateTime? _pollUntil;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  bool get _inWizard =>
      _phase == KycPhase.intro ||
      _phase == KycPhase.method ||
      _phase == KycPhase.consent ||
      _phase == KycPhase.face;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load(first: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool first = false}) async {
    final gateway = ref.read(kycGatewayProvider);
    final results = await Future.wait<Object>([
      gateway.available(),
      gateway.current(),
    ]);
    if (!mounted) {
      return;
    }
    final available = results[0] as bool;
    final fresh = results[1] as KycSnapshot;
    final snapshot = fresh.gatewayUrl == null && fresh.isPending
        ? fresh.copyWith(gatewayUrl: _snapshot.gatewayUrl)
        : fresh;
    final stage = kycStageFor(snapshot, available: available, now: _now());
    final next = switch (stage) {
      KycStage.comingSoon => KycPhase.comingSoon,
      KycStage.start => KycPhase.intro,
      KycStage.pending => KycPhase.pending,
      KycStage.expired => KycPhase.expired,
      KycStage.failed => KycPhase.failed,
      KycStage.verified => KycPhase.verified,
    };
    setState(() {
      _available = available;
      _snapshot = snapshot;
      // Someone mid-way through the steps keeps their place unless the
      // server has a final answer or the service closed.
      final keepStep =
          !first &&
          _inWizard &&
          next != KycPhase.verified &&
          next != KycPhase.comingSoon;
      if (!keepStep) {
        _phase = next;
      }
    });
    _syncPolling();
  }

  void _syncPolling() {
    if (_phase != KycPhase.pending) {
      _poll?.cancel();
      _poll = null;
      _pollUntil = null;
      return;
    }
    if (_poll != null) {
      return;
    }
    _pollUntil = _now().add(kycPollFor);
    _poll = Timer.periodic(kycPollEvery, (_) {
      final until = _pollUntil;
      if (!mounted || until == null || _now().isAfter(until)) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      unawaited(_load());
    });
  }

  void _go(KycPhase phase) {
    setState(() {
      _phase = phase;
      _error = null;
    });
    _syncPolling();
  }

  void _back() {
    switch (_phase) {
      case KycPhase.method:
        _go(
          _snapshot.isFailed || _snapshot.isExpired(_now())
              ? KycPhase.failed
              : KycPhase.intro,
        );
      case KycPhase.consent:
        _go(KycPhase.method);
      case KycPhase.face:
        _go(KycPhase.consent);
      default:
        HomiziBackButton.leave(context);
    }
  }

  Future<void> _begin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final gateway = ref.read(kycGatewayProvider);
      await gateway.giveConsent(_kind);
      final next = await gateway.start(_kind, returnUrl: kycReturnUrl());
      if (!mounted) {
        return;
      }
      if (next.unavailable) {
        setState(() {
          _available = false;
          _snapshot = next;
          _phase = KycPhase.comingSoon;
        });
        _syncPolling();
        return;
      }
      setState(() {
        _snapshot = next;
        _phase = next.isVerified ? KycPhase.verified : KycPhase.pending;
      });
      _syncPolling();
      await _openDigio();
    } on KycFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
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
    final opened = uri != null && await ref.read(kycLauncherProvider).open(uri);
    if (!opened && mounted) {
      setState(
        () => _error =
            'Digio could not be opened. Tap "Open Digio" to try again.',
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
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = next;
        _consent = false;
        _phase = _available ? KycPhase.intro : KycPhase.comingSoon;
        _error = null;
      });
      _syncPolling();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(homiziText(context, 'Verification data deleted.')),
        ),
      );
    } on KycFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: HomiziBackButton(onPressed: _back),
        title: Text(homiziText(context, 'Verify identity')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: Key('kyc-phase-${_phase.name}'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_phase != KycPhase.loading &&
                _phase != KycPhase.comingSoon &&
                _phase != KycPhase.verified)
              _Progress(phase: _phase),
            ..._body(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Notice(
                key: const Key('kyc-error'),
                text: _error!,
                color: HomiziColors.error,
                wash: HomiziColors.errorWash,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final text = Theme.of(context).textTheme;
    switch (_phase) {
      case KycPhase.loading:
        return const [
          SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(color: HomiziColors.logoOrange),
          ),
        ];
      case KycPhase.comingSoon:
        return [
          const SizedBox(height: 24),
          const _Hero(
            icon: Icons.schedule,
            color: HomiziColors.logoOrange,
            wash: HomiziColors.accentWash,
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Verification coming soon'),
            key: const Key('kyc-coming-soon'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, kycComingSoonDetail),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 24),
          _checks(context),
          const SizedBox(height: 12),
          Text(
            homiziText(context, kycComingSoonCopy),
            key: const Key('kyc-status'),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: HomiziColors.muted),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('kyc-done'),
            onPressed: () => HomiziBackButton.leave(context),
            child: Text(homiziText(context, 'Back to profile')),
          ),
        ];
      case KycPhase.intro:
        return [
          const SizedBox(height: 8),
          const _Hero(
            icon: Icons.verified_user_outlined,
            color: HomiziColors.logoOrange,
            wash: HomiziColors.accentWash,
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Get verified with Aadhaar'),
            key: const Key('kyc-intro'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Two quick checks through Digio: your Aadhaar, then a live selfie matched to the Aadhaar photo. Verified people get green badges on their profile, listings, and cards.',
            ),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 20),
          _Card(
            title: 'Your privacy',
            child: Column(
              key: const Key('kyc-privacy'),
              children: [
                for (final note in kycPrivacyNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: HomiziColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(homiziText(context, note))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _GradientCta(
            ctaKey: const Key('kyc-get-started'),
            label: 'Get started',
            onPressed: () => _go(KycPhase.method),
          ),
        ];
      case KycPhase.method:
        return [
          Text(
            homiziText(context, 'Choose how to share Aadhaar'),
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _MethodTile(
            tileKey: const Key('kyc-method-digilocker'),
            icon: Icons.account_balance_wallet_outlined,
            title: 'DigiLocker',
            detail: kycDigilockerCopy,
            badge: 'Recommended',
            selected: _kind == KycDocumentKind.digilocker,
            onTap: () => setState(() => _kind = KycDocumentKind.digilocker),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            tileKey: const Key('kyc-method-offline'),
            icon: Icons.description_outlined,
            title: 'Offline Aadhaar',
            detail: kycOfflineCopy,
            selected: _kind == KycDocumentKind.aadhaarOffline,
            onTap: () => setState(() => _kind = KycDocumentKind.aadhaarOffline),
          ),
          const SizedBox(height: 20),
          _GradientCta(
            ctaKey: const Key('kyc-method-next'),
            label: 'Continue',
            onPressed: () => _go(KycPhase.consent),
          ),
        ];
      case KycPhase.consent:
        return [
          Text(
            homiziText(context, 'Your consent'),
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Text(
              homiziText(context, kycConsentCopy),
              key: const Key('kyc-consent-copy'),
              style: text.bodyMedium?.copyWith(
                color: HomiziColors.inkSoft,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('kyc-consent'),
            contentPadding: EdgeInsets.zero,
            activeColor: HomiziColors.logoOrange,
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
            title: Text(homiziText(context, kycConsentCheckbox)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          _GradientCta(
            ctaKey: const Key('kyc-continue'),
            label: 'I agree, continue',
            onPressed: _consent ? () => _go(KycPhase.face) : null,
          ),
        ];
      case KycPhase.face:
        return [
          Text(
            homiziText(context, 'Next: Aadhaar, then a selfie'),
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepLine(
                  number: '1',
                  text: _kind == KycDocumentKind.digilocker
                      ? 'Confirm your Aadhaar in DigiLocker.'
                      : 'Upload your Aadhaar Offline XML and share code.',
                ),
                const _StepLine(
                  number: '2',
                  text: 'Take a live selfie. Good light, no glasses or mask.',
                ),
                const _StepLine(
                  number: '3',
                  text:
                      'Digio matches it to your Aadhaar photo and sends us the result.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, kycFaceStepCopy),
            key: const Key('kyc-face-step'),
            style: text.bodyMedium?.copyWith(color: HomiziColors.muted),
          ),
          const SizedBox(height: 20),
          _GradientCta(
            ctaKey: const Key('kyc-open-digio'),
            label: 'Open secure check',
            busy: _busy,
            onPressed: _busy ? null : () => unawaited(_begin()),
          ),
        ];
      case KycPhase.pending:
        return [
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: HomiziColors.logoOrange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Checking with Digio'),
            key: const Key('kyc-pending'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, kycPendingCopy),
            key: const Key('kyc-status'),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 20),
          _checks(context),
          const SizedBox(height: 20),
          if (_snapshot.gatewayUrl != null) ...[
            _GradientCta(
              ctaKey: const Key('kyc-reopen'),
              label: 'Open Digio',
              onPressed: () => unawaited(_openDigio()),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            key: const Key('kyc-refresh'),
            onPressed: _busy ? null : () => unawaited(_load()),
            child: Text(homiziText(context, 'Check status')),
          ),
          const SizedBox(height: 16),
          _deleteLink(context),
        ];
      case KycPhase.expired:
      case KycPhase.failed:
        final expired = _phase == KycPhase.expired;
        return [
          const SizedBox(height: 16),
          const _Hero(
            icon: Icons.refresh,
            color: HomiziColors.error,
            wash: HomiziColors.errorWash,
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(
              context,
              expired ? 'Link expired' : 'Verification did not finish',
            ),
            key: Key(expired ? 'kyc-expired' : 'kyc-failed'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              expired
                  ? kycExpiredCopy
                  : 'Digio could not confirm your Aadhaar or the selfie match. This often happens with low light or a mismatch in the photo. Nothing was saved except the result.',
            ),
            key: const Key('kyc-status'),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 20),
          _checks(context),
          const SizedBox(height: 20),
          _GradientCta(
            ctaKey: const Key('kyc-retry'),
            label: 'Try again',
            onPressed: () => _go(KycPhase.method),
          ),
          const SizedBox(height: 16),
          _deleteLink(context),
        ];
      case KycPhase.verified:
        return [
          const SizedBox(height: 24),
          const _Hero(
            icon: Icons.verified,
            color: HomiziColors.success,
            wash: HomiziColors.successWash,
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, "You're verified"),
            key: const Key('kyc-success'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, kycSuccessCopy),
            key: const Key('kyc-status'),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 20),
          _checks(context),
          if (_snapshot.maskedLast4 != null) ...[
            const SizedBox(height: 12),
            Text(
              '${homiziText(context, 'Aadhaar ending')} ${_snapshot.maskedLast4}',
              key: const Key('kyc-mask'),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: HomiziColors.muted),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kyc-done'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.success,
              foregroundColor: HomiziColors.onSuccess,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => HomiziBackButton.leave(context),
            child: Text(homiziText(context, 'Done')),
          ),
          const SizedBox(height: 16),
          _deleteLink(context),
        ];
    }
  }

  Widget _checks(BuildContext context) {
    final unavailable = _phase == KycPhase.comingSoon;
    final aadhaar = unavailable
        ? KycCheckState.notStarted
        : _snapshot.aadhaarStatus;
    final face = unavailable ? KycCheckState.notStarted : _snapshot.faceStatus;
    return _Card(
      child: Column(
        children: [
          _CheckLine(
            lineKey: const Key('kyc-aadhaar-status'),
            label: aadhaarStatusLabel(aadhaar),
            state: aadhaar,
          ),
          const Divider(height: 20, color: HomiziColors.line),
          _CheckLine(
            lineKey: const Key('kyc-face-status'),
            label: faceStatusLabel(face),
            state: face,
          ),
        ],
      ),
    );
  }

  Widget _deleteLink(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('kyc-delete'),
        style: TextButton.styleFrom(foregroundColor: HomiziColors.muted),
        onPressed: _busy ? null : () => unawaited(_delete()),
        child: Text(homiziText(context, 'Delete verification data')),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.phase});

  final KycPhase phase;

  @override
  Widget build(BuildContext context) {
    final step = switch (phase) {
      KycPhase.intro => 0,
      KycPhase.method => 1,
      KycPhase.consent => 2,
      KycPhase.face => 3,
      _ => 4,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step
                      ? HomiziColors.logoOrange
                      : HomiziColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 4) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.icon, required this.color, required this.wash});

  final IconData icon;
  final Color color;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
        child: Icon(icon, size: 46, color: color),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        border: Border.all(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              homiziText(context, title!),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({
    required this.ctaKey,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final Key ctaKey;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ctaKey,
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              height: 52,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: HomiziColors.white,
                        ),
                      )
                    : Text(
                        homiziText(context, label),
                        style: const TextStyle(
                          color: HomiziColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String detail;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? HomiziColors.accentWash : HomiziColors.white,
            border: Border.all(
              color: selected ? HomiziColors.logoOrange : HomiziColors.line,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HomiziColors.logoOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          homiziText(context, title),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: HomiziColors.ink,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HomiziColors.successWash,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              homiziText(context, badge!),
                              style: text.labelSmall?.copyWith(
                                color: HomiziColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, detail),
                      style: text.bodyMedium?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? HomiziColors.logoOrange : HomiziColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: HomiziColors.accentWash,
            child: Text(
              number,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(homiziText(context, text))),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.lineKey,
    required this.label,
    required this.state,
  });

  final Key lineKey;
  final String label;
  final KycCheckState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      KycCheckState.verified => (Icons.check_circle, HomiziColors.success),
      KycCheckState.failed => (Icons.cancel, HomiziColors.error),
      KycCheckState.inProgress => (Icons.timelapse, HomiziColors.logoOrange),
      KycCheckState.notStarted => (
        Icons.radio_button_unchecked,
        HomiziColors.muted,
      ),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            homiziText(context, label),
            key: lineKey,
            style: TextStyle(
              color: state == KycCheckState.verified
                  ? HomiziColors.success
                  : HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.text,
    required this.color,
    required this.wash,
    required this.icon,
  });

  final String text;
  final Color color;
  final Color wash;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(context, text),
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
