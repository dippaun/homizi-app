import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Email and mobile confirmation from Auth, with a Verify action when needed.
class ContactVerifyBadges extends StatelessWidget {
  const ContactVerifyBadges({
    required this.emailVerified,
    required this.phoneVerified,
    required this.onVerifyEmail,
    required this.onVerifyPhone,
    super.key,
  });

  final bool emailVerified;
  final bool phoneVerified;
  final VoidCallback? onVerifyEmail;
  final VoidCallback? onVerifyPhone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ContactVerifyBadge(
          badgeKey: const Key('email-verified-badge'),
          actionKey: const Key('verify-email'),
          label: 'Email verified',
          verified: emailVerified,
          onVerify: onVerifyEmail,
        ),
        const SizedBox(height: 8),
        ContactVerifyBadge(
          badgeKey: const Key('mobile-verified-badge'),
          actionKey: const Key('verify-mobile'),
          label: 'Mobile verified',
          verified: phoneVerified,
          onVerify: onVerifyPhone,
        ),
      ],
    );
  }
}

class ContactVerifyBadge extends StatelessWidget {
  const ContactVerifyBadge({
    required this.label,
    required this.verified,
    required this.badgeKey,
    required this.actionKey,
    super.key,
    this.onVerify,
  });

  final String label;
  final bool verified;
  final Key badgeKey;
  final Key actionKey;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final verify = onVerify;
    return Material(
      color: verified ? HomiziColors.successWash : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: verified ? HomiziColors.success : HomiziColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified : Icons.verified_outlined,
              color: verified ? HomiziColors.success : HomiziColors.logoOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                homiziText(context, label),
                key: badgeKey,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (verified)
              const Text(
                'Verified',
                style: TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (verify != null)
              TextButton(
                key: actionKey,
                onPressed: verify,
                child: Text(
                  homiziText(context, 'Verify'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
