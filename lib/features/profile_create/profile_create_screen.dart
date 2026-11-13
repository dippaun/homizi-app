import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

const _stepTitles = <String>[
  'Select Your Role',
  'Basic Information',
  'Language Known',
  'Verify Contact',
  'Aadhaar Verification',
  'Selfie Verification',
  'Choose Your Profile Photo',
  'Lifestyle & Preferences',
  'Terms & Completion',
];

const _stepDetails = <String>[
  'Choose one or more roles (Tenant, Owner/Host, Property Partner, Home-Sharer).',
  'Add Full Name (verification only), Nick Name + Surname (public), DOB (DD/MM/YYYY, year mandatory), Gender and Occupation.',
  'Select your preferred languages (e.g., Hindi, English, Marathi, Gujarati).',
  'Verify your mobile number and email with OTP.',
  'Verify your identity using Aadhaar with OTP.',
  'Capture a live selfie for identity verification (used only for verification and kept private).',
  'Choose a profile photo to appear on your public profile or use your verified selfie (optional).',
  'Share your living and lifestyle preferences to find better matches.',
  'Accept terms, privacy policy and consent. Your verified profile is ready.',
];

/// Nine-step Create Your Profile flow from the spec.
///
/// Aadhaar is the live Digio check. This screen never marks it verified.
class ProfileCreateScreen extends ConsumerStatefulWidget {
  const ProfileCreateScreen({super.key});

  @override
  ConsumerState<ProfileCreateScreen> createState() =>
      _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends ConsumerState<ProfileCreateScreen> {
  final _scroll = ScrollController();
  final _fullName = TextEditingController();
  final _nickname = TextEditingController();
  final _surname = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _mobileOtp = TextEditingController();
  final _emailOtp = TextEditingController();
  final _aadhaar = TextEditingController();
  late final TextInputFormatter _aadhaarFormatter = _AadhaarFormatter(this);

  final _errors = <String, String>{};
  final _roles = <String>{};
  final _languages = <String>{};

  var _step = 0;
  var _showDone = false;
  var _saving = false;
  var _aadhaarBusy = false;
  var _returningToAction = false;
  String? _gender;
  String? _occupation;
  String? _smoking;
  String? _drinking;
  String? _food;
  String? _cooking;
  String? _cleaning;
  var _mobileOtpSent = false;
  var _mobileVerified = false;
  var _emailOtpSent = false;
  var _emailVerified = false;
  var _aadhaarDigits = '';
  var _aadhaarVerified = false;
  var _aadhaarLast4 = '';
  var _aadhaarUnavailable = false;
  var _selfieVerified = false;
  var _showPhoto = false;
  String? _sampleAvatar;
  String? _cameraError;
  var _terms = false;
  var _privacy = false;
  var _consent = false;
  String _about = '';
  String _city = '';
  String _company = '';
  var _tags = const <String>[];
  var _documents = const <String>[];
  int? _budgetMin;
  int? _budgetMax;
  var _localities = const <String>[];
  var _lookingFor = const <String>[];
  String _moveIn = '';
  String? _pets;

  @override
  void initState() {
    super.initState();
    _apply(ref.read(profileCreateStoreProvider).draft);
  }

  void _apply(ProfileCreateDraft saved) {
    _step = saved.step.clamp(0, profileStepTerms);
    _showDone =
        saved.step >= profileStepTerms &&
        saved.termsComplete &&
        saved.mobileVerified &&
        saved.selfieVerified;
    final legal = [
      saved.firstName.trim(),
      saved.lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    _fullName.text = legal;
    _nickname.text = saved.nickname;
    _surname.text = saved.surname;
    _day.text = saved.birthDay == null ? '' : '${saved.birthDay}';
    _month.text = saved.birthMonth == null ? '' : '${saved.birthMonth}';
    _year.text = saved.birthYear == null ? '' : '${saved.birthYear}';
    _gender = saved.gender;
    _occupation = saved.occupation;
    _mobile.text = saved.mobile;
    _mobileOtpSent = saved.mobileOtpSent;
    _mobileVerified = saved.mobileVerified;
    _email.text = saved.email;
    _emailOtpSent = saved.emailOtpSent;
    _emailVerified = saved.emailVerified;
    _aadhaarVerified = saved.aadhaarVerified;
    _aadhaarLast4 = saved.aadhaarLast4;
    if (saved.aadhaarVerified && saved.aadhaarLast4.length == 4) {
      _aadhaar.text = 'XXXX XXXX ${saved.aadhaarLast4}';
      _aadhaarDigits = saved.aadhaarLast4;
    }
    _selfieVerified = saved.selfieVerified;
    _showPhoto = saved.showPhotoToVerifiedUsers;
    _sampleAvatar = saved.sampleAvatar;
    _roles
      ..clear()
      ..addAll(saved.roles);
    _languages
      ..clear()
      ..addAll(saved.languages);
    _smoking = saved.smoking;
    _drinking = saved.drinking;
    _food = saved.food;
    _cooking = saved.cooking;
    _cleaning = saved.cleaning;
    _pets = saved.pets;
    _terms = saved.termsAccepted;
    _privacy = saved.privacyAccepted;
    _consent = saved.consentAccepted;
    _about = saved.about;
    _city = saved.city;
    _company = saved.companyName;
    _tags = saved.tags;
    _documents = saved.documents;
    _budgetMin = saved.budgetMin;
    _budgetMax = saved.budgetMax;
    _localities = saved.localities;
    _lookingFor = saved.lookingFor;
    _moveIn = saved.moveInLabel;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fullName.dispose();
    _nickname.dispose();
    _surname.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _mobile.dispose();
    _email.dispose();
    _mobileOtp.dispose();
    _emailOtp.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  int? _parsePart(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null) {
      return null;
    }
    return value;
  }

  ProfileCreateDraft _draft() {
    final legal = splitProfileLegalName(_fullName.text);
    return ProfileCreateDraft(
      step: _step,
      firstName: legal.$1,
      lastName: legal.$2,
      nickname: _nickname.text.trim(),
      surname: _surname.text.trim(),
      age: profileDraftAge(
        ProfileCreateDraft(birthYear: _parsePart(_year.text)),
      ),
      birthDay: _parsePart(_day.text),
      birthMonth: _parsePart(_month.text),
      birthYear: _parsePart(_year.text),
      gender: _gender,
      companyName: _company,
      occupation: _occupation,
      mobile: _mobile.text.replaceAll(RegExp(r'\D'), ''),
      mobileOtpSent: _mobileOtpSent,
      mobileVerified: _mobileVerified,
      email: _email.text.trim(),
      emailOtpSent: _emailOtpSent,
      emailVerified: _emailVerified,
      aadhaarLast4: _aadhaarVerified ? _aadhaarLast4 : '',
      aadhaarVerified: _aadhaarVerified,
      selfieVerified: _selfieVerified,
      livenessPassed: _selfieVerified,
      showPhotoToVerifiedUsers: _showPhoto,
      sampleAvatar: _showPhoto ? _sampleAvatar : null,
      roles: _roles.toList(),
      languages: _languages.toList(),
      smoking: _smoking,
      drinking: _drinking,
      food: _food,
      cooking: _cooking,
      cleaning: _cleaning,
      pets: _pets,
      termsAccepted: _terms,
      privacyAccepted: _privacy,
      consentAccepted: _consent,
      about: _about,
      city: _city,
      tags: _tags,
      documents: _documents,
      budgetMin: _budgetMin,
      budgetMax: _budgetMax,
      localities: _localities,
      lookingFor: _lookingFor,
      moveInLabel: _moveIn,
    );
  }

  Future<void> _persist() async {
    await ref.read(profileCreateStoreProvider).save(_draft());
  }

  void _put(String key, String? message) {
    if (message == null) {
      _errors.remove(key);
    } else {
      _errors[key] = message;
    }
  }

  Future<void> _alert(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('profile-create-alert'),
          backgroundColor: HomiziColors.white,
          title: Text(homiziText(context, title)),
          content: Text(homiziText(context, message)),
          actions: [
            TextButton(
              key: const Key('profile-create-alert-ok'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(homiziText(context, 'OK')),
            ),
          ],
        );
      },
    );
  }

