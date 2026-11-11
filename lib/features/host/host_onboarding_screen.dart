import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/host/host_onboarding_store.dart';
import 'package:homizi/features/profile_create/identity_provider.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/trust/host_trust_panels.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

/// Eight-step Become a Host flow. Verification reuses Create Your Profile.
class HostOnboardingScreen extends ConsumerStatefulWidget {
  const HostOnboardingScreen({super.key});

  @override
  ConsumerState<HostOnboardingScreen> createState() =>
      _HostOnboardingScreenState();
}

class _HostOnboardingScreenState extends ConsumerState<HostOnboardingScreen> {
  final _scroll = ScrollController();
  final _full = TextEditingController();
  final _nickname = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _mobileOtp = TextEditingController();
  final _emailOtp = TextEditingController();
  final _aadhaar = TextEditingController();
  final _aadhaarOtp = TextEditingController();
  final _bio = TextEditingController();
  final _company = TextEditingController();
  final _registration = TextEditingController();
  late final TextInputFormatter _aadhaarFormatter = _AadhaarFormatter(this);

  var _step = 0;
  var _saving = false;
  var _roles = <HostRole>{};
  var _agreement = false;
  var _addingRole = false;
  String? _gender;
  var _mobileOtpSent = false;
  var _mobileVerified = false;
  var _emailOtpSent = false;
  var _emailVerified = false;
  var _aadhaarDigits = '';
  var _aadhaarOtpSent = false;
  var _aadhaarVerified = false;
  var _selfieVerified = false;
  var _livenessPassed = false;
  var _showPhoto = false;
  String? _sampleAvatar;
  String? _responseTime;
  var _preferred = <String>{};
  var _plan = HostPlan.free;
  var _authorizations = <PropertyAuthKind, PropertyAuthStatus>{};
  var _accepted = false;
  String? _error;

  /// Staging and development use the demo face check. Production stays on Digio
  /// and never treats a typed code or a sample photo as a pass.
  bool get _demoIdentity =>
      identityProviderFor(ref.read(appConfigProvider)) is DemoAadhaarProvider;

  bool get _aadhaarAccepted => _demoIdentity && _aadhaarVerified;

  bool get _selfieAccepted =>
      _demoIdentity && _selfieVerified && _livenessPassed;

  bool get _identityDone => identityChecksComplete(
    mobileVerified: _mobileVerified,
    emailVerified: _emailVerified,
    aadhaarVerified: _aadhaarAccepted,
    selfieVerified: _selfieAccepted,
  );

  String? get _identityGate {
    if (_step != 3 || _identityDone) {
      return null;
    }
    final message = identityBlockMessage(
      mobileVerified: _mobileVerified,
      emailVerified: _emailVerified,
      aadhaarVerified: _aadhaarAccepted,
      selfieVerified: _selfieAccepted,
    );
    return message.isEmpty ? null : message;
  }

