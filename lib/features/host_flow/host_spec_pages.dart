import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/host/listing_identity_step.dart';
import 'package:homizi/features/host_flow/host_flow_chrome.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/trust/host_trust_panels.dart';

/// Spec-styled Become a Host pages. The screen still owns the draft and save.
class HostSpecFlow extends StatelessWidget {
  const HostSpecFlow({
    required this.step,
    required this.confirmed,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onContinue,
    required this.onListProperty,
    required this.scrollController,
    required this.roles,
    required this.onToggleRole,
    required this.addingRole,
    required this.onAddRole,
    required this.agreement,
    required this.onAgreement,
    required this.fullName,
    required this.nickname,
    required this.mobile,
    required this.email,
    required this.gender,
    required this.onGender,
    required this.onMobileChanged,
    required this.onEmailChanged,
    required this.demoIdentity,
    required this.mobileVerified,
    required this.emailVerified,
    required this.aadhaarVerified,
    required this.selfieVerified,
    required this.mobileOtpSent,
    required this.emailOtpSent,
    required this.aadhaarOtpSent,
    required this.mobileOtp,
    required this.emailOtp,
    required this.aadhaar,
    required this.aadhaarOtp,
    required this.aadhaarFormatters,
    required this.onSendMobile,
    required this.onVerifyMobile,
    required this.onSendEmail,
    required this.onVerifyEmail,
    required this.onSendAadhaar,
    required this.onVerifyAadhaar,
    required this.onSamplePhoto,
    required this.onLiveness,
    required this.sampleReady,
    required this.onOpenDigio,
    required this.onSelfieCamera,
    required this.onSelfieUpload,
    required this.onVerifyLater,
    required this.selfieNote,
    required this.showPhoto,
    required this.onShowPhoto,
    required this.bio,
    required this.responseTime,
    required this.onResponse,
    required this.preferred,
    required this.onPreferred,
    required this.plan,
    required this.onPlan,
    required this.showCompany,
    required this.company,
    required this.registration,
    required this.host,
    required this.profile,
    required this.onSubmitAuth,
    required this.accepted,
    required this.onAccepted,
    super.key,
  });

  final int step;
  final bool confirmed;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onListProperty;
  final ScrollController scrollController;
  final Set<HostRole> roles;
  final ValueChanged<HostRole> onToggleRole;
  final bool addingRole;
  final VoidCallback onAddRole;
  final bool agreement;
  final ValueChanged<bool> onAgreement;
  final TextEditingController fullName;
  final TextEditingController nickname;
  final TextEditingController mobile;
  final TextEditingController email;
  final String? gender;
  final ValueChanged<String?> onGender;
  final VoidCallback onMobileChanged;
  final VoidCallback onEmailChanged;
  final bool demoIdentity;
  final bool mobileVerified;
  final bool emailVerified;
  final bool aadhaarVerified;
  final bool selfieVerified;
  final bool mobileOtpSent;
  final bool emailOtpSent;
  final bool aadhaarOtpSent;
  final TextEditingController mobileOtp;
  final TextEditingController emailOtp;
  final TextEditingController aadhaar;
  final TextEditingController aadhaarOtp;
  final List<TextInputFormatter> aadhaarFormatters;
  final VoidCallback onSendMobile;
  final VoidCallback onVerifyMobile;
  final VoidCallback onSendEmail;
  final VoidCallback onVerifyEmail;
  final VoidCallback onSendAadhaar;
  final VoidCallback onVerifyAadhaar;
  final VoidCallback onSamplePhoto;
  final VoidCallback onLiveness;
  final bool sampleReady;
  final VoidCallback onOpenDigio;
  final VoidCallback onSelfieCamera;
  final VoidCallback onSelfieUpload;
  final VoidCallback onVerifyLater;
  final String? selfieNote;
  final bool showPhoto;
  final ValueChanged<bool> onShowPhoto;
  final TextEditingController bio;
  final String? responseTime;
  final ValueChanged<String?> onResponse;
  final Set<String> preferred;
  final void Function(String type, bool selected) onPreferred;
  final HostPlan plan;
  final ValueChanged<HostPlan> onPlan;
  final bool showCompany;
  final TextEditingController company;
  final TextEditingController registration;
  final HostOnboardingDraft host;
  final ProfileCreateDraft profile;
  final ValueChanged<PropertyAuthKind> onSubmitAuth;
  final bool accepted;
  final ValueChanged<bool> onAccepted;