  String? _firstError() {
    for (final value in _errors.values) {
      return value;
    }
    return null;
  }

  bool _validate() {
    _errors.clear();
    if (_step == profileStepRole) {
      _put('roles', validateWizardRoles(_roles.toList()));
    } else if (_step == profileStepBasic) {
      _put('fullName', validateFullName(_fullName.text));
      _put(
        'nickname',
        validatePersonName(_nickname.text, 'Enter a nick name.'),
      );
      _put('surname', validatePersonName(_surname.text, 'Enter a surname.'));
      _put(
        'dob',
        validateDateOfBirth(
          day: _parsePart(_day.text),
          month: _parsePart(_month.text),
          year: _parsePart(_year.text),
        ),
      );
      _put('gender', _gender == null ? 'Choose a gender.' : null);
      _put('occupation', validateOccupation(_occupation));
    } else if (_step == profileStepLanguage) {
      _put(
        'languages',
        _languages.isEmpty ? 'Select your preferred languages.' : null,
      );
    } else if (_step == profileStepContact) {
      _put('mobile', validateIndianMobile(_mobile.text));
      _put('email', validateEmailAddress(_email.text));
      _put('mobileOtp', _mobileVerified ? null : 'Verify your mobile number.');
      _put('emailOtp', _emailVerified ? null : 'Verify your email address.');
    } else if (_step == profileStepSelfie) {
      _put(
        'selfie',
        _selfieVerified
            ? null
            : 'Capture a live selfie for identity verification.',
      );
    } else if (_step == profileStepLifestyle && _draft().needsLifestyle) {
      _put('smoking', _choice(_smoking, profileSmokingOptions, 'smoking'));
      _put('drinking', _choice(_drinking, profileDrinkingOptions, 'drinking'));
      _put('food', _choice(_food, profileFoodOptions, 'food preference'));
      _put('cooking', _choice(_cooking, profileCookingOptions, 'cooking'));
      _put('cleaning', _choice(_cleaning, profileCleaningOptions, 'cleaning'));
    } else if (_step == profileStepTerms && !_showDone) {
      if (!_terms || !_privacy || !_consent) {
        _put('terms', 'Accept terms, privacy policy and consent.');
      }
    }
    return _errors.isEmpty;
  }

