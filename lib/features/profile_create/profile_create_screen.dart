import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/current_user_avatar.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/demo_login.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/auth/otp/phone_otp_channel.dart';
import 'package:homizi/features/auth/otp/whatsapp_style_icon.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/office/saved_office_field.dart';
import 'package:homizi/features/profile/occupation_picker.dart';
import 'package:homizi/features/profile/shared_answers.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/profile_email_auth.dart';
import 'package:homizi/features/profile_create/profile_email_otp.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/profile_create/profile_role_select.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/ui/kit/kit.dart';

const _stepTitles = <String>[
  'Select Your Role',
  'Basic Information',
  'Your office',
  'Language Known',
  'Verify Contact',
  'Aadhaar Verification',
  'Selfie Verification',
  'Choose Your Profile Photo',
  'Lifestyle & Preferences',
  'Budget and move-in',
  'House rules',
  'Your home',
  'Terms & Completion',
];

const _stepDetails = <String>[
  'Choose one or more roles (Tenant, Owner/Host, Property Partner, Home-Sharer).',
  'Name, date of birth, occupation, company, and the city you live in.',
  'Save the workplace commute uses. You can change it later from Profile.',
  'Select your preferred languages (e.g., Hindi, English, Marathi, Gujarati).',
  'Verify your mobile number and email with OTP.',
  'Verify your identity using Aadhaar with OTP.',
  'Capture a live selfie for identity verification (used only for verification and kept private).',
  'Choose a profile photo to appear on your public profile or use your verified selfie (optional).',
  'Smoking, drinking, food, cooking, cleaning, pets, sleep, guests, and work style.',
  'Monthly budget and when you want to move.',
  'What the home should allow. Skip any rule you do not mind.',
  'Listing a home comes after this. The same profile is used on the listing.',
  'Accept terms, privacy policy and consent. Your verified profile is ready.',
];

enum _EmailBusy { none, send, verify }

/// Nine-step Create Your Profile flow from the spec.
///
/// Aadhaar is the live Digio check. This screen never marks it verified.
class ProfileCreateScreen extends ConsumerStatefulWidget {
  const ProfileCreateScreen({this.registrationFinish = false, super.key});

  /// Post-login registration. Role was already chosen. Ends on "You're all set".
  final bool registrationFinish;

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
  final _companyField = TextEditingController();
  final _cityField = TextEditingController();
  final _budgetMinField = TextEditingController();
  final _budgetMaxField = TextEditingController();
  final _moveField = TextEditingController();
  late final TextInputFormatter _aadhaarFormatter = _AadhaarFormatter(this);

  final _errors = <String, String>{};
  final _roles = <String>{};
  final _languages = <String>{};

