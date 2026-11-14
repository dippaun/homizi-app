import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';

/// One row per contact. The verification state sits on that same row.
class ContactVerifyBadges extends StatelessWidget {
  const ContactVerifyBadges({
    required this.email,
    required this.phone,
    required this.emailVerified,
    required this.phoneVerified,
    required this.onVerifyEmail,
    required this.onVerifyPhone,
    super.key,
  });

  final String email;
  final String phone;
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
          valueKey: const Key('profile-email'),
          verifiedLabel: 'Email',
          unverifiedLabel: 'Email not verified',
          value: email,
          verified: emailVerified,
          unverifiedIcon: Icons.mail_outline,
          onVerify: onVerifyEmail,
        ),
        ContactVerifyBadge(
          badgeKey: const Key('mobile-verified-badge'),
          actionKey: const Key('verify-mobile'),
          valueKey: const Key('profile-phone'),
          verifiedLabel: 'Mobile',
          unverifiedLabel: 'Mobile not verified',
          value: phone,
          verified: phoneVerified,
          unverifiedIcon: Icons.phone_outlined,
          onVerify: onVerifyPhone,
        ),
      ],
    );
  }
}

/// Prefers the auth user's phone. Falls back to the profile contact line.
String profilePhoneDisplay({
  required String phoneE164,
  required String fallback,
}) {
  if (phoneE164.trim().isEmpty) {
    return fallback;
  }
  return maskProfilePhone(phoneE164);
}

class ContactVerifyBadge extends StatelessWidget {
  const ContactVerifyBadge({
    required this.verifiedLabel,
    required this.unverifiedLabel,
    required this.value,
    required this.verified,
    required this.unverifiedIcon,
    required this.badgeKey,
    required this.actionKey,
    required this.valueKey,
    super.key,
    this.onVerify,
  });

  final String verifiedLabel;
  final String unverifiedLabel;
  final String value;
  final bool verified;
  final IconData unverifiedIcon;
  final Key badgeKey;
  final Key actionKey;
  final Key valueKey;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verify = onVerify;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: verified ? HomiziColors.successWash : HomiziColors.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(
              verified ? Icons.check_circle : unverifiedIcon,
              color: verified ? HomiziColors.success : HomiziColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(
                    context,
                    verified ? verifiedLabel : unverifiedLabel,
                  ),
                  key: badgeKey,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  homiziText(context, value),
                  key: valueKey,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: HomiziColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HomiziColors.successWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          else if (verify != null)
            FilledButton(
              key: actionKey,
              style: FilledButton.styleFrom(
                backgroundColor: HomiziColors.logoOrange,
                foregroundColor: HomiziColors.ink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 36),
                shape: const StadiumBorder(),
              ),
              onPressed: verify,
              child: Text(homiziText(context, 'Verify')),
            ),
        ],
      ),
    );
  }
}