  String? _choice(String? value, List<String> options, String label) {
    if (value == null || !options.contains(value)) {
      return 'Choose your $label.';
    }
    return null;
  }

  Future<void> _continue() async {
    if (_showDone) {
      await _explore();
      return;
    }
    if (_step == profileStepAadhaar &&
        !_aadhaarVerified &&
        !_aadhaarUnavailable) {
      await _runAadhaar();
      return;
    }
    final ok = _validate();
    final message = _firstError();
    setState(() {});
    if (!ok || _saving) {
      if (message != null && mounted) {
        await _alert(_stepTitles[_step], message);
      }
      return;
    }
    if (_step == profileStepTerms) {
      setState(() {
        _terms = true;
        _privacy = true;
        _consent = true;
        _showDone = true;
        _saving = true;
      });
      await _persist();
      if (mounted) {
        setState(() => _saving = false);
      }
      return;
    }
    setState(() {
      _step += 1;
      _errors.clear();
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _saving = true);
    await _persist();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  void _publishVerification() {
    ref
        .read(ownVerificationProvider.notifier)
        .replace(publicProfileFromDraft(_draft()));
  }

  void _dropPendingAction() {
    if (_returningToAction) {
      return;
    }
    final notifier = ref.read(pendingVerifiedActionProvider.notifier);
    unawaited(Future<void>(() => notifier.take()));
  }

  Future<void> _explore() async {
    setState(() => _saving = true);
    await _persist();
    if (!mounted) {
      return;
    }
    final wire = profilePrimaryWire(_draft());
    if (wire != null) {
      await ref.read(sessionProvider.notifier).selectPrimaryRole(wire);
    }
    if (!mounted) {
      return;
    }
    _publishVerification();
    final pending = ref.read(pendingVerifiedActionProvider.notifier).take();
    setState(() => _saving = false);
    if (pending != null) {
      _returningToAction = true;
      final router = GoRouter.maybeOf(context);
      if (router != null && router.canPop()) {
        router.pop();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await pending();
      return;
    }
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Profile ready',
        detail: 'Your profile is verified and ready to use Homizi.',
      );
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(RoutePaths.profileMe);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _back() {
    if (_showDone) {
      setState(() => _showDone = false);
      return;
    }
    if (_step == 0) {
      _dropPendingAction();
      HomiziBackButton.leave(context);
      return;
    }
    setState(() {
      _step -= 1;
      _errors.clear();
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _restart() async {
    setState(() {
      _step = 0;
      _showDone = false;
      _gender = null;
      _occupation = null;
      _smoking = null;
      _drinking = null;
      _food = null;
      _cooking = null;
      _cleaning = null;
      _pets = null;
      _roles.clear();
      _languages.clear();
      _mobileOtpSent = false;
      _mobileVerified = false;
      _emailOtpSent = false;
      _emailVerified = false;
      _aadhaarDigits = '';
      _aadhaarVerified = false;
      _aadhaarLast4 = '';
      _aadhaarUnavailable = false;
      _selfieVerified = false;
      _showPhoto = false;
      _sampleAvatar = null;
      _cameraError = null;
      _terms = false;
      _privacy = false;
      _consent = false;
      _errors.clear();
      _fullName.clear();
      _nickname.clear();
      _surname.clear();
      _day.clear();
      _month.clear();
      _year.clear();
      _mobile.clear();
      _email.clear();
      _mobileOtp.clear();
      _emailOtp.clear();
      _aadhaar.clear();
    });
    ref.read(profileMediaProvider.notifier).clear();
    await _persist();
  }

  bool get _devCode => ref.read(appConfigProvider).allowsDevOtp;

  void _sendMobile() {
    final error = validateIndianMobile(_mobile.text);
    setState(() {
      _put('mobile', error);
      _mobileOtpSent = error == null;
      if (!_devCode && error == null) {
        _put('mobileOtp', 'Phone SMS is not connected. No code was sent.');
        _mobileOtpSent = false;
      }
    });
  }

  void _sendEmail() {
    final error = validateEmailAddress(_email.text);
    setState(() {
      _put('email', error);
      _emailOtpSent = error == null;
    });
    if (error != null || _devCode) {
      return;
    }
    unawaited(_sendHostedEmail());
  }

  Future<void> _sendHostedEmail() async {
    try {
      await ref
          .read(accountGatewayProvider)
          .requestEmailOtp(email: _email.text.trim());
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailOtpSent = false;
        _put('email', error.message);
      });
    }
  }

  void _verifyMobile() {
    if (!_devCode) {
      setState(() {
        _mobileVerified = false;
        _put('mobileOtp', 'Phone SMS is not connected. No code was sent.');
      });
      return;
    }
    final ok = profileOtpMatches(_mobileOtp.text);
    setState(() {
      _mobileVerified = ok;
      _put(
        'mobileOtp',
        ok
            ? null
            : 'That code does not match. The code is ${AppConfig.devOtp}.',
      );
    });
  }

  Future<void> _verifyEmail() async {
    if (_devCode) {
      final ok = profileOtpMatches(_emailOtp.text);
      setState(() {
        _emailVerified = ok;
        _put(
          'emailOtp',
          ok
              ? null
              : 'That code does not match. The code is ${AppConfig.devOtp}.',
        );
      });
      return;
    }
    try {
      await ref
          .read(accountGatewayProvider)
          .verifyEmailOtp(
            email: _email.text.trim(),
            code: _emailOtp.text.trim(),
            policyVersion:
                ref.read(sessionProvider).policyVersion ??
                ref.read(appConfigProvider).policyVersion,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _emailVerified = true;
        _put('emailOtp', null);
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailVerified = false;
        _put('emailOtp', error.message);
      });
    }
  }

  /// Asks Digio. A missing configuration stays unverified.
  Future<void> _runAadhaar() async {
    setState(() => _aadhaarBusy = true);
    try {
      final gateway = ref.read(kycGatewayProvider);
      final current = await gateway.current();
      if (current.aadhaarVerified) {
        _acceptAadhaar(current);
        return;
      }
      try {
        await gateway.giveConsent(KycDocumentKind.aadhaarOffline);
      } on KycFailure {
        // Consent may already be on the account.
      }
      final started = await gateway.start(KycDocumentKind.aadhaarOffline);
      if (!mounted) {
        return;
      }
      if (started.aadhaarVerified) {
        _acceptAadhaar(started);
        return;
      }
      final gatewayUrl = started.gatewayUrl;
      if (gatewayUrl != null) {
        final uri = kycGatewayUri(gatewayUrl, returnUrl: kycReturnUrl());
        if (uri != null) {
          await ref.read(kycLauncherProvider).open(uri);
        }
        final again = await gateway.current();
        if (!mounted) {
          return;
        }
        if (again.aadhaarVerified) {
          _acceptAadhaar(again);
          return;
        }
      }
      setState(() {
        _aadhaarVerified = false;
        _aadhaarUnavailable = true;
        _aadhaarLast4 = '';
        _aadhaarBusy = false;
      });
      await _alert('Aadhaar Verification', kycComingSoonCopy);
    } on KycFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _aadhaarVerified = false;
        _aadhaarUnavailable = true;
        _aadhaarBusy = false;
      });
      await _alert('Aadhaar Verification', error.message);
    } finally {
      if (mounted && _aadhaarBusy) {
        setState(() => _aadhaarBusy = false);
      }
    }
  }

