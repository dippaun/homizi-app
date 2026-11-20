import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Verification tab: progress ring, live status marks, and one card per method.
class VerificationPanel extends StatefulWidget {
  const VerificationPanel({
    required this.emailVerified,
    required this.phoneVerified,
    required this.aadhaarVerified,
    required this.onEmail,
    required this.onPhone,
    required this.onAadhaar,
    super.key,
  });

  final bool emailVerified;
  final bool phoneVerified;
  final bool aadhaarVerified;
  final VoidCallback? onEmail;
  final VoidCallback? onPhone;
  final VoidCallback onAadhaar;

  @override
  State<VerificationPanel> createState() => _VerificationPanelState();
}

class _VerificationPanelState extends State<VerificationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = [
      widget.emailVerified,
      widget.phoneVerified,
      widget.aadhaarVerified,
    ].where((item) => item).length;
    final level = done / 3;
    return Column(
      key: const Key('profile-verification-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: HomiziColors.soft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: level,
                        strokeWidth: 7,
                        backgroundColor: HomiziColors.line,
                        color: done == 3
                            ? HomiziColors.success
                            : HomiziColors.logoOrange,
                      ),
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(
                          CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Icon(
                          done == 3 ? Icons.verified : Icons.shield_outlined,
                          color: done == 3
                              ? HomiziColors.success
                              : HomiziColors.logoOrange,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, 'Trust level'),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(
                          context,
                          done == 3
                              ? 'Fully verified. Hosts can trust this profile.'
                              : '$done of 3 checks complete.',
                        ),
                        style: const TextStyle(
                          color: HomiziColors.inkSoft,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          title: 'Email',
          detail: widget.emailVerified
              ? 'Email verified'
              : 'Confirm the email on this account.',
          verified: widget.emailVerified,
          pulse: _pulse,
          action: 'Verify email',
          onPressed: widget.emailVerified ? null : widget.onEmail,
        ),
        if (!widget.phoneVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              homiziText(context, 'Verify phone'),
              key: const Key('verify-phone-prompt'),
              style: const TextStyle(
                color: HomiziColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        _MethodCard(
          title: 'Mobile',
          detail: widget.phoneVerified ? 'Mobile verified' : 'Verify phone',
          verified: widget.phoneVerified,
          pulse: _pulse,
          action: 'Verify phone',
          onPressed: widget.phoneVerified ? null : widget.onPhone,
        ),
        _MethodCard(
          title: 'Aadhaar',
          detail: widget.aadhaarVerified
              ? 'Aadhaar verified'
              : 'Aadhaar is not verified yet.',
          verified: widget.aadhaarVerified,
          pulse: _pulse,
          action: 'Get verified',
          onPressed: widget.aadhaarVerified ? null : widget.onAadhaar,
        ),
        const SizedBox(height: 8),
        const _TrustBenefits(),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.title,
    required this.detail,
    required this.verified,
    required this.pulse,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final bool verified;
  final Animation<double> pulse;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _LiveMark(verified: verified, pulse: pulse),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      homiziText(context, detail),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPressed != null)
                TextButton(
                  onPressed: onPressed,
                  child: Text(
                    homiziText(context, action),
                    style: const TextStyle(
                      color: HomiziColors.logoOrange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMark extends StatelessWidget {
  const _LiveMark({required this.verified, required this.pulse});

  final bool verified;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      verified ? Icons.check_circle : Icons.shield_outlined,
      color: verified ? HomiziColors.success : HomiziColors.logoOrange,
      size: 28,
    );
    if (verified) {
      return icon;
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(pulse),
      child: icon,
    );
  }
}

class _TrustBenefits extends StatelessWidget {
  const _TrustBenefits();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.verified_user_outlined, 'A badge hosts recognise'),
      (Icons.lock_outline, 'Contact stays private'),
      (Icons.handshake_outlined, 'Faster, safer matches'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, 'Why verify'),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(item.$1, color: HomiziColors.logoOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        homiziText(context, item.$2),
                        style: const TextStyle(color: HomiziColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