  @override
  Widget build(BuildContext context) {
    final copy = confirmed
        ? (
            'You are a host on Homizi',
            'Your host profile is saved. Identity checks and property checks stay separate.',
          )
        : hostOnboardingSteps[step];
    final badge = confirmed || step == 0 ? null : '${step + 1}/8';
    final last = step == hostOnboardingStepCount - 1;
    return FlowPage(
      pageKey: const Key('host-flow-page'),
      backKey: const Key('host-onboard-back'),
      scrollController: scrollController,
      onBack: saving ? null : onBack,
      stepLabel: badge,
      stepKey: const Key('host-onboard-step'),
      title: copy.$1,
      titleKey: const Key('host-onboard-title'),
      subtitle: copy.$2,
      body: confirmed ? const _HostConfirmed() : _body(context),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Text(
              homiziText(context, error!),
              key: const Key('host-onboard-error'),
              style: const TextStyle(color: HomiziColors.error),
            ),
            const SizedBox(height: 8),
          ],
          FlowContinueButton(
            label: confirmed
                ? 'List your property'
                : last
                ? 'Agree and finish'
                : step == 2
                ? 'Save & Continue'
                : 'Continue',
            busy: saving,
            buttonKey: confirmed
                ? const Key('host-flow-list')
                : const Key('host-onboard-continue'),
            onPressed: confirmed ? onListProperty : onContinue,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (step) {
      0 => const _HostIntro(),
      1 => _categories(context),
      2 => _profile(context),
      3 => _verify(),
      4 => _additional(context),
      5 => _trust(context),
      6 => const _CategoryProfiles(),
      _ => _responsibility(context),
    };
  }

  Widget _categories(BuildContext context) {
    const tones = <HostRole, (IconData, Color, Color)>{
      HostRole.owner: (
        Icons.home_rounded,
        HomiziColors.accent,
        HomiziColors.accentWash,
      ),
      HostRole.broker: (Icons.person, HomiziColors.ink, HomiziColors.soft),
      HostRole.roomie: (
        Icons.groups,
        HomiziColors.success,
        HomiziColors.successWash,
      ),
      HostRole.company: (
        Icons.apartment,
        HomiziColors.ink,
        HomiziColors.warningWash,
      ),
    };
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [
            for (final role in HostRole.values)
              _RoleTile(
                role: role,
                tone: tones[role]!,
                selected: roles.contains(role),
                onTap: () => onToggleRole(role),
              ),
          ],
        ),
        if (roles.contains(HostRole.roomie))
          CheckboxListTile(
            key: const Key('host-agreement-permit'),
            contentPadding: EdgeInsets.zero,
            value: agreement,
            onChanged: (value) => onAgreement(value ?? false),
            title: Text(
              homiziText(
                context,
                'I confirm my rental agreement permits me to share this home.',
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: flowCard(color: HomiziColors.accentWash),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: HomiziColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      homiziText(context, 'Add Multiple Roles'),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  homiziText(
                    context,
                    addingRole
                        ? 'Choose one more category below. One account can hold more than one role.'
                        : 'You can choose more than one role in a single account. For example, you can be an Existing Tenant for one property and a Broker for another.',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('host-add-role'),
                    onPressed: roles.length >= HostRole.values.length
                        ? null
                        : onAddRole,
                    child: Text(homiziText(context, 'Add another role')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Basic Information'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _iconField(
          icon: Icons.person_outline,
          child: TextField(
            key: const Key('host-full-name'),
            controller: fullName,
            textCapitalization: TextCapitalization.words,
            decoration: profileFieldDecoration(
              context,
              label: 'Full Name (for verification)',
              hint: 'Enter your full name',
              helper: 'Private, never shown publicly',
            ),
          ),
        ),
        _iconField(
          icon: Icons.badge_outlined,
          child: TextField(
            key: const Key('host-nickname'),
            controller: nickname,
            textCapitalization: TextCapitalization.words,
            decoration: profileFieldDecoration(
              context,
              label: 'Nick Name (public profile)',
              hint: 'Enter your display name',
            ),
          ),
        ),
        _iconField(
          icon: Icons.wc_outlined,
          child: DropdownButtonFormField<String>(
            key: ValueKey('host-gender-${gender ?? ''}'),
            initialValue: gender,
            decoration: profileFieldDecoration(
              context,
              label: 'Gender (optional)',
              hint: 'Select gender',
            ),
            items: [
              for (final option in profileGenderOptions)
                DropdownMenuItem(
                  value: option,
                  child: Text(homiziText(context, option)),
                ),
            ],
            onChanged: onGender,
          ),
        ),
        _iconField(
          icon: Icons.phone_android,
          child: TextField(
            key: const Key('host-mobile'),
            controller: mobile,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: profileFieldDecoration(
              context,
              label: 'Mobile Number',
              prefix: '+91 ',
              hint: 'Enter mobile number',
            ),
            onChanged: (_) => onMobileChanged(),
          ),
        ),
        _iconField(
          icon: Icons.mail_outline,
          child: TextField(
            key: const Key('host-email'),
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: profileFieldDecoration(
              context,
              label: 'Email Address',
              hint: 'Enter email address',
            ),
            onChanged: (_) => onEmailChanged(),
          ),
        ),
      ],
    );
  }

  Widget _iconField({required IconData icon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Icon(icon, color: HomiziColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _verify() {
    return ListingIdentityStep(
      demoIdentity: demoIdentity,
      mobileVerified: mobileVerified,
      emailVerified: emailVerified,
      aadhaarVerified: aadhaarVerified,
      selfieVerified: selfieVerified,
      reused:
          mobileVerified && emailVerified && aadhaarVerified && selfieVerified,
      mobileOtpSent: mobileOtpSent,
      emailOtpSent: emailOtpSent,
      aadhaarOtpSent: aadhaarOtpSent,
      mobileOtp: mobileOtp,
      emailOtp: emailOtp,
      aadhaar: aadhaar,
      aadhaarOtp: aadhaarOtp,
      aadhaarFormatters: aadhaarFormatters,
      onSendMobile: onSendMobile,
      onVerifyMobile: onVerifyMobile,
      onSendEmail: onSendEmail,
      onVerifyEmail: onVerifyEmail,
      onSendAadhaar: onSendAadhaar,
      onVerifyAadhaar: onVerifyAadhaar,
      onSamplePhoto: onSamplePhoto,
      onLiveness: onLiveness,
      sampleReady: sampleReady,
      onOpenDigio: onOpenDigio,
      showPhoto: showPhoto,
      onShowPhoto: onShowPhoto,
      onSelfieCamera: onSelfieCamera,
      onSelfieUpload: onSelfieUpload,
      onVerifyLater: onVerifyLater,
      selfieNote: selfieNote,
    );
  }

  Widget _additional(BuildContext context) {
    return Column(
      children: [
        _fold(
          context,
          icon: Icons.notes_outlined,
          title: 'Short Biography / Landlord Note',
          detail: 'Tell something about yourself or your property',
          child: TextField(
            key: const Key('host-bio'),
            controller: bio,
            minLines: 2,
            maxLines: 4,
            maxLength: 280,
            decoration: profileFieldDecoration(
              context,
              label: 'Short biography',
            ),
          ),
        ),
        _fold(
          context,
          icon: Icons.schedule_outlined,
          title: 'Response Time Expectation',
          detail: 'e.g. Replies within 24 hours',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in hostResponseTimes)
                FilterChip(
                  key: Key('host-response-$option'),
                  label: Text(homiziText(context, option)),
                  selected: responseTime == option,
                  onSelected: (selected) =>
                      onResponse(selected ? option : null),
                ),
            ],
          ),
        ),
        _fold(
          context,
          icon: Icons.groups_outlined,
          title: 'Preferred Tenant Types',
          detail: 'Working Professional / Student / Actor / Any',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in hostPreferredTenantTypes)
                FilterChip(
                  key: Key('host-pref-$option'),
                  label: Text(homiziText(context, option)),
                  selected: preferred.contains(option),
                  onSelected: (selected) => onPreferred(option, selected),
                ),
            ],
          ),
        ),
        _fold(
          context,
          icon: Icons.apartment,
          title: 'Business Details (If Company)',
          detail: 'Company name, Registration number (Optional)',
          child: showCompany
              ? Column(
                  children: [
                    TextField(
                      key: const Key('host-company-name'),
                      controller: company,
                      textCapitalization: TextCapitalization.words,
                      decoration: profileFieldDecoration(
                        context,
                        label: 'Company name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('host-registration'),
                      controller: registration,
                      decoration: profileFieldDecoration(
                        context,
                        label: 'Registration number',
                      ),
                    ),
                  ],
                )
              : Text(
                  homiziText(
                    context,
                    'Shown when you also choose Company / Property Management.',
                  ),
                ),
        ),
        _fold(
          context,
          icon: Icons.workspace_premium_outlined,
          title: 'Subscription Plan',
          detail: 'Free / Premium (Paid Badge)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final item in HostPlan.values)
                    ChoiceChip(
                      key: Key('host-plan-${item.wire}'),
                      label: Text(homiziText(context, item.label)),
                      selected: plan == item,
                      onSelected: (_) => onPlan(item),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Premium is a badge in this demo. No payment is taken.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fold(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        elevation: 1,
        shadowColor: HomiziColors.shadow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: HomiziColors.clear),
          child: ExpansionTile(
            leading: Icon(icon, color: HomiziColors.accent),
            title: Text(
              homiziText(context, title),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              homiziText(context, detail),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: HomiziColors.muted,
                fontSize: 12,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [child],
          ),
        ),
      ),
    );
  }

  Widget _trust(BuildContext context) {
    final privacy = hostOnboardingPrivacy(host: host, profile: profile);
    final kinds = authorizationKindsFor(host.roles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _personCard(
          context,
          name: privacy.publicName,
          role: host.roles.isEmpty ? null : host.roles.first,
          place: null,
          asset: null,
          verified: profile.mobileVerified && profile.emailVerified,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _panel(
                context,
                title: 'Identity Verification',
                titleKey: const Key('host-trust-identity'),
                children: [
                  _trustLine(
                    context,
                    'Mobile Verified',
                    profile.mobileVerified,
                  ),
                  _trustLine(context, 'Email Verified', profile.emailVerified),
                  _trustLine(
                    context,
                    'Aadhaar Verified',
                    profile.aadhaarVerified,
                    iconKey: const Key('host-identity-aadhaar'),
                  ),
                  _trustLine(
                    context,
                    'Selfie Verified',
                    profile.selfieVerified,
                    iconKey: const Key('host-identity-selfie'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _panel(
                context,
                title: 'Property Authorization',
                titleKey: const Key('host-trust-property'),
                children: [
                  for (final kind in kinds) _authLine(context, kind),
                  if (kinds.isEmpty)
                    Text(
                      homiziText(
                        context,
                        'Choose a category to add a document.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final role in host.roles) HostRoleChip(role: role)],
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
        const SizedBox(height: 12),
        Text(
          homiziText(context, 'Example'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: const Key('host-rohan-example'),
          decoration: flowCard(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _personCard(
                  context,
                  name: rohanTrustName,
                  role: HostRole.broker,
                  place: rohanTrustPlace,
                  asset: 'assets/avatars/avatar_02.webp',
                  verified: true,
                ),
                const SizedBox(height: 8),
                for (final entry in rohanPropertyExamples.entries)
                  Text(
                    homiziText(
                      context,
                      '${entry.key.label} · ${entry.value.label}',
                    ),
                    key: Key('host-example-auth-${entry.key.wire}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: flowCard(color: HomiziColors.warningWash),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: HomiziColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    homiziText(
                      context,
                      'A verified person is not automatically the owner of a property. Property authorization is checked separately to ensure transparency and trust.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _authLine(BuildContext context, PropertyAuthKind kind) {
    final status = authorizationStatus(host, kind);
    final color = switch (status) {
      PropertyAuthStatus.verified => HomiziColors.success,
      PropertyAuthStatus.underReview => HomiziColors.warning,
      PropertyAuthStatus.notSubmitted => HomiziColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(homiziText(context, kind.label)),
          Text(
            homiziText(context, status.label),
            key: Key('host-auth-status-${kind.wire}'),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (status != PropertyAuthStatus.verified)
            TextButton(
              key: Key('host-auth-submit-${kind.wire}'),
              onPressed: () => onSubmitAuth(kind),
              child: Text(homiziText(context, 'Submit for review')),
            ),
        ],
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required Key titleKey,
    required List<Widget> children,
  }) {
    return DecoratedBox(
      decoration: flowCard(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, title),
              key: titleKey,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _trustLine(
    BuildContext context,
    String label,
    bool done, {
    Key? iconKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            key: iconKey,
            size: 16,
            color: done ? HomiziColors.success : HomiziColors.muted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              homiziText(context, done ? label : '$label — not yet'),
              style: const TextStyle(fontSize: 12, color: HomiziColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personCard(
    BuildContext context, {
    required String name,
    required HostRole? role,
    required String? place,
    required String? asset,
    required bool verified,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: HomiziColors.mist,
          backgroundImage: asset == null ? null : AssetImage(asset),
          child: asset == null
              ? Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(color: HomiziColors.ink),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      homiziText(context, name),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: HomiziColors.success,
                    ),
                    Text(
                      homiziText(context, 'Verified'),
                      style: const TextStyle(
                        color: HomiziColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              if (role != null) HostRoleChip(role: role),
              if (place != null)
                Text(
                  homiziText(context, place),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: HomiziColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responsibility(BuildContext context) {
    const icons = <(IconData, Color)>[
      (Icons.check_circle, HomiziColors.success),
      (Icons.check_circle, HomiziColors.success),
      (Icons.check_circle, HomiziColors.success),
      (Icons.check_circle, HomiziColors.success),
      (Icons.info, HomiziColors.accent),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < hostResponsibilityRules.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icons[i].$1, color: icons[i].$2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(context, hostResponsibilityRules[i]),
                    key: Key('host-rule-$i'),
                  ),
                ),
              ],
            ),
          ),
        CheckboxListTile(
          key: const Key('host-responsibility-check'),
          contentPadding: EdgeInsets.zero,
          value: accepted,
          onChanged: (value) => onAccepted(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            homiziText(
              context,
              'I will list only genuine homes and follow these rules.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in const [
              'Trusted People',
              'Genuine Listings',
              'Safer Rentals',
            ])
              DecoratedBox(
                decoration: BoxDecoration(
                  color: HomiziColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    homiziText(context, label),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
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

class _HostIntro extends StatelessWidget {
  const _HostIntro();

  @override
  Widget build(BuildContext context) {
    const points = <(IconData, Color, String)>[
      (Icons.verified_user_outlined, HomiziColors.accent, 'Verified Users'),
      (
        Icons.groups_outlined,
        HomiziColors.success,
        'Find the Right Tenants or Roomies',
      ),
      (Icons.schedule_outlined, HomiziColors.accent, 'Save Time & Effort'),
      (
        Icons.currency_rupee,
        HomiziColors.success,
        'Safe & Transparent Process',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final point in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(point.$1, color: point.$2),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              homiziText(context, point.$3),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                                color: HomiziColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: Image.asset(
                'assets/avatars/avatar_04.webp',
                width: 120,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        const FlowBanner(
          lines: ['List Today', 'Find Great People', 'Live Better'],
        ),
      ],
    );
  }
}

class _HostConfirmed extends StatelessWidget {
  const _HostConfirmed();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('host-flow-confirm'),
      children: [
        Icon(Icons.check_circle, color: HomiziColors.success, size: 64),
        SizedBox(height: 12),
        Text(
          'Next, list the property in a few steps.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', color: HomiziColors.inkSoft),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final HostRole role;
  final (IconData, Color, Color) tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tone.$3 : HomiziColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('host-role-${role.wire}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? tone.$2 : HomiziColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tone.$1, color: tone.$2, size: 28),
                const SizedBox(height: 8),
                Text(
                  homiziText(context, role.title),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    homiziText(context, hostRoleDetails[role] ?? ''),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: HomiziColors.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryProfiles extends StatelessWidget {
  const _CategoryProfiles();

  static const _photos = <HostRole, String>{
    HostRole.owner: 'assets/avatars/avatar_04.webp',
    HostRole.broker: 'assets/avatars/avatar_01.webp',
    HostRole.roomie: 'assets/avatars/avatar_02.webp',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final example in hostCategoryExamples) ...[
          DecoratedBox(
            decoration: flowCard(),
            child: Padding(
              key: Key('host-example-${example.role.wire}'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  example.role == HostRole.company
                      ? const CircleAvatar(
                          backgroundColor: HomiziColors.mist,
                          child: Icon(Icons.apartment, color: HomiziColors.ink),
                        )
                      : CircleAvatar(
                          backgroundImage: AssetImage(_photos[example.role]!),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                homiziText(context, example.name),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w800,
                                  color: HomiziColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: HomiziColors.success,
                            ),
                          ],
                        ),
                        Text(
                          homiziText(context, example.line),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: HomiziColors.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HostRoleChip(role: example.role),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