  void _acceptAadhaar(KycSnapshot snapshot) {
    setState(() {
      _aadhaarVerified = true;
      _aadhaarUnavailable = false;
      _aadhaarLast4 = snapshot.maskedLast4 ?? '';
      _aadhaarDigits = _aadhaarLast4;
      if (_aadhaarLast4.length == 4) {
        _aadhaar.text = 'XXXX XXXX $_aadhaarLast4';
      }
    });
  }

  Future<void> _captureSelfie() async {
    final bytes = await ref.read(profileImageSourceProvider).captureSelfie();
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _cameraError = 'The camera could not be opened.';
        _selfieVerified = false;
      });
      await _alert('Selfie Verification', 'The camera could not be opened.');
      return;
    }
    ref.read(profileMediaProvider.notifier).setSelfie(bytes);
    setState(() {
      _selfieVerified = true;
      _cameraError = null;
      _put('selfie', null);
    });
    await _persist();
  }

  Future<void> _uploadPhoto() async {
    final bytes = await ref.read(profileImageSourceProvider).pickProfilePhoto();
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      await _alert('Profile Photo', 'The photo library could not be opened.');
      return;
    }
    await _keepPublicPhoto(bytes);
  }

  Future<void> _useSelfie() async {
    final selfie = ref.read(profileMediaProvider).selfie;
    if (selfie == null) {
      await _alert('Profile Photo', 'Capture a live selfie first.');
      return;
    }
    ref.read(profileMediaProvider.notifier).useSelfieAsPhoto();
    await _keepPublicPhoto(selfie);
  }

  Future<void> _keepPublicPhoto(Uint8List bytes) async {
    String? stored;
    try {
      stored = await ref.read(accountGatewayProvider).saveProfilePhoto(bytes);
    } on Object {
      stored = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _showPhoto = true;
      _sampleAvatar = stored;
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final title = _showDone ? 'Profile Completed!' : _stepTitles[_step];
    final detail = _showDone
        ? 'Your profile is verified and ready to use Homizi.'
        : _stepDetails[_step];
    final media = ref.watch(profileMediaProvider);
    return RepaintBoundary(
      key: const Key('profile-create-shot'),
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _dropPendingAction();
          }
        },
        child: Scaffold(
          backgroundColor: HomiziColors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: HomiziColors.white,
            surfaceTintColor: HomiziColors.white,
            centerTitle: true,
            leading: IconButton(
              key: const Key('profile-create-back'),
              tooltip: homiziText(context, 'Back'),
              onPressed: _back,
              icon: const Icon(Icons.arrow_back),
            ),
            title: const ProfileCreateLogo(),
            actions: [
              PopupMenuButton<String>(
                key: const Key('profile-create-menu'),
                tooltip: homiziText(context, 'Menu'),
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'restart') {
                    unawaited(_restart());
                  } else if (value == 'exit') {
                    _dropPendingAction();
                    HomiziBackButton.leave(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'restart',
                    child: Text(homiziText(context, 'Start over')),
                  ),
                  PopupMenuItem(
                    value: 'exit',
                    child: Text(homiziText(context, 'Exit')),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(
                        homiziText(
                          context,
                          'Step 2: Create Your Profile & Verification',
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(context, 'Universal for All Users'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: HomiziColors.logoOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homiziText(
                          context,
                          'A one-time, verified profile for Tenants, Property Owners/Hosts, Property Partners and People Looking to Share a Home.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HomiziColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ProfileCreateProgress(step: _step),
                      const SizedBox(height: 20),
                      Text(
                        homiziText(context, title),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homiziText(context, detail),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: HomiziColors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_showDone ? 'done' : _step),
                          child: _showDone ? _doneBody() : _stepBody(media),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ProfileCreateButton(
                    label: _showDone ? 'Start Exploring' : 'Continue',
                    busy: _saving || _aadhaarBusy,
                    onPressed: () => unawaited(_continue()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(ProfileMediaState media) {
    return switch (_step) {
      profileStepRole => _roleStep(),
      profileStepBasic => _basicStep(),
      profileStepLanguage => _languageStep(),
      profileStepContact => _contactStep(),
      profileStepAadhaar => _aadhaarStep(),
      profileStepSelfie => _selfieStep(media),
      profileStepPhoto => _photoStep(media),
      profileStepLifestyle => _lifestyleStep(),
      _ => _termsStep(),
    };
  }

  Widget _roleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'I am a... (Select one or more)'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final role in profileWizardRoles) ...[
          _selectCard(
            key: Key('profile-role-${role.$1}'),
            title: role.$2,
            body: role.$3,
            selected: _roles.contains(role.$1),
            onTap: () => setState(() {
              if (!_roles.add(role.$1)) {
                _roles.remove(role.$1);
              }
            }),
          ),
          const SizedBox(height: 10),
        ],
        if (_errors['roles'] != null) _error(_errors['roles']!),
        const _InfoCard(
          title: 'User Roles on Homizi',
          lines: [
            'Tenant — Looking for a rental home.',
            'Property Owner / Host — Own a property and want to list it for rent.',
            'Property Partner — Real estate agent / property consultant.',
            'Home-Sharer — Already living in a property and looking for a co-resident to share it.',
          ],
        ),
      ],
    );
  }

  Widget _basicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile-create-full-name'),
          controller: _fullName,
          textCapitalization: TextCapitalization.words,
          decoration: profileFieldDecoration(
            context,
            label: 'Full Name',
            hint: 'Verification only, not shown on your public profile',
            error: _errors['fullName'],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Full Name — for verification & records only (not visible publicly)',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('profile-create-nickname'),
          controller: _nickname,
          textCapitalization: TextCapitalization.words,
          decoration: profileFieldDecoration(
            context,
            label: 'Nick Name',
            hint: 'Shown on your public profile',
            error: _errors['nickname'],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('profile-create-surname'),
          controller: _surname,
          textCapitalization: TextCapitalization.words,
          decoration: profileFieldDecoration(
            context,
            label: 'Surname',
            hint: 'Shown on your public profile',
            error: _errors['surname'],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(context, 'Date of Birth'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _dobField('DD', _day, 'profile-create-dob-day')),
            const SizedBox(width: 8),
            Expanded(
              child: _dobField('MM', _month, 'profile-create-dob-month'),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _dobField('YYYY', _year, 'profile-create-dob-year'),
            ),
          ],
        ),
        if (_errors['dob'] != null) _error(_errors['dob']!),
        const SizedBox(height: 4),
        Text(
          homiziText(context, 'DD / MM / YYYY (Year is mandatory)'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(context, 'Gender'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in profileWizardGenders)
              ChoiceChip(
                key: Key('profile-create-gender-${option.$2}'),
                label: Text(homiziText(context, option.$1)),
                selected: _gender == option.$2,
                onSelected: (_) => setState(() => _gender = option.$2),
              ),
          ],
        ),
        if (_errors['gender'] != null) _error(_errors['gender']!),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('profile-create-occupation'),
          initialValue: _occupation,
          decoration: profileFieldDecoration(
            context,
            label: 'Occupation',
            error: _errors['occupation'],
          ),
          items: [
            for (final option in profileOccupationOptions)
              DropdownMenuItem(
                value: option,
                child: Text(homiziText(context, _occupationLabel(option))),
              ),
          ],
          onChanged: (value) => setState(() => _occupation = value),
        ),
        const SizedBox(height: 16),
        const _InfoCard(
          title: 'Key Profile Fields',
          lines: [
            'Full Name — for verification & records only (not visible publicly)',
            'Nick Name + Surname — shown on your public profile',
            'Date of Birth — DD / MM / YYYY (Year is mandatory)',
            'Gender & Occupation',
            'Language Known — Hindi / English / Marathi / Gujarati / Others',
            'Mobile & Email — OTP verification',
            'Aadhaar Verification — secure & authorised',
            'Live Selfie — mandatory (private)',
            'Profile Photo — appear in public profile',
            'Terms, Privacy Policy & Consent — mandatory',
          ],
        ),
      ],
    );
  }

  Widget _dobField(String hint, TextEditingController controller, String key) {
    return TextField(
      key: Key(key),
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: profileFieldDecoration(context, label: hint),
    );
  }

  Widget _languageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Select all that apply'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in profileWizardLanguages)
              FilterChip(
                key: Key('profile-language-$language'),
                label: Text(homiziText(context, language)),
                selected: _languages.contains(language),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _languages.add(language);
                  } else {
                    _languages.remove(language);
                  }
                }),
              ),
          ],
        ),
        if (_errors['languages'] != null) _error(_errors['languages']!),
      ],
    );
  }

  Widget _contactStep() {
    final helper = _devCode ? 'Staging test code ${AppConfig.devOtp}' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _otpBlock(
          label: 'Mobile Number',
          fieldKey: 'profile-create-mobile',
          sendKey: 'profile-create-mobile-send',
          otpKey: 'profile-create-mobile-otp',
          verifyKey: 'profile-create-mobile-verify',
          checkKey: 'profile-create-mobile-check',
          controller: _mobile,
          otpController: _mobileOtp,
          sent: _mobileOtpSent,
          verified: _mobileVerified,
          error: _errors['mobile'],
          otpError: _errors['mobileOtp'],
          helper: helper,
          prefix: '+91 ',
          onSend: _sendMobile,
          onVerify: _verifyMobile,
        ),
        const SizedBox(height: 16),
        _otpBlock(
          label: 'Email Address',
          fieldKey: 'profile-create-email',
          sendKey: 'profile-create-email-send',
          otpKey: 'profile-create-email-otp',
          verifyKey: 'profile-create-email-verify',
          checkKey: 'profile-create-email-check',
          controller: _email,
          otpController: _emailOtp,
          sent: _emailOtpSent,
          verified: _emailVerified,
          error: _errors['email'],
          otpError: _errors['emailOtp'],
          helper: helper,
          onSend: _sendEmail,
          onVerify: () => unawaited(_verifyEmail()),
        ),
      ],
    );
  }

  Widget _otpBlock({
    required String label,
    required String fieldKey,
    required String sendKey,
    required String otpKey,
    required String verifyKey,
    required String checkKey,
    required TextEditingController controller,
    required TextEditingController otpController,
    required bool sent,
    required bool verified,
    required String? error,
    required String? otpError,
    required String? helper,
    required VoidCallback onSend,
    required VoidCallback onVerify,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key(fieldKey),
          controller: controller,
          keyboardType: prefix == null
              ? TextInputType.emailAddress
              : TextInputType.phone,
          decoration: profileFieldDecoration(
            context,
            label: label,
            error: error,
            prefix: prefix,
          ),
        ),
        const SizedBox(height: 8),
        if (verified)
          ProfileCheckLine(
            label: '$label verified',
            color: profileVerifiedGreen,
            iconKey: Key(checkKey),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key(sendKey),
              onPressed: onSend,
              child: Text(
                homiziText(context, sent ? 'Resend OTP' : 'Send OTP'),
              ),
            ),
          ),
          if (sent) ...[
            TextField(
              key: Key(otpKey),
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: profileFieldDecoration(
                context,
                label: 'OTP',
                error: otpError,
                helper: helper,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key(verifyKey),
                onPressed: onVerify,
                child: Text(homiziText(context, 'Verify OTP')),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _aadhaarStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile-create-aadhaar'),
          controller: _aadhaar,
          keyboardType: TextInputType.number,
          inputFormatters: [_aadhaarFormatter],
          decoration: profileFieldDecoration(
            context,
            label: 'Enter Aadhaar number',
            hint: 'XXXX XXXX 1234',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'We use secure and government authorised verification.',
          ),
        ),
        const SizedBox(height: 8),
        if (_aadhaarVerified)
          const ProfileCheckLine(
            label: 'Aadhaar verified',
            color: profileVerifiedGreen,
            iconKey: Key('profile-create-aadhaar-check'),
          )
        else ...[
          FilledButton(
            key: const Key('profile-create-aadhaar-verify'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.accent,
              foregroundColor: HomiziColors.ink,
            ),
            onPressed: _aadhaarBusy ? null : () => unawaited(_runAadhaar()),
            child: Text(homiziText(context, 'Verify with OTP')),
          ),
          if (_aadhaarUnavailable) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, kycComingSoonCopy),
              key: const Key('profile-aadhaar-unavailable'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, aadhaarStatusLabel(KycCheckState.notStarted)),
              key: const Key('profile-aadhaar-status'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _selfieStep(ProfileMediaState media) {
    final selfie = media.selfie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Selfie Verification (Mandatory)'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (selfie != null)
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Image.memory(
              selfie,
              key: const Key('profile-create-selfie-ready'),
              height: 180,
              width: 140,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            key: const Key('profile-create-selfie-empty'),
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomiziColors.mist,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: HomiziColors.line),
            ),
            child: const Icon(Icons.photo_camera_outlined, size: 48),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('profile-create-capture'),
          style: FilledButton.styleFrom(
            backgroundColor: HomiziColors.accent,
            foregroundColor: HomiziColors.ink,
          ),
          onPressed: () => unawaited(_captureSelfie()),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(
            homiziText(context, 'Use Camera to capture a live selfie'),
          ),
        ),
        if (_cameraError != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, _cameraError!),
            key: const Key('profile-selfie-error'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.error),
          ),
        ],
        if (_errors['selfie'] != null) _error(_errors['selfie']!),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            'This selfie is only for verification purposes and will not be visible to other users.',
          ),
        ),
        if (_selfieVerified) ...[
          const SizedBox(height: 8),
          const ProfileCheckLine(
            label: 'Selfie captured. This photo stays private.',
            color: profileVerifiedGreen,
            iconKey: Key('profile-create-liveness-check'),
          ),
        ],
        const SizedBox(height: 16),
        const _InfoCard(
          title: 'Profile Privacy & Control',
          lines: [
            'Verification selfie remains private and secure.',
            'You decide which information appears on your profile.',
            'Full name is never shown publicly.',
            'You can update your profile and preferences anytime.',
          ],
        ),
      ],
    );
  }

  Widget _photoStep(ProfileMediaState media) {
    final photo = media.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Appear in Profile'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 12),
        if (photo != null)
          ClipOval(
            child: Image.memory(
              photo,
              key: const Key('profile-create-photo-ready'),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('profile-create-upload'),
          onPressed: () => unawaited(_uploadPhoto()),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(homiziText(context, 'Add Photo / Upload Photo')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('profile-create-use-selfie'),
          onPressed: () => unawaited(_useSelfie()),
          icon: const Icon(Icons.face_retouching_natural_outlined),
          label: Text(homiziText(context, 'Use My Selfie as Profile Photo')),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'The verification selfie stays private unless you choose it as your profile photo.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
        ),
      ],
    );
  }

  Widget _lifestyleStep() {
    final needed = _draft().needsLifestyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'For Tenants & Home-Sharers'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.logoOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (!needed)
          const _InfoCard(
            title: 'Completion Note',
            lines: [
              'For Property Owner / Host / Property Partner: Profile setup is complete after verification.',
              'For Tenant & Home-Sharer: Continue to add more details like location, budget and housing preferences in the next step.',
            ],
          ),
        _choiceRow('Smoking', profileSmokingOptions, _smoking, (value) {
          setState(() => _smoking = value);
        }, 'smoking'),
        _choiceRow('Drinking', profileDrinkingOptions, _drinking, (value) {
          setState(() => _drinking = value);
        }, 'drinking'),
        _choiceRow('Food Preference', profileFoodOptions, _food, (value) {
          setState(() => _food = value);
        }, 'food'),
        _choiceRow('Cooking', profileCookingOptions, _cooking, (value) {
          setState(() => _cooking = value);
        }, 'cooking'),
        _choiceRow('Cleaning', profileCleaningOptions, _cleaning, (value) {
          setState(() => _cleaning = value);
        }, 'cleaning'),
        const SizedBox(height: 8),
        const _InfoCard(
          title: 'Lifestyle & Preferences',
          lines: [
            'Smoking — Yes / No / Occasional / Prefer not to say',
            'Drinking — Yes / No / Occasional / Prefer not to say',
            'Food Preference — Veg / Non-Veg / Both / Prefer not to say',
            'Cooking — Cook myself / Shared cooking / Prefer to hire a cook',
            'Cleaning — Myself / Shared cleaning / Prefer to hire a house help',
          ],
        ),
      ],
    );
  }

  Widget _choiceRow(
    String label,
    List<String> options,
    String? selected,
    ValueChanged<String> onChanged,
    String errorKey,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, label),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  key: Key('profile-$errorKey-$option'),
                  label: Text(homiziText(context, option)),
                  selected: selected == option,
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
          if (_errors[errorKey] != null) _error(_errors[errorKey]!),
        ],
      ),
    );
  }

  Widget _termsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          key: const Key('profile-terms'),
          value: _terms,
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'I agree to the Terms & Conditions')),
          onChanged: (value) => setState(() => _terms = value ?? false),
        ),
        CheckboxListTile(
          key: const Key('profile-privacy'),
          value: _privacy,
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'I accept the Privacy Policy')),
          onChanged: (value) => setState(() => _privacy = value ?? false),
        ),
        CheckboxListTile(
          key: const Key('profile-consent'),
          value: _consent,
          contentPadding: EdgeInsets.zero,
          title: Text(
            homiziText(
              context,
              'I give my consent for identity verification and data usage as per Homizi policy',
            ),
          ),
          onChanged: (value) => setState(() => _consent = value ?? false),
        ),
        if (_errors['terms'] != null) _error(_errors['terms']!),
        TextButton(
          onPressed: () => context.push(RoutePaths.terms),
          child: Text(homiziText(context, 'Read Terms & Conditions')),
        ),
        TextButton(
          onPressed: () => context.push(RoutePaths.privacy),
          child: Text(homiziText(context, 'Read Privacy Policy')),
        ),
        const _InfoCard(
          title: 'Completion Note',
          lines: [
            'For Property Owner / Host / Property Partner: Profile setup is complete after verification.',
            'For Tenant & Home-Sharer: Continue to add more details like location, budget and housing preferences in the next step.',
          ],
        ),
      ],
    );
  }

  Widget _doneBody() {
    final draft = _draft();
    final profile = publicProfileFromDraft(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: profileVerifiedGreen, size: 72),
        const SizedBox(height: 12),
        Text(
          homiziText(context, profile.publicName),
          key: const Key('profile-create-public-name'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (draft.mobileVerified)
          const ProfileCheckLine(
            label: 'Mobile Verified',
            color: profileVerifiedGreen,
          ),
        if (draft.emailVerified)
          const ProfileCheckLine(
            label: 'Email Verified',
            color: profileVerifiedGreen,
          ),
        if (draft.aadhaarVerified)
          const ProfileCheckLine(
            label: 'Aadhaar Verified',
            color: profileVerifiedGreen,
            iconKey: Key('profile-verified-aadhaar'),
          )
        else
          Text(
            homiziText(context, kycComingSoonCopy),
            key: const Key('profile-done-aadhaar-pending'),
          ),
        if (draft.selfieVerified)
          const ProfileCheckLine(
            label: 'Selfie Verified',
            color: profileVerifiedGreen,
            iconKey: Key('profile-verified-selfie'),
          ),
        const SizedBox(height: 8),
        const _InfoCard(
          title: 'Completion Note',
          lines: [
            'For Property Owner / Host / Property Partner: Profile setup is complete after verification.',
            'For Tenant & Home-Sharer: Continue to add more details like location, budget and housing preferences in the next step.',
          ],
        ),
      ],
    );
  }

  Widget _selectCard({
    required Key key,
    required String title,
    required String body,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? HomiziColors.accentWash : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(
          color: selected ? HomiziColors.logoOrange : HomiziColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: key,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? HomiziColors.logoOrange : HomiziColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(homiziText(context, body)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        homiziText(context, message),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: HomiziColors.error),
      ),
    );
  }
}

String _occupationLabel(String stored) {
  if (stored == 'Working professional') {
    return 'Working Professional';
  }
  return stored;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, title),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(homiziText(context, line)),
            ),
        ],
      ),
    );
  }
}

class _AadhaarFormatter extends TextInputFormatter {
  _AadhaarFormatter(this._host);

  final _ProfileCreateScreenState _host;

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
    _host._aadhaarDigits = edit.digits;
    return TextEditingValue(
      text: edit.shown,
      selection: TextSelection.collapsed(offset: edit.shown.length),
    );
  }
}