  @override
  void initState() {
    super.initState();
    final host = ref.read(hostOnboardingProvider);
    final saved = ref.read(profileCreateStoreProvider).draft;
    _roles = {...host.roles};
    _agreement = host.agreementPermitsShare;
    _gender = host.gender ?? saved.gender;
    _responseTime = host.responseTime;
    _preferred = {...host.preferredTypes};
    _plan = host.plan;
    _authorizations = Map.of(host.authorizations);
    _accepted = host.acceptedResponsibility;
    _company.text = host.companyName.isNotEmpty
        ? host.companyName
        : saved.companyName;
    _registration.text = host.registrationNo;
    _bio.text = host.bio;
    final savedName = [
      saved.firstName.trim(),
      saved.lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    _full.text = host.fullName.isNotEmpty ? host.fullName : savedName;
    _nickname.text = host.nickname.isNotEmpty ? host.nickname : saved.nickname;
    _mobile.text = host.mobile.isNotEmpty ? host.mobile : saved.mobile;
    _email.text = host.email.isNotEmpty ? host.email : saved.email;
    _mobileOtpSent = saved.mobileOtpSent;
    _mobileVerified = saved.mobileVerified;
    _emailOtpSent = saved.emailOtpSent;
    _emailVerified = saved.emailVerified;
    _aadhaarOtpSent = saved.aadhaarOtpSent;
    _aadhaarVerified = saved.aadhaarVerified;
    _selfieVerified = saved.selfieVerified;
    _livenessPassed = saved.livenessPassed;
    _showPhoto = saved.showPhotoToVerifiedUsers;
    _sampleAvatar = saved.sampleAvatar;
    if (saved.aadhaarVerified && saved.aadhaarLast4.length == 4) {
      _aadhaarDigits = saved.aadhaarLast4;
      _aadhaar.text = 'XXXX XXXX ${saved.aadhaarLast4}';
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _full.dispose();
    _nickname.dispose();
    _mobile.dispose();
    _email.dispose();
    _mobileOtp.dispose();
    _emailOtp.dispose();
    _aadhaar.dispose();
    _aadhaarOtp.dispose();
    _bio.dispose();
    _company.dispose();
    _registration.dispose();
    super.dispose();
  }

  HostOnboardingDraft _draft() {
    return HostOnboardingDraft(
      roles: _roles,
      agreementPermitsShare: _agreement,
      fullName: _full.text.trim(),
      nickname: _nickname.text.trim(),
      gender: _gender,
      mobile: _mobile.text.replaceAll(RegExp(r'\D'), ''),
      email: _email.text.trim(),
      bio: _bio.text.trim(),
      responseTime: _responseTime,
      preferredTypes: _preferred,
      companyName: _company.text.trim(),
      registrationNo: _registration.text.trim(),
      plan: _plan,
      authorizations: _authorizations,
      acceptedResponsibility: _accepted,
    );
  }

  ProfileCreateDraft _profileDraft() {
    final existing = ref.read(profileCreateStoreProvider).draft;
    final names = splitLegalName(_full.text);
    final last4 = _aadhaarDigits.length <= 4
        ? _aadhaarDigits
        : _aadhaarDigits.substring(_aadhaarDigits.length - 4);
    return ProfileCreateDraft(
      step: _identityDone ? 4 : existing.step,
      firstName: names.first,
      lastName: names.last,
      nickname: _nickname.text.trim(),
      age: existing.age,
      gender: _gender,
      companyName: _company.text.trim(),
      occupation: existing.occupation,
      mobile: _mobile.text.replaceAll(RegExp(r'\D'), ''),
      mobileOtpSent: _mobileOtpSent,
      mobileVerified: _mobileVerified,
      email: _email.text.trim(),
      emailOtpSent: _emailOtpSent,
      emailVerified: _emailVerified,
      aadhaarLast4: last4,
      aadhaarOtpSent: _aadhaarOtpSent,
      aadhaarVerified: _aadhaarVerified,
      selfieVerified: _selfieVerified,
      livenessPassed: _livenessPassed,
      showPhotoToVerifiedUsers: _showPhoto,
      sampleAvatar: _sampleAvatar,
    );
  }

  Future<void> _syncProfile() async {
    final next = _profileDraft();
    await ref.read(profileCreateStoreProvider).save(next);
    ref
        .read(ownVerificationProvider.notifier)
        .replace(publicProfileFromDraft(next));
  }

  void _back() {
    if (_step == 0) {
      HomiziBackButton.leave(context);
      return;
    }
    setState(() {
      _step -= 1;
      _error = null;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _continue() async {
    final draft = _draft();
    final issues = hostOnboardingErrors(
      draft: draft,
      step: _step,
      identityComplete: _identityDone,
      mobileVerified: _mobileVerified,
      emailVerified: _emailVerified,
      aadhaarVerified: _aadhaarAccepted,
      selfieVerified: _selfieAccepted,
    );
    if (issues.isNotEmpty) {
      setState(() => _error = issues.first);
      return;
    }
    ref.read(hostOnboardingProvider.notifier).replace(draft);
    if (_step >= 2) {
      await _syncProfile();
    }
    if (!mounted) {
      return;
    }
    if (_step >= hostOnboardingStepCount - 1) {
      await _finish(draft);
      return;
    }
    setState(() {
      _step += 1;
      _error = null;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _finish(HostOnboardingDraft draft) async {
    setState(() => _saving = true);
    await ref.read(hostOnboardingProvider.notifier).pushRemote(draft);
    final company = draft.includesCompany ? draft.companyName.trim() : '';
    try {
      await ref
          .read(accountGatewayProvider)
          .saveHostProfile(
            HostProfile(
              category: primaryHostCategory(draft.roles),
              companyName: company,
            ),
          );
    } on Object {
      if (!demoModeOn(ref)) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = 'Host profile was not saved.';
          });
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    openDemoSuccess(
      context,
      title: 'You are a host on Homizi',
      detail:
          'Your host profile is saved. Identity checks and property checks stay separate.',
    );
  }

  void _toggleRole(HostRole role) {
    setState(() {
      if (_roles.contains(role)) {
        _roles.remove(role);
        if (role == HostRole.roomie) {
          _agreement = false;
        }
      } else {
        _roles.add(role);
      }
      _error = null;
    });
  }

  void _sendMobile() {
    final error = validateIndianMobile(_mobile.text);
    setState(() {
      _error = error;
      if (error == null) {
        _mobileOtpSent = true;
      }
    });
  }

  void _verifyMobile() {
    final ok = profileOtpMatches(_mobileOtp.text);
    setState(() {
      _mobileVerified = ok;
      _error = ok ? null : 'That code does not match. The demo code is 000000.';
    });
    if (ok) {
      unawaited(_syncProfile());
    }
  }

  void _sendEmail() {
    final error = validateEmailAddress(_email.text);
    setState(() {
      _error = error;
      if (error == null) {
        _emailOtpSent = true;
      }
    });
  }

  void _verifyEmail() {
    final ok = profileOtpMatches(_emailOtp.text);
    setState(() {
      _emailVerified = ok;
      _error = ok ? null : 'That code does not match. The demo code is 000000.';
    });
    if (ok) {
      unawaited(_syncProfile());
    }
  }

  void _sendAadhaar() {
    final error = validateAadhaarDigits(_aadhaarDigits);
    setState(() {
      _error = error;
      if (error == null) {
        _aadhaarOtpSent = true;
      }
    });
  }

  Future<void> _verifyAadhaar() async {
    if (!_demoIdentity) {
      setState(() {
        _aadhaarVerified = false;
        _error = kycComingSoonCopy;
      });
      return;
    }
    final digitsError = validateAadhaarDigits(_aadhaarDigits);
    final provider = identityProviderFor(ref.read(appConfigProvider));
    final result = await provider.submitOtp(
      otp: _aadhaarOtp.text,
      digitsReady: digitsError == null,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _aadhaarVerified = result.verified;
      _error = result.verified ? null : result.message;
    });
    if (result.verified) {
      await _syncProfile();
    }
  }

  void _useSample() {
    if (!_demoIdentity) {
      return;
    }
    setState(() {
      _sampleAvatar = profileSampleAvatar;
      _livenessPassed = false;
      _selfieVerified = false;
      _error = null;
    });
  }

  Future<void> _confirmLiveness() async {
    if (!_demoIdentity) {
      setState(() {
        _livenessPassed = false;
        _selfieVerified = false;
        _error = kycFaceStepCopy;
      });
      return;
    }
    if (_sampleAvatar == null) {
      setState(() => _error = 'Capture a selfie or use the sample photo.');
      return;
    }
    final provider = identityProviderFor(ref.read(appConfigProvider));
    final result = await provider.confirmLiveness();
    if (!mounted) {
      return;
    }
    setState(() {
      _livenessPassed = result.verified;
      _selfieVerified = result.verified;
      _error = result.verified ? null : result.message;
    });
    if (result.verified) {
      await _syncProfile();
    }
  }

  void _submitAuth(PropertyAuthKind kind) {
    final next = submitAuthorization(_draft(), kind);
    setState(() {
      _authorizations = Map.of(next.authorizations);
      _error = null;
    });
    ref.read(hostOnboardingProvider.notifier).replace(next);
  }

  @override
  Widget build(BuildContext context) {
    final copy = hostOnboardingSteps[_step];
    final last = _step == hostOnboardingStepCount - 1;
    final identityGate = _identityGate;
    final notice = _error ?? identityGate;
    return Scaffold(
      key: const Key('host-onboarding-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: IconButton(
          key: const Key('host-onboard-back'),
          tooltip: homiziText(context, 'Back'),
          onPressed: _saving ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const ProfileCreateLogo(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    '${_step + 1}/$hostOnboardingStepCount',
                    key: const Key('host-onboard-step'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: HomiziColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    homiziText(context, copy.$1),
                    key: const Key('host-onboard-title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(homiziText(context, copy.$2)),
                  const SizedBox(height: 20),
                  _body(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notice != null) ...[
                    Text(
                      homiziText(context, notice),
                      key: const Key('host-onboard-error'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _ContinueButton(
                    label: last
                        ? 'Agree and finish'
                        : _step == 2
                        ? 'Save & Continue'
                        : 'Continue',
                    busy: _saving,
                    onPressed: _saving || identityGate != null
                        ? null
                        : () => unawaited(_continue()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_step) {
      0 => const _Intro(),
      1 => _categories(),
      2 => _profile(),
      3 => _verify(),
      4 => _additional(),
      5 => HostTrustRecord(
        host: _draft(),
        profile: _profileDraft(),
        onSubmit: _submitAuth,
      ),
      6 => const HostCategoryShowcase(),
      _ => _responsibility(),
    };
  }

  Widget _categories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in HostRole.values) ...[
          _RoleCard(
            role: role,
            selected: _roles.contains(role),
            onTap: () => _toggleRole(role),
          ),
          const SizedBox(height: 12),
        ],
        if (_roles.contains(HostRole.roomie))
          CheckboxListTile(
            key: const Key('host-agreement-permit'),
            contentPadding: EdgeInsets.zero,
            value: _agreement,
            onChanged: (value) => setState(() {
              _agreement = value ?? false;
              _error = null;
            }),
            title: Text(
              homiziText(
                context,
                'I confirm my rental agreement permits me to share this home.',
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        OutlinedButton.icon(
          key: const Key('host-add-role'),
          onPressed: _roles.length >= HostRole.values.length
              ? null
              : () => setState(() => _addingRole = true),
          icon: const Icon(Icons.add),
          label: Text(homiziText(context, 'Add another role')),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            _addingRole
                ? 'Choose one more category below. One account can hold more than one role.'
                : 'You can add more than one role in a single account. For example, you can be an Existing Tenant for one property and a Broker for another.',
          ),
        ),
      ],
    );
  }

  Widget _profile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('host-full-name'),
          controller: _full,
          textCapitalization: TextCapitalization.words,
          decoration: profileFieldDecoration(
            context,
            label: 'Full name',
            hint: 'For verification',
            helper: 'Private, never shown publicly',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('host-nickname'),
          controller: _nickname,
          textCapitalization: TextCapitalization.words,
          decoration: profileFieldDecoration(
            context,
            label: 'Nickname',
            hint: 'Public profile',
            helper: 'Shown on your public profile',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Gender (optional)'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in profileGenderOptions)
              FilterChip(
                key: Key('host-gender-$option'),
                label: Text(homiziText(context, option)),
                selected: _gender == option,
                onSelected: (selected) => setState(() {
                  _gender = selected ? option : null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('host-mobile'),
          controller: _mobile,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: profileFieldDecoration(
            context,
            label: 'Mobile number',
            prefix: '+91 ',
          ),
          onChanged: (_) {
            if (_mobileVerified) {
              setState(() => _mobileVerified = false);
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('host-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: profileFieldDecoration(context, label: 'Email address'),
          onChanged: (_) {
            if (_emailVerified) {
              setState(() => _emailVerified = false);
            }
          },
        ),
      ],
    );
  }

  Widget _verify() {
    final demo = _demoIdentity;
    final mobilePhase = contactCheckPhase(
      verified: _mobileVerified,
      otpSent: _mobileOtpSent,
    );
    final emailPhase = contactCheckPhase(
      verified: _emailVerified,
      otpSent: _emailOtpSent,
    );
    final aadhaarPhase = demo
        ? aadhaarCheckPhase(
            verified: _aadhaarAccepted,
            otpSent: _aadhaarOtpSent,
            digitCount: _aadhaarDigits.length,
          )
        : HostCheckPhase.pending;
    final selfiePhase = selfieCheckPhase(
      verified: _selfieAccepted,
      livenessPassed: demo && _livenessPassed,
      hasPhoto: demo && _sampleAvatar != null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_identityDone)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _IdentityNote(
              text: 'Using your Create Your Profile verification.',
              noteKey: Key('host-verification-reused'),
            ),
          ),
        _CheckTile(
          phase: mobilePhase,
          title: _mobileVerified ? 'Mobile Verified' : 'Mobile number',
          detail: _mobileVerified
              ? 'This number is confirmed.'
              : _mobileOtpSent
              ? 'Enter the code to finish this check.'
              : 'Send a code to the number on your profile.',
          iconKey: _mobileVerified ? const Key('host-mobile-check') : null,
          child: _mobileVerified
              ? null
              : _otpBlock(
                  sent: _mobileOtpSent,
                  sendKey: const Key('host-mobile-send'),
                  fieldKey: const Key('host-mobile-otp'),
                  verifyKey: const Key('host-mobile-verify'),
                  controller: _mobileOtp,
                  onSend: _sendMobile,
                  onVerify: _verifyMobile,
                  helper: demo ? 'Demo code 000000' : null,
                ),
        ),
        _CheckTile(
          phase: emailPhase,
          title: _emailVerified ? 'Email Verified' : 'Email address',
          detail: _emailVerified
              ? 'This email is confirmed.'
              : _emailOtpSent
              ? 'Enter the code to finish this check.'
              : 'Send a code to the email on your profile.',
          iconKey: _emailVerified ? const Key('host-email-check') : null,
          child: _emailVerified
              ? null
              : _otpBlock(
                  sent: _emailOtpSent,
                  sendKey: const Key('host-email-send'),
                  fieldKey: const Key('host-email-otp'),
                  verifyKey: const Key('host-email-verify'),
                  controller: _emailOtp,
                  onSend: _sendEmail,
                  onVerify: _verifyEmail,
                  helper: demo ? 'Demo code 000000' : null,
                ),
        ),
        _CheckTile(
          phase: aadhaarPhase,
          title: _aadhaarAccepted ? 'Aadhaar Verified' : 'Aadhaar number',
          detail: _aadhaarAccepted
              ? 'Only the last 4 digits are kept.'
              : demo
              ? 'Enter the number, then verify with the code.'
              : kycComingSoonCopy,
          iconKey: _aadhaarAccepted ? const Key('host-aadhaar-check') : null,
          child: !demo || _aadhaarAccepted ? null : _aadhaarFields(),
        ),
        _CheckTile(
          phase: selfiePhase,
          title: _selfieAccepted ? 'Selfie Verified' : 'Selfie',
          detail: _selfieAccepted
              ? 'The liveness check passed.'
              : demo
              ? _sampleAvatar == null
                    ? 'Add a photo, then blink once to confirm it is you.'
                    : 'Blink once, then confirm.'
              : kycFaceStepCopy,
          iconKey: _selfieAccepted ? const Key('host-liveness-check') : null,
          child: !demo || _selfieAccepted ? null : _selfieFields(),
        ),
        _photoToggle(),
      ],
    );
  }

  Widget _aadhaarFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          homiziText(
            context,
            'We use secure and government authorized verification.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('host-aadhaar'),
          controller: _aadhaar,
          keyboardType: TextInputType.number,
          inputFormatters: [_aadhaarFormatter],
          decoration: profileFieldDecoration(
            context,
            label: 'Aadhaar number',
            hint: 'XXXX XXXX 1234',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('host-aadhaar-send'),
            onPressed: _sendAadhaar,
            child: Text(homiziText(context, 'Send OTP')),
          ),
        ),
        if (_aadhaarOtpSent) ...[
          TextField(
            key: const Key('host-aadhaar-otp'),
            controller: _aadhaarOtp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: profileFieldDecoration(
              context,
              label: 'Demo verification',
              helper:
                  'Demo verification — Digio is not live. The code is 000000.',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('host-aadhaar-verify'),
              onPressed: () => unawaited(_verifyAadhaar()),
              child: Text(homiziText(context, 'Verify')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selfieFields() {
    final ready = _sampleAvatar != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _SelfieFrame(asset: _sampleAvatar)),
        const SizedBox(height: 12),
        if (!ready)
          OutlinedButton.icon(
            key: const Key('host-sample-photo'),
            onPressed: _useSample,
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.ink,
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: HomiziColors.accent, width: 2),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(homiziText(context, 'Use sample photo')),
          )
        else ...[
          Text(
            homiziText(context, 'Sample photo for this demo'),
            key: const Key('host-sample-ready'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('host-liveness'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.accent,
              foregroundColor: HomiziColors.ink,
              minimumSize: const Size(0, 48),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            onPressed: () => unawaited(_confirmLiveness()),
            child: Text(homiziText(context, 'I blinked')),
          ),
        ],
      ],
    );
  }

  Widget _photoToggle() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.soft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, 'Show my photo to verified users'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(
                        context,
                        'Off by default. Other people see your initials unless this is on and they are verified.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                key: const Key('host-photo-toggle'),
                value: _showPhoto,
                onChanged: (value) => setState(() => _showPhoto = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBlock({
    required bool sent,
    required Key sendKey,
    required Key fieldKey,
    required Key verifyKey,
    required TextEditingController controller,
    required VoidCallback onSend,
    required VoidCallback onVerify,
    required String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: sendKey,
            onPressed: onSend,
            child: Text(homiziText(context, 'Send OTP')),
          ),
        ),
        if (sent) ...[
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: profileFieldDecoration(
              context,
              label: 'OTP',
              helper: helper,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: verifyKey,
              onPressed: onVerify,
              child: Text(homiziText(context, 'Verify')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _additional() {
    final company = _roles.contains(HostRole.company);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('host-bio'),
          controller: _bio,
          minLines: 2,
          maxLines: 4,
          maxLength: 280,
          decoration: profileFieldDecoration(
            context,
            label: 'Short biography',
            hint: 'Tell something about yourself or your property',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Expected response time'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in hostResponseTimes)
              FilterChip(
                key: Key('host-response-$option'),
                label: Text(homiziText(context, option)),
                selected: _responseTime == option,
                onSelected: (selected) => setState(() {
                  _responseTime = selected ? option : null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Preferred tenant or flatmate'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in hostPreferredTenantTypes)
              FilterChip(
                key: Key('host-pref-$option'),
                label: Text(homiziText(context, option)),
                selected: _preferred.contains(option),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _preferred.add(option);
                  } else {
                    _preferred.remove(option);
                  }
                }),
              ),
          ],
        ),
        if (company) ...[
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Business details'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('host-company-name'),
            controller: _company,
            textCapitalization: TextCapitalization.words,
            decoration: profileFieldDecoration(context, label: 'Company name'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('host-registration'),
            controller: _registration,
            decoration: profileFieldDecoration(
              context,
              label: 'Registration number',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Subscription plan'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final plan in HostPlan.values)
              ChoiceChip(
                key: Key('host-plan-${plan.wire}'),
                label: Text(homiziText(context, plan.label)),
                selected: _plan == plan,
                onSelected: (_) => setState(() => _plan = plan),
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
    );
  }

  Widget _responsibility() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HostResponsibilityList(),
        CheckboxListTile(
          key: const Key('host-responsibility-check'),
          contentPadding: EdgeInsets.zero,
          value: _accepted,
          onChanged: (value) => setState(() {
            _accepted = value ?? false;
            _error = null;
          }),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            homiziText(
              context,
              'I will list only genuine homes and follow these rules.',
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityNote extends StatelessWidget {
  const _IdentityNote({required this.text, required this.noteKey});

  final String text;
  final Key noteKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          homiziText(context, text),
          key: noteKey,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.phase,
    required this.title,
    required this.detail,
    this.iconKey,
    this.child,
  });

  final HostCheckPhase phase;
  final String title;
  final String detail;
  final Key? iconKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final done = phase == HostCheckPhase.done;
    final icon = switch (phase) {
      HostCheckPhase.pending => Icons.radio_button_unchecked,
      HostCheckPhase.inProgress => Icons.timelapse,
      HostCheckPhase.done => Icons.check_circle,
    };
    final iconColor = switch (phase) {
      HostCheckPhase.pending => HomiziColors.muted,
      HostCheckPhase.inProgress => HomiziColors.accent,
      HostCheckPhase.done => HomiziColors.success,
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: done ? HomiziColors.successWash : HomiziColors.soft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, key: iconKey, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, title),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          homiziText(context, hostCheckPhaseLabel(phase)),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: done
                                ? HomiziColors.success
                                : HomiziColors.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(context, detail),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HomiziColors.inkSoft,
                ),
              ),
              if (child != null) ...[const SizedBox(height: 8), child!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfieFrame extends StatelessWidget {
  const _SelfieFrame({required this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    final photo = asset;
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomiziColors.white,
        border: Border.all(color: HomiziColors.accent, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? const Icon(Icons.person, size: 64, color: HomiziColors.muted)
          : Image.asset(
              photo,
              key: const Key('host-selfie-preview'),
              fit: BoxFit.cover,
              width: 132,
              height: 132,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person, size: 64, color: HomiziColors.muted),
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    const points = <(IconData, String)>[
      (Icons.verified_user_outlined, 'Verified Users'),
      (Icons.groups_outlined, 'Find the Right Tenants or Roomies'),
      (Icons.schedule_outlined, 'Save Time & Effort'),
      (Icons.shield_outlined, 'Safe & Transparent Process'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(point.$1, color: HomiziColors.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(homiziText(context, point.$2))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: HomiziColors.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'List today. Find great people. Live better.',
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final HostRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.accentWash : HomiziColors.white,
      elevation: selected ? 0 : 2,
      shadowColor: HomiziColors.shadowStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        key: Key('host-role-${role.wire}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, role.title),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(homiziText(context, hostRoleDetails[role] ?? '')),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: HomiziColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        key: const Key('host-onboard-continue'),
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.accent,
          foregroundColor: HomiziColors.ink,
          disabledBackgroundColor: HomiziColors.accentDisabled,
          disabledForegroundColor: HomiziColors.ink,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(homiziText(context, label)),
      ),
    );
  }
}

class _AadhaarFormatter extends TextInputFormatter {
  _AadhaarFormatter(this._host);

  final _HostOnboardingScreenState _host;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final edit = applyAadhaarEdit(
      digits: _host._aadhaarDigits,
      previousShown: oldValue.text,
      nextText: newValue.text,
    );
    if (edit.digits != _host._aadhaarDigits) {
      _host._aadhaarVerified = false;
    }
    _host._aadhaarDigits = edit.digits;
    return TextEditingValue(
      text: edit.shown,
      selection: TextSelection.collapsed(offset: edit.shown.length),
    );
  }
}