  var _step = 0;
  var _showDone = false;
  var _askRoommate = false;
  bool? _seekRoommate;
  var _reedit = false;
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
  var _mobileBusy = false;
  var _mobileResendRemaining = 0;
  PhoneOtpChannel _mobileChannel = PhoneOtpChannel.sms;
  Timer? _mobileResendTimer;
  var _emailOtpSent = false;
  var _emailVerified = false;
  var _emailKind = ProfileEmailOtpKind.localCode;
  var _emailBusy = _EmailBusy.none;
  var _emailAwaitingOther = false;
  var _emailResendSeconds = 0;
  var _emailNotice = '';
  var _emailCurrent = '';
  final _emailAttempts = OtpAttemptGate();
  Timer? _emailResendTimer;
  var _emailSnapshot = '';
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
    unawaited(_bootstrap());
    if (widget.registrationFinish && _step < profileStepBasic) {
      _step = profileStepBasic;
    }
    if (widget.registrationFinish) {
      _step = _advancePastFilled(_step);
    }
    if (widget.registrationFinish && _showDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_finishRegistration());
      });
    }
    _prefillAccountEmail();
    _emailSnapshot = _email.text.trim().toLowerCase();
    _email.addListener(_onEmailEdited);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileHostedEmail();
      _applySessionPhone();
      unawaited(_resumePendingAction());
    });
  }

  var _resumedPending = false;

  /// A finished profile opened from Verify now goes straight back to the
  /// message or interest that was waiting.
  Future<void> _resumePendingAction() async {
    if (!mounted || _resumedPending || !_showDone || _reedit) {
      return;
    }
    if (ref.read(pendingVerifiedActionProvider) == null) {
      return;
    }
    _resumedPending = true;
    await _explore();
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
    _companyField.text = saved.companyName;
    _cityField.text = saved.city;
    _budgetMinField.text = saved.budgetMin == null ? '' : '${saved.budgetMin}';
    _budgetMaxField.text = saved.budgetMax == null ? '' : '${saved.budgetMax}';
    _moveField.text = saved.moveInLabel;
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
    _email.removeListener(_onEmailEdited);
    _emailResendTimer?.cancel();
    _mobileResendTimer?.cancel();
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
    _companyField.dispose();
    _cityField.dispose();
    _budgetMinField.dispose();
    _budgetMaxField.dispose();
    _moveField.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final startedAt = _step;
    final store = ref.read(profileCreateStoreProvider);
    await store.restoreDevice();
    var draft = await store.hydrate(store.draft);
    draft = await adoptSharedAnswers(ref, draft);
    if (!mounted || _step != startedAt) {
      return;
    }
    setState(() {
      _apply(draft);
      if (widget.registrationFinish) {
        _step = _advancePastFilled(_step);
      }
    });
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
      companyName: _companyField.text.trim(),
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
      city: _cityField.text.trim(),
      tags: _tags,
      documents: _documents,
      budgetMin: int.tryParse(_budgetMinField.text.trim()) ?? _budgetMin,
      budgetMax: int.tryParse(_budgetMaxField.text.trim()) ?? _budgetMax,
      localities: _localities,
      lookingFor: _lookingFor,
      moveInLabel: _moveField.text.trim().isEmpty
          ? _moveIn
          : _moveField.text.trim(),
    );
  }

  Future<void> _persist() async {
    final next = _draft();
    await ref.read(profileCreateStoreProvider).save(next);
    await publishSharedAnswers(ref, next);
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
      _put(
        'city',
        _cityField.text.trim().length < 2 ? 'Enter your city.' : null,
      );
    } else if (_step == profileStepLanguage) {
      _put(
        'languages',
        _languages.isEmpty ? 'Select your preferred languages.' : null,
      );
    } else if (_step == profileStepContact) {
      if (ref.read(demoLoginActiveProvider)) {
        _mobileVerified = true;
        _emailVerified = true;
        _put('mobile', null);
        _put('email', null);
        _put('mobileOtp', null);
        _put('emailOtp', null);
      } else {
        _put('mobile', validateIndianMobile(_mobile.text));
        _put('email', validateEmailAddress(_email.text));
        _put(
          'mobileOtp',
          _mobileVerified ? null : 'Verify your mobile number.',
        );
        _put('emailOtp', _emailVerified ? null : 'Verify your email address.');
      }
    } else if (_step == profileStepSelfie) {
      if (ref.read(demoLoginActiveProvider)) {
        _selfieVerified = true;
      }
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
    if (ref.read(demoLoginActiveProvider)) {
      _aadhaarVerified = true;
      _aadhaarUnavailable = true;
      _selfieVerified = true;
      _mobileVerified = true;
      _emailVerified = true;
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
      if (_seekRoommate == null) {
        final draft = _draft();
        if (goalsPublishRoommate(draft.roles, draft.tags)) {
          await _answerRoommate(true);
          return;
        }
        setState(() => _askRoommate = true);
        return;
      }
      if (widget.registrationFinish) {
        setState(() => _saving = true);
        await _finishRegistration();
        return;
      }
      setState(() {
        _terms = true;
        _privacy = true;
        _consent = true;
        _showDone = true;
        _saving = true;
      });
      await _persist();
      if (!mounted) {
        return;
      }
      if (ref.read(pendingVerifiedActionProvider) != null) {
        _resumedPending = true;
        await _explore();
        return;
      }
      setState(() => _saving = false);
      return;
    }
    _markStepAnswered();
    setState(() {
      _step = _advancePastFilled(_step + 1);
      _errors.clear();
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _saving = true);
    try {
      await _persist();
    } on Object {
      // The draft is already in memory. The step still advances.
    }
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
    await _openRoleHome();
  }

  Future<void> _finishRegistration() async {
    _terms = true;
    _privacy = true;
    _consent = true;
    await _openRoleHome();
  }

  /// Writes the public name and role, then opens that role's Home.
  ///
  /// The role picker reads a missing name or role as "not finished". Both
  /// have to be on the server before navigation, and the in-memory gate must
  /// not keep the previous "still registering" answer.
  Future<void> _openRoleHome() async {
    await _persist();
    final name = profilePublicName(_draft());
    if (name.length >= 2) {
      try {
        final gateway = ref.read(accountGatewayProvider);
        final current = await gateway.loadTenantProfile();
        await gateway.saveTenantProfile(current.copyWith(displayName: name));
      } on Object {
        // The draft is already stored. The role write below still runs.
      }
    }
    final chosen = profilePrimaryWire(_draft());
    final existing = ref.read(sessionProvider).homiziWire;
    final wire = (chosen != null && chosen.isNotEmpty)
        ? chosen
        : (existing != null && existing.isNotEmpty)
        ? existing
        : 'tenant';
    if (isHomiziRoleWire(wire)) {
      await ref.read(sessionProvider.notifier).selectPrimaryRole(wire);
    }
    if (!mounted) {
      return;
    }
    ref.read(registrationBypassProvider.notifier).markDone();
    ref.read(registrationHomePassProvider.notifier).allow();
    ref.invalidate(registrationGateProvider);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(RoutePaths.home);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _back() {
    if (_showDone) {
      setState(() => _showDone = false);
      return;
    }
    if (widget.registrationFinish && _step <= profileStepBasic) {
      HomiziBackButton.leave(context);
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
      _mobileBusy = false;
      _mobileResendRemaining = 0;
      _mobileChannel = PhoneOtpChannel.sms;
      _mobileResendTimer?.cancel();
      _emailOtpSent = false;
      _emailVerified = false;
      _emailKind = ProfileEmailOtpKind.localCode;
      _emailBusy = _EmailBusy.none;
      _emailAwaitingOther = false;
      _emailResendSeconds = 0;
      _emailNotice = '';
      _emailCurrent = '';
      _emailAttempts.reset();
      _emailResendTimer?.cancel();
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

  bool get _hostedProfileEmail =>
      ref.read(appConfigProvider).usesHostedEmailOtp;

  void _prefillAccountEmail() {
    if (!_hostedProfileEmail || _email.text.trim().isNotEmpty) {
      return;
    }
    final contact = ref.read(sessionProvider).contact.trim();
    if (!contact.contains('@') ||
        contact.endsWith('@${AuthContact.syntheticDomain}')) {
      return;
    }
    _email.text = contact;
  }

  void _onEmailEdited() {
    final next = _email.text.trim().toLowerCase();
    if (next == _emailSnapshot) {
      return;
    }
    _emailSnapshot = next;
    final dirty =
        _emailOtpSent ||
        _emailVerified ||
        _emailAwaitingOther ||
        _emailResendSeconds > 0 ||
        _emailNotice.isNotEmpty;
    if (!dirty) {
      return;
    }
    _emailResendTimer?.cancel();
    _emailResendTimer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailOtpSent = false;
        _emailVerified = false;
        _emailAwaitingOther = false;
        _emailNotice = '';
        _emailResendSeconds = 0;
        _emailBusy = _EmailBusy.none;
        _emailAttempts.reset();
        _emailOtp.clear();
        _put('emailOtp', null);
      });
    });
  }

  void _reconcileHostedEmail() {
    if (!mounted || !_hostedProfileEmail) {
      return;
    }
    final kind = ref.read(profileEmailVerifierProvider).classify(_email.text);
    if (kind == ProfileEmailOtpKind.alreadyVerified) {
      setState(() {
        _emailVerified = true;
        _emailOtpSent = false;
        _emailNotice = '';
        _put('emailOtp', null);
      });
      return;
    }
    if (kind != ProfileEmailOtpKind.localCode && _emailVerified) {
      setState(() {
        _emailVerified = false;
        _emailOtpSent = false;
      });
    }
  }

  /// A staging test number already stored on the contact row counts as verified.
  void _applySessionPhone() {
    if (!mounted) {
      return;
    }
    final session = ref.read(sessionProvider);
    if (!session.phoneVerified) {
      return;
    }
    final national = indianMobileNational(session.phoneE164);
    if (national == null) {
      return;
    }
    final typed = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (typed.isNotEmpty && typed != national) {
      return;
    }
    if (_mobileVerified && typed == national) {
      return;
    }
    setState(() {
      if (typed.isEmpty) {
        _mobile.text = national;
      }
      _mobileVerified = true;
      _mobileOtpSent = false;
      _put('mobileOtp', null);
      if (_errors['mobile'] == phoneTrialUnverifiedMessage) {
        _put('mobile', null);
      }
    });
  }

  void _startEmailCooldown() {
    _emailResendTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _emailResendSeconds = resendCooldownSeconds);
    _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _emailResendSeconds -= 1;
        if (_emailResendSeconds <= 0) {
          _emailResendSeconds = 0;
          timer.cancel();
          _emailResendTimer = null;
        }
      });
    });
  }

  /// Staging and production with a project connected. Demo keeps the on-device
  /// code and does not call Auth.
  bool get _hostedPhone {
    final config = ref.read(appConfigProvider);
    return config.usesHostedPhoneOtp && !ref.read(forceDemoModeProvider);
  }

  void _startMobileCooldown() {
    _mobileResendTimer?.cancel();
    _mobileResendRemaining = phoneResendCooldownSeconds;
    _mobileResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_mobileResendRemaining <= 1) {
          _mobileResendRemaining = 0;
          timer.cancel();
          return;
        }
        _mobileResendRemaining -= 1;
      });
    });
  }

  Future<void> _sendMobile(PhoneOtpChannel channel) async {
    final error = validateIndianMobile(_mobile.text);
    if (error != null) {
      setState(() => _put('mobile', error));
      return;
    }
    if (_mobileResendRemaining > 0 || _mobileBusy) {
      return;
    }
    _mobileChannel = phoneDeliveryChannel(channel);
    if (!_hostedPhone) {
      setState(() {
        _mobileOtpSent = false;
        _put('mobile', phoneCodesUnavailableMessage);
        _put('mobileOtp', null);
      });
      return;
    }
    setState(() {
      _mobileBusy = true;
      _put('mobile', null);
      _put('mobileOtp', null);
    });
    final message = await ref
        .read(sessionProvider.notifier)
        .requestPhoneCode(_mobile.text, link: true, channel: channel);
    if (!mounted) {
      return;
    }
    final providerOn = ref.read(authProviderSettingsProvider).phone;
    final staged =
        ref.read(appConfigProvider).phoneTestCode(_mobile.text) != null;
    setState(() {
      _mobileBusy = false;
      if (message != null || (!providerOn && !staged)) {
        _mobileOtpSent = false;
        final shown = message ?? phoneCodesUnavailableMessage;
        _put(
          'mobile',
          channel == PhoneOtpChannel.whatsapp
              ? whatsappSendFailure(shown)
              : shown,
        );
        return;
      }
      _mobileOtpSent = true;
      _startMobileCooldown();
    });
  }

  void _sendEmail() {
    if (_emailBusy != _EmailBusy.none || _emailResendSeconds > 0) {
      return;
    }
    final error = validateEmailAddress(_email.text);
    if (error != null) {
      setState(() => _put('email', error));
      return;
    }
    if (!_hostedProfileEmail) {
      if (!ref.read(appConfigProvider).allowsDevOtp) {
        setState(() {
          _emailOtpSent = false;
          _put('email', productionDevOtpMessage);
        });
        return;
      }
      setState(() {
        _put('email', null);
        _put('emailOtp', null);
        _emailNotice = '';
        _emailKind = ProfileEmailOtpKind.localCode;
        _emailOtpSent = true;
        _emailVerified = false;
        _emailAwaitingOther = false;
        _emailAttempts.reset();
      });
      _startEmailCooldown();
      return;
    }
    setState(() {
      _emailBusy = _EmailBusy.send;
      _put('email', null);
    });
    unawaited(_sendHostedEmail());
  }

  Future<void> _sendHostedEmail() async {
    try {
      final send = await ref
          .read(profileEmailVerifierProvider)
          .request(_email.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _emailBusy = _EmailBusy.none;
        _emailKind = send.kind;
        _emailCurrent = send.currentEmail;
        _emailNotice = '';
        if (send.kind == ProfileEmailOtpKind.alreadyVerified) {
          _emailVerified = true;
          _emailOtpSent = false;
          _put('emailOtp', null);
          return;
        }
        _emailVerified = false;
        _emailOtpSent = true;
        _emailAwaitingOther = false;
        _emailAttempts.reset();
        _put('emailOtp', null);
      });
      if (send.kind != ProfileEmailOtpKind.alreadyVerified) {
        _startEmailCooldown();
      }
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailBusy = _EmailBusy.none;
        _emailOtpSent = false;
        _put('email', error.message);
      });
      if (error.message == emailSendRateLimitMessage) {
        _startEmailCooldown();
      }
    }
  }

  Future<void> _verifyMobile() async {
    if (!_hostedPhone) {
      setState(() {
        _mobileVerified = false;
        _put('mobileOtp', phoneCodesUnavailableMessage);
      });
      return;
    }
    if (_mobileOtp.text.trim() == AppConfig.devOtp) {
      setState(() => _put('mobileOtp', phoneDevCodeRefusedMessage));
      return;
    }
    if (!isSixDigitCode(_mobileOtp.text)) {
      setState(() => _put('mobileOtp', 'Enter the 6-digit code.'));
      return;
    }
    setState(() => _mobileBusy = true);
    final error = await ref
        .read(sessionProvider.notifier)
        .verifyPhoneCode(raw: _mobile.text, code: _mobileOtp.text, link: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _mobileBusy = false;
      _mobileVerified = error == null;
      _put('mobileOtp', error);
    });
  }

  Future<void> _verifyEmail() async {
    if (_emailBusy != _EmailBusy.none) {
      return;
    }
    final kind = _emailKind;
    if (kind == ProfileEmailOtpKind.localCode || !_hostedProfileEmail) {
      if (!ref.read(appConfigProvider).allowsDevOtp) {
        setState(() => _put('emailOtp', productionDevOtpMessage));
        return;
      }
      final ok = profileOtpMatches(_emailOtp.text);
      setState(() {
        _emailVerified = ok;
        _put('emailOtp', ok ? null : 'That code does not match.');
      });
      return;
    }
    final code = _emailOtp.text.trim();
    if (ref.read(appConfigProvider).environment == AppEnvironment.prod &&
        code == AppConfig.devOtp) {
      setState(() => _put('emailOtp', productionDevOtpMessage));
      return;
    }
    if (!isSixDigitCode(code)) {
      setState(() {
        _put('emailOtp', 'Enter the 6-digit code from the email.');
      });
      return;
    }
    if (_emailAttempts.blocked) {
      setState(() => _put('emailOtp', retryCapMessage));
      return;
    }
    setState(() => _emailBusy = _EmailBusy.verify);
    try {
      final check = await ref
          .read(profileEmailVerifierProvider)
          .confirm(
            email: _email.text.trim(),
            code: code,
            kind: kind,
            awaitingOther: _emailAwaitingOther,
            currentEmail: _emailCurrent,
            policyVersion:
                ref.read(sessionProvider).policyVersion ??
                ref.read(appConfigProvider).policyVersion,
          );
      if (!mounted) {
        return;
      }
      final snapshot = check.snapshot;
      if (check.verified && snapshot != null) {
        ref.read(sessionProvider.notifier).adoptVerifiedContact(snapshot);
      }
      setState(() {
        _emailBusy = _EmailBusy.none;
        if (check.verified) {
          _emailVerified = true;
          _emailAwaitingOther = false;
          _emailNotice = '';
          _put('emailOtp', null);
          return;
        }
        if (check.needsOtherEmailCode) {
          _emailAwaitingOther = true;
          _emailOtp.clear();
          _emailNotice = check.message ?? '';
          _put('emailOtp', null);
          return;
        }
        _emailAttempts.recordFailure();
        _emailVerified = false;
        _put(
          'emailOtp',
          _emailAttempts.blocked
              ? retryCapMessage
              : (check.message ?? incorrectOtpMessage),
        );
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailBusy = _EmailBusy.none;
        _emailAttempts.recordFailure();
        _emailVerified = false;
        _put(
          'emailOtp',
          _emailAttempts.blocked ? retryCapMessage : error.message,
        );
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
    if (stored != null && stored.isNotEmpty) {
      publishSavedAvatar(context, stored, bytes: bytes);
    }
    setState(() {
      _showPhoto = true;
      _sampleAvatar = stored;
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((session) => session.phoneE164), (
      previous,
      next,
    ) {
      _applySessionPhone();
    });
    ref.listen(sessionProvider.select((session) => session.phoneVerified), (
      previous,
      next,
    ) {
      _applySessionPhone();
    });
    if (_showDone && !_reedit) {
      return Scaffold(
        key: const Key('profile-create-saved'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Your profile')),
        ),
        body: SavedSummaryCard(
          title: 'Profile saved',
          fill: true,
          fields: [
            SavedField(
              label: 'Name',
              icon: Icons.badge_outlined,
              value: profilePublicName(_draft()),
            ),
            SavedField(
              label: 'City',
              icon: Icons.place_outlined,
              value: _draft().city,
              onAdd: () => setState(() => _reedit = true),
            ),
          ],
          onEdit: () => setState(() => _reedit = true),
        ),
      );
    }
    final title = _showDone ? 'Profile Completed!' : _stepTitles[_step];
    final detail = _showDone
        ? 'Your profile is verified and ready to use Homizi.'
        : _stepDetails[_step];
    final media = ref.watch(profileMediaProvider);
    final onRole = !_showDone && _step == profileStepRole;
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
            elevation: 0,
            scrolledUnderElevation: 0,
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
          body: ContentBody(
            pageId: 'profile-create-${_showDone ? 'done' : _step}',
            variant: onRole ? PageBackgroundVariant.soft : null,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        if (!onRole) ...[
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
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: HomiziColors.muted),
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
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: HomiziColors.muted),
                          ),
                          const SizedBox(height: 20),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 340),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset =
                                Tween<Offset>(
                                  begin: const Offset(0.12, 0.02),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(
                              _askRoommate
                                  ? 'roommate'
                                  : _showDone
                                  ? 'done'
                                  : _step,
                            ),
                            child: _askRoommate
                                ? _roommateAskBody()
                                : _showDone
                                ? _doneBody()
                                : _stepBody(media),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_askRoommate)
                    const SizedBox(height: 8)
                  else if (onRole)
                    StickyCta(
                      child: ProfileCreateButton(
                        label: 'Continue',
                        busy: _saving || _aadhaarBusy,
                        onPressed: () => unawaited(_continue()),
                      ),
                    )
                  else
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
      ),
    );
  }

  Widget _stepBody(ProfileMediaState media) {
    return switch (_step) {
      profileStepRole => _roleStep(),
      profileStepBasic => _basicStep(),
      profileStepOffice => _officeStep(),
      profileStepLanguage => _languageStep(),
      profileStepContact => _contactStep(),
      profileStepAadhaar => _aadhaarStep(),
      profileStepSelfie => _selfieStep(media),
      profileStepPhoto => _photoStep(media),
      profileStepLifestyle => _lifestyleStep(),
      profileStepBudget => _budgetStep(),
      profileStepRules => _rulesStep(),
      profileStepListing => _listingStep(),
      _ => _termsStep(),
    };
  }

  Widget _roleStep() {
    return ProfileRoleSelect(
      selected: _roles,
      error: _errors['roles'],
      progressStep: _step,
      onToggle: (id) => setState(() {
        if (!_roles.add(id)) {
          _roles.remove(id);
        }
        _errors.remove('roles');
      }),
    );
  }

  Widget _basicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitTextField(
          fieldKey: const Key('profile-create-full-name'),
          label: 'Full Name',
          controller: _fullName,
          hint: 'Priya Shah',
          helper: 'Verification only, not shown on your public profile',
          error: _errors['fullName'],
          icon: RealLifeIcons.person,
          textCapitalization: TextCapitalization.words,
        ),
        KitTextField(
          fieldKey: const Key('profile-create-nickname'),
          label: 'Nick Name',
          controller: _nickname,
          hint: 'Shown on your public profile',
          error: _errors['nickname'],
          icon: RealLifeIcons.badge,
          textCapitalization: TextCapitalization.words,
        ),
        KitTextField(
          fieldKey: const Key('profile-create-surname'),
          label: 'Surname',
          controller: _surname,
          hint: 'Shown on your public profile',
          error: _errors['surname'],
          icon: RealLifeIcons.person,
          textCapitalization: TextCapitalization.words,
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
            IconButton(
              key: const Key('profile-create-dob-pick'),
              tooltip: homiziText(context, 'Choose a date'),
              onPressed: _pickDob,
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: HomiziColors.logoOrange,
              ),
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
        OptionGrid(
          children: [
            for (final option in profileWizardGenders)
              OptionTile(
                key: Key('profile-create-gender-${option.$2}'),
                label: homiziText(context, option.$1),
                icon: iconForChoice(option.$1),
                selected: _gender == option.$2,
                onTap: () => setState(() => _gender = option.$2),
              ),
          ],
        ),
        if (_errors['gender'] != null) _error(_errors['gender']!),
        const SizedBox(height: 12),
        OccupationPicker(
          key: const Key('profile-create-occupation'),
          selected: _occupation,
          error: _errors['occupation'],
          onSelected: (value) => setState(() => _occupation = value),
        ),
        KitTextField(
          fieldKey: const Key('profile-create-company'),
          label: 'Company',
          controller: _companyField,
          hint: 'Optional',
          icon: RealLifeIcons.briefcase,
          textCapitalization: TextCapitalization.words,
        ),
        KitTextField(
          fieldKey: const Key('profile-create-city'),
          label: 'Current City',
          controller: _cityField,
          hint: 'Ahmedabad',
          error: _errors['city'],
          icon: RealLifeIcons.pin,
          textCapitalization: TextCapitalization.words,
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
      readOnly: true,
      enableInteractiveSelection: false,
      showCursor: false,
      keyboardType: TextInputType.none,
      onTap: () => _pickDob(),
      decoration: profileFieldDecoration(context, label: hint),
    );
  }

  Future<void> _pickDob() async {
    final picked = await pickHomiziDate(
      context,
      initial: DateTime(
        int.tryParse(_year.text) ?? DateTime.now().year - 26,
        (int.tryParse(_month.text) ?? 1).clamp(1, 12),
        (int.tryParse(_day.text) ?? 1).clamp(1, 28),
      ),
      firstDate: DateTime(DateTime.now().year - 80),
      lastDate: DateTime(
        DateTime.now().year - 18,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _day.text = picked.day.toString().padLeft(2, '0');
      _month.text = picked.month.toString().padLeft(2, '0');
      _year.text = picked.year.toString();
    });
  }

  Widget _officeStep() {
    return const Column(
      key: Key('profile-office-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SavedOfficeField()],
    );
  }

  Widget _budgetStep() {
    return Column(
      key: const Key('profile-budget-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitTextField(
          fieldKey: const Key('profile-budget-min'),
          label: 'Minimum budget (₹)',
          controller: _budgetMinField,
          hint: '8000',
          keyboardType: TextInputType.number,
          icon: RealLifeIcons.wallet,
        ),
        KitTextField(
          fieldKey: const Key('profile-budget-max'),
          label: 'Maximum budget (₹)',
          controller: _budgetMaxField,
          hint: '20000',
          keyboardType: TextInputType.number,
          icon: RealLifeIcons.wallet,
        ),
        KitTextField(
          fieldKey: const Key('profile-move-in'),
          label: 'Move-in',
          controller: _moveField,
          hint: 'Next month',
          icon: Icons.event_outlined,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _rulesStep() {
    final selected = profileAllowRules(_tags).toSet();
    return Column(
      key: const Key('profile-rules-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in profileHouseRules)
          CheckboxListTile(
            key: Key('profile-rule-$rule'),
            value: selected.contains(rule),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, rule)),
            onChanged: (value) {
              setState(() {
                final rules = profileAllowRules(_tags).toSet();
                if (value ?? false) {
                  rules.add(rule);
                } else {
                  rules.remove(rule);
                }
                final kept = [
                  for (final tag in _tags)
                    if (!tag.startsWith('allow:')) tag,
                ];
                _tags = [...kept, for (final item in rules) 'allow:$item'];
              });
            },
          ),
      ],
    );
  }

  Widget _listingStep() {
    return Column(
      key: const Key('profile-listing-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            'Your name, city, and lifestyle stay on this profile. Posting a room or a home uses them and does not ask again.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
      ],
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
        KitMultiChoice(
          label: 'Select all that apply',
          icon: RealLifeIcons.language,
          selected: _languages,
          options: [
            for (final language in profileWizardLanguages)
              KitOption(
                value: language,
                label: language,
                icon: RealLifeIcons.language,
                key: Key('profile-language-$language'),
              ),
          ],
          onChanged: (next) => setState(() {
            _languages
              ..clear()
              ..addAll(next);
          }),
        ),
        if (_errors['languages'] != null) _error(_errors['languages']!),
      ],
    );
  }

  Widget _contactStep() {
    final emailHosted =
        _hostedProfileEmail && _emailKind != ProfileEmailOtpKind.localCode;
    final mobileError = _errors['mobile'];
    final trialNote = mobileError == phoneTrialUnverifiedMessage;
    final phoneLabel = _mobileResendRemaining > 0
        ? 'Resend in ${_mobileResendRemaining}s'
        : _mobileOtpSent
        ? (phoneWhatsappOtp && _mobileChannel == PhoneOtpChannel.whatsapp
              ? 'Resend on WhatsApp'
              : 'Resend code')
        : (phoneWhatsappOtp ? 'Send code on WhatsApp' : 'Send code by SMS');
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
          error: trialNote ? null : mobileError,
          otpError: _errors['mobileOtp'],
          aside: trialNote ? phoneTrialUnverifiedMessage : '',
          helper: !_mobileOtpSent
              ? null
              : _mobileChannel == PhoneOtpChannel.whatsapp
              ? 'Enter the 6-digit code from WhatsApp.'
              : 'Enter the 6-digit code from the text message.',
          prefix: '+91 ',
          onSend: () => unawaited(
            _sendMobile(
              phoneWhatsappOtp ? PhoneOtpChannel.whatsapp : PhoneOtpChannel.sms,
            ),
          ),
          onVerify: () => unawaited(_verifyMobile()),
          phoneChannels: true,
          phoneBusy: _mobileBusy,
          phoneSendLabel: phoneLabel,
          onSendSms: () => unawaited(_sendMobile(PhoneOtpChannel.sms)),
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
          onSend: _sendEmail,
          onVerify: () => unawaited(_verifyEmail()),
          solidActions: true,
          resendWait: _emailResendSeconds,
          busy: _emailBusy,
          notice: _emailNotice,
          note: emailHosted && _emailOtpSent ? otpExpiryHint : null,
          verifyLocked: _emailAttempts.blocked,
          digitsOnly: true,
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
    required VoidCallback onSend,
    required VoidCallback onVerify,
    String? helper,
    String? prefix,
    bool solidActions = false,
    int resendWait = 0,
    _EmailBusy busy = _EmailBusy.none,
    String notice = '',
    String? note,
    String aside = '',
    bool verifyLocked = false,
    bool digitsOnly = false,
    bool phoneChannels = false,
    bool phoneBusy = false,
    String? phoneSendLabel,
    VoidCallback? onSendSms,
  }) {
    final waiting = resendWait > 0;
    final phoneLocked =
        phoneBusy || (phoneSendLabel?.startsWith('Resend in') ?? false);
    final sendLabel = phoneChannels
        ? (phoneSendLabel ?? 'Send code on WhatsApp')
        : waiting
        ? 'Resend in ${resendWait}s'
        : (sent ? 'Resend OTP' : 'Send OTP');
    final sendPressed = phoneChannels
        ? (phoneLocked ? null : onSend)
        : (busy != _EmailBusy.none || waiting ? null : onSend);
    final verifyPressed = phoneChannels
        ? (phoneBusy ? null : onVerify)
        : (busy != _EmailBusy.none || verifyLocked ? null : onVerify);
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
        if (aside.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, aside),
            key: const Key('profile-create-phone-note'),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
        ],
        const SizedBox(height: 8),
        if (verified)
          ProfileCheckLine(
            label: '$label verified',
            color: profileVerifiedGreen,
            iconKey: Key(checkKey),
          )
        else ...[
          if (phoneChannels && phoneWhatsappOtp) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: Key(sendKey),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.accent,
                  foregroundColor: HomiziColors.ink,
                  disabledBackgroundColor: HomiziColors.accent.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: HomiziColors.ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                onPressed: sendPressed,
                icon: phoneBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HomiziColors.ink,
                        ),
                      )
                    : const WhatsAppStyleIcon(),
                label: Text(homiziText(context, sendLabel)),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('$sendKey-sms'),
                onPressed: phoneLocked ? null : onSendSms,
                child: Text(homiziText(context, 'Send by SMS instead')),
              ),
            ),
          ] else if (phoneChannels)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: Key(sendKey),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.accent,
                  foregroundColor: HomiziColors.ink,
                  disabledBackgroundColor: HomiziColors.accent.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: HomiziColors.ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                onPressed: sendPressed,
                child: phoneBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HomiziColors.ink,
                        ),
                      )
                    : Text(homiziText(context, sendLabel)),
              ),
            )
          else if (solidActions)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: Key(sendKey),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.accent,
                  foregroundColor: HomiziColors.ink,
                  disabledBackgroundColor: HomiziColors.accent.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: HomiziColors.ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                onPressed: sendPressed,
                child: busy == _EmailBusy.send
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HomiziColors.ink,
                        ),
                      )
                    : Text(homiziText(context, sendLabel)),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key(sendKey),
                onPressed: sendPressed,
                child: Text(homiziText(context, sendLabel)),
              ),
            ),
          if (notice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              homiziText(context, notice),
              key: const Key('profile-create-email-notice'),
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
          ],
          if (sent) ...[
            const SizedBox(height: 8),
            TextField(
              key: Key(otpKey),
              controller: otpController,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]
                  : null,
              decoration: profileFieldDecoration(
                context,
                label: 'OTP',
                error: otpError,
                helper: helper,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                homiziText(context, note),
                key: const Key('profile-create-email-expiry'),
                style: const TextStyle(color: HomiziColors.muted),
              ),
            ],
            const SizedBox(height: 8),
            if (solidActions || phoneChannels)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: Key(verifyKey),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.accent,
                    foregroundColor: HomiziColors.ink,
                    disabledBackgroundColor: HomiziColors.accent.withValues(
                      alpha: 0.5,
                    ),
                    disabledForegroundColor: HomiziColors.ink,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  onPressed: verifyPressed,
                  child:
                      (!phoneChannels && busy == _EmailBusy.verify) ||
                          (phoneChannels && phoneBusy)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HomiziColors.ink,
                          ),
                        )
                      : Text(homiziText(context, 'Verify OTP')),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: Key(verifyKey),
                  onPressed: verifyPressed,
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
        _choiceRow('Pets', profilePetOptions, _pets, (value) {
          setState(() => _pets = value);
        }, 'pets'),
        _tagChoice('Sleep', 'sleep', const ['early', 'flexible', 'night']),
        _tagChoice('Guests', 'guests', const [
          'rarely',
          'occasionally',
          'frequently',
        ]),
        _tagChoice('Work style', 'work', const ['office', 'hybrid', 'home']),
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

  Widget _tagChoice(String label, String prefix, List<String> options) {
    final selected = profileTagged(_tags, prefix);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, label),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  key: Key('profile-$prefix-$option'),
                  label: Text(homiziText(context, option)),
                  selected: selected == option,
                  selectedColor: HomiziColors.logoOrange,
                  onSelected: (_) => setState(() {
                    _tags = profileWithTag(_tags, prefix, option);
                  }),
                ),
            ],
          ),
        ],
      ),
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
          KitChoiceField<String>(
            label: label,
            icon: iconForChoice(label),
            gap: 0,
            selected: selected,
            options: [
              for (final option in options)
                KitOption(
                  value: option,
                  label: option,
                  icon: iconForChoice(option),
                  key: Key('profile-$errorKey-$option'),
                ),
            ],
            onChanged: onChanged,
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

  Widget _roommateAskBody() {
    return Column(
      key: const Key('profile-roommate-seeker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'List me as a roommate seeker?'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'People looking for a flatmate can see the same profile. You can change this later in Profile.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('profile-roommate-seeker-no'),
                onPressed: _saving
                    ? null
                    : () => unawaited(_answerRoommate(false)),
                child: Text(homiziText(context, 'No')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('profile-roommate-seeker-yes'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.logoOrange,
                  foregroundColor: HomiziColors.white,
                ),
                onPressed: _saving
                    ? null
                    : () => unawaited(_answerRoommate(true)),
                child: Text(homiziText(context, 'Yes')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _markStepAnswered() {
    final mark = switch (_step) {
      profileStepOffice => 'office',
      profileStepBudget => 'budget',
      profileStepRules => 'rules',
      profileStepListing => 'listing',
      _ => null,
    };
    if (mark == null || _tags.contains('asked:$mark')) {
      return;
    }
    _tags = [..._tags, 'asked:$mark'];
  }

  /// Steps whose answers are already on the one profile are not asked again.
  bool _stepSatisfied(int step) {
    final draft = _draft();
    switch (step) {
      case profileStepRole:
        return draft.roles.isNotEmpty;
      case profileStepBasic:
        return profilePublicName(draft).length >= 2 &&
            draft.city.trim().isNotEmpty &&
            (draft.occupation ?? '').trim().isNotEmpty;
      case profileStepOffice:
        return draft.tags.contains('asked:office') ||
            ref.read(officeRepositoryProvider).primary != null;
      case profileStepLanguage:
        return draft.languages.isNotEmpty;
      case profileStepLifestyle:
        return (draft.smoking ?? '').isNotEmpty &&
            (draft.food ?? '').isNotEmpty &&
            (draft.drinking ?? '').isNotEmpty;
      case profileStepBudget:
        return draft.tags.contains('asked:budget') ||
            (draft.budgetMin != null && draft.budgetMax != null);
      case profileStepRules:
        return draft.tags.contains('asked:rules');
      case profileStepListing:
        final lists =
            draft.roles.contains('host') || draft.roles.contains('sharer');
        return !lists || draft.tags.contains('asked:listing');
      default:
        return false;
    }
  }

  int _advancePastFilled(int step) {
    var next = step;
    while (next < profileStepTerms && _stepSatisfied(next)) {
      next++;
    }
    return next;
  }

  Future<void> _answerRoommate(bool yes) async {
    setState(() => _saving = true);
    final ask = ref
        .read(finderProvider)
        .ask
        .copyWith(profilePosted: yes, postAsked: true);
    ref.read(finderProvider.notifier).saveAsk(ask);
    await writeDeviceString('roommate_finder_post', yes ? 'allow' : 'decline');
    await LiveAccountSync.roommateBrief(ask.toJson());
    if (!mounted) {
      return;
    }
    setState(() {
      _seekRoommate = yes;
      _askRoommate = false;
      _saving = false;
    });
    await _continue();
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
