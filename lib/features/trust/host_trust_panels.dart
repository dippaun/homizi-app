import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/public_profile.dart';

class HostRoleChip extends StatelessWidget {
  const HostRoleChip({required this.role, super.key});

  final HostRole role;

  @override
  Widget build(BuildContext context) {
    if (role == HostRole.broker) {
      return const BrokerChip();
    }
    return Chip(
      key: Key('host-role-chip-${role.wire}'),
      label: Text(homiziText(context, role.chip)),
      backgroundColor: HomiziColors.mist,
      side: const BorderSide(color: HomiziColors.line),
      labelStyle: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class HostTrustRecord extends StatelessWidget {
  const HostTrustRecord({
    required this.host,
    required this.profile,
    required this.onSubmit,
    super.key,
  });

  final HostOnboardingDraft host;
  final ProfileCreateDraft profile;
  final ValueChanged<PropertyAuthKind> onSubmit;

  @override
  Widget build(BuildContext context) {
    final privacy = hostOnboardingPrivacy(host: host, profile: profile);
    final kinds = authorizationKindsFor(host.roles);
    final card = publicProfileFromDraft(
      profile,
    ).copyWith(nickname: host.nickname);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Your trust record'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        PublicProfileCard(profile: card),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final role in host.roles) HostRoleChip(role: role)],
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Identity Verification'),
          key: const Key('host-trust-identity'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _IdentityLine(
          label: 'Mobile Verified',
          done: profile.mobileVerified,
          iconKey: const Key('host-identity-mobile'),
        ),
        _IdentityLine(
          label: 'Email Verified',
          done: profile.emailVerified,
          iconKey: const Key('host-identity-email'),
        ),
        _IdentityLine(
          label: 'Aadhaar Verified',
          done: profile.aadhaarVerified,
          iconKey: const Key('host-identity-aadhaar'),
        ),
        _IdentityLine(
          label: 'Selfie Verified',
          done: profile.selfieVerified,
          iconKey: const Key('host-identity-selfie'),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Property Authorization'),
          key: const Key('host-trust-property'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final kind in kinds)
          _AuthRow(
            kind: kind,
            status: authorizationStatus(host, kind),
            onSubmit: () => onSubmit(kind),
          ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'A verified person is not automatically the owner of a property. Property authorization is checked separately.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          key: const Key('host-privacy-note'),
          homiziText(
            context,
            privacy.showsPhoto
                ? 'Your photo is visible to verified members because you opted in. Phone and email stay off this card.'
                : 'Contact details and photos follow your privacy settings. Your phone and email stay off this card. A photo appears only when you opt in and the viewer is verified.',
          ),
        ),
        const SizedBox(height: 20),
        const _RohanExample(),
      ],
    );
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.label,
    required this.done,
    required this.iconKey,
  });

  final String label;
  final bool done;
  final Key iconKey;

  @override
  Widget build(BuildContext context) {
    return ProfileCheckLine(
      label: done ? label : '$label — not yet',
      color: done ? profileVerifiedGreen : HomiziColors.muted,
      iconKey: iconKey,
    );
  }
}

class _AuthRow extends StatelessWidget {
  const _AuthRow({
    required this.kind,
    required this.status,
    required this.onSubmit,
  });

  final PropertyAuthKind kind;
  final PropertyAuthStatus status;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PropertyAuthStatus.verified => profileVerifiedGreen,
      PropertyAuthStatus.underReview => HomiziColors.accent,
      PropertyAuthStatus.notSubmitted => HomiziColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.article_outlined, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(homiziText(context, kind.label)),
                Text(
                  homiziText(context, status.label),
                  key: Key('host-auth-status-${kind.wire}'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (status != PropertyAuthStatus.verified)
            OutlinedButton(
              key: Key('host-auth-submit-${kind.wire}'),
              onPressed: onSubmit,
              child: Text(homiziText(context, 'Submit for review')),
            ),
        ],
      ),
    );
  }
}

class _RohanExample extends StatelessWidget {
  const _RohanExample();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        key: const Key('host-rohan-example'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, rohanTrustName),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const BrokerChip(),
            const SizedBox(height: 4),
            Text(homiziText(context, rohanTrustRole)),
            Text(homiziText(context, rohanTrustPlace)),
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'Identity Verification'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const ProfileCheckLine(
              label: 'Mobile Verified',
              color: profileVerifiedGreen,
            ),
            const ProfileCheckLine(
              label: 'Email Verified',
              color: profileVerifiedGreen,
            ),
            const ProfileCheckLine(
              label: 'Aadhaar Verified',
              color: profileVerifiedGreen,
            ),
            const ProfileCheckLine(
              label: 'Selfie Verified',
              color: profileVerifiedGreen,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Property Authorization'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final entry in rohanPropertyExamples.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  homiziText(
                    context,
                    '${entry.key.label} · ${entry.value.label}',
                  ),
                  key: Key('host-example-auth-${entry.key.wire}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HostCategoryShowcase extends StatelessWidget {
  const HostCategoryShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final example in hostCategoryExamples) ...[
          _ExampleCard(example: example),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final HostCategoryExample example;

  @override
  Widget build(BuildContext context) {
    final initial = example.name.characters.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        key: Key('host-example-${example.role.wire}'),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: HomiziColors.mist,
              foregroundColor: HomiziColors.ink,
              child: Text(initial),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, example.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(context, example.line),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  HostRoleChip(role: example.role),
                  const SizedBox(height: 4),
                  const Text(
                    'Verified',
                    style: TextStyle(
                      color: profileVerifiedGreen,
                      fontWeight: FontWeight.w700,
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

class HostResponsibilityList extends StatelessWidget {
  const HostResponsibilityList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < hostResponsibilityRules.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: HomiziColors.accentWash,
                foregroundColor: HomiziColors.ink,
                child: Text('${i + 1}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  homiziText(context, hostResponsibilityRules[i]),
                  key: Key('host-rule-$i'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Trusted People · Genuine Listings · Safer Rentals',
          ),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            "Together, let's create a better renting experience with Homizi.",
          ),
        ),
      ],
    );
  }
}
