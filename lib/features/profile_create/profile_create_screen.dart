import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:image_picker/image_picker.dart';

const _stepCopy = <(String, String)>[
  ('Basic Information', 'Tell us about yourself'),
  ('Verify Mobile & Email', 'Keep your account secure'),
  ('Aadhaar Verification', 'Verify your identity with Aadhaar'),
  ('Selfie Verification', 'Take a clear selfie to confirm your identity'),
  ('Profile Completed!', 'Your profile is verified and ready to use Homizi.'),
];

/// Five-step Create Your Profile flow. It does not send the person to sign-in.
class ProfileCreateScreen extends ConsumerStatefulWidget {
  const ProfileCreateScreen({super.key});

  @override
  ConsumerState<ProfileCreateScreen> createState() =>
      _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends ConsumerState<ProfileCreateScreen> {
  final _scroll = ScrollController();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _mobileOtp = TextEditingController();
  final _emailOtp = TextEditingController();
  final _aadhaar = TextEditingController();
  final _aadhaarOtp = TextEditingController();
  final _errors = <String, String>{};

  var _step = 0;
  var _generation = 0;
  var _saving = false;
  int? _birthYear;
  String? _gender;
  String? _occupation;
  var _mobileOtpSent = false;
  var _mobileVerified = false;
  var _emailOtpSent = false;
  var _emailVerified = false;
  var _aadhaarDigits = '';
  var _aadhaarOtpSent = false;
  var _aadhaarVerified = false;
  var _selfieVerified = false;
  Uint8List? _selfieBytes;
  String? _sampleAvatar;
  var _cameraUnavailable = false;

  @override
  void initState() {
    super.initState();
    _apply(ref.read(profileCreateStoreProvider).draft);
  }

  void _apply(ProfileCreateDraft saved) {
    _step = saved.step.clamp(0, _stepCopy.length - 1);
    _name.text = saved.fullName;
    _birthYear = saved.birthYear;
    _dob.text = saved.birthYear == null ? '' : '${saved.birthYear}';
    _gender = saved.gender;
    _occupation = saved.occupation;
    _mobile.text = saved.mobile;
    _mobileOtpSent = saved.mobileOtpSent;
    _mobileVerified = saved.mobileVerified;
    _email.text = saved.email;
    _emailOtpSent = saved.emailOtpSent;
    _emailVerified = saved.emailVerified;
    _aadhaarDigits = saved.aadhaarLast4;
    _aadhaarOtpSent = saved.aadhaarOtpSent;
    _aadhaarVerified = saved.aadhaarVerified;
    if (saved.aadhaarVerified && saved.aadhaarLast4.length == 4) {
      _aadhaar.text = 'XXXX XXXX ${saved.aadhaarLast4}';
    }
    _selfieVerified = saved.selfieVerified;
    _sampleAvatar = saved.sampleAvatar;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _dob.dispose();
    _mobile.dispose();
    _email.dispose();
    _mobileOtp.dispose();
    _emailOtp.dispose();
    _aadhaar.dispose();
    _aadhaarOtp.dispose();
    super.dispose();
  }

  ProfileCreateDraft _draft() {
    final last4 = _aadhaarDigits.length <= 4
        ? _aadhaarDigits
        : _aadhaarDigits.substring(_aadhaarDigits.length - 4);
    return ProfileCreateDraft(
      step: _step,
      fullName: _name.text.trim(),
      birthYear: _birthYear,
      gender: _gender,
      occupation: _occupation,
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
      sampleAvatar: _sampleAvatar,
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

  bool _validate() {
    if (_step == 0) {
      _put('name', validateFullName(_name.text));
      _put('birthYear', validateBirthYear(_birthYear));
      _put('gender', validateGender(_gender));
      _put('occupation', validateOccupation(_occupation));
    } else if (_step == 1) {
      _put('mobile', validateIndianMobile(_mobile.text));
      _put('email', validateEmailAddress(_email.text));
      _put('mobileOtp', _mobileVerified ? null : 'Verify your mobile number.');
      _put('emailOtp', _emailVerified ? null : 'Verify your email address.');
    } else if (_step == 2) {
      if (_aadhaarVerified) {
        _put('aadhaar', null);
        _put('aadhaarOtp', null);
      } else {
        _put('aadhaar', validateAadhaarDigits(_aadhaarDigits));
        _put('aadhaarOtp', 'Verify the Aadhaar OTP.');
      }
    } else if (_step == 3) {
      _put(
        'selfie',
        _selfieVerified ? null : 'Capture a selfie or use the sample photo.',
      );
    }
    return _errors.isEmpty;
  }

  Future<void> _continue() async {
    if (_step >= _stepCopy.length - 1) {
      await _explore();
      return;
    }
    final ok = _validate();
    setState(() {});
    if (!ok || _saving) {
      return;
    }
    setState(() => _step += 1);
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _saving = true);
    await _persist();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _explore() async {
    setState(() => _saving = true);
    await _persist();
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(RoutePaths.home);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _back() {
    if (_step == 0) {
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
      _generation += 1;
      _birthYear = null;
      _gender = null;
      _occupation = null;
      _mobileOtpSent = false;
      _mobileVerified = false;
      _emailOtpSent = false;
      _emailVerified = false;
      _aadhaarDigits = '';
      _aadhaarOtpSent = false;
      _aadhaarVerified = false;
      _selfieVerified = false;
      _selfieBytes = null;
      _sampleAvatar = null;
      _cameraUnavailable = false;
      _errors.clear();
      _name.clear();
      _dob.clear();
      _mobile.clear();
      _email.clear();
      _mobileOtp.clear();
      _emailOtp.clear();
      _aadhaar.clear();
      _aadhaarOtp.clear();
    });
    await _persist();
  }

  Future<void> _pickYear() async {
    final year = await pickBirthYear(context, _birthYear);
    if (!mounted || year == null) {
      return;
    }
    setState(() {
      _birthYear = year;
      _dob.text = '$year';
      _put('birthYear', null);
    });
  }

  void _sendMobile() {
    final error = validateIndianMobile(_mobile.text);
    setState(() {
      _put('mobile', error);
      if (error == null) {
        _mobileOtpSent = true;
      }
    });
  }

  void _sendEmail() {
    final error = validateEmailAddress(_email.text);
    setState(() {
      _put('email', error);
      if (error == null) {
        _emailOtpSent = true;
      }
    });
  }

  void _sendAadhaar() {
    final error = validateAadhaarDigits(_aadhaarDigits);
    setState(() {
      _put('aadhaar', error);
      if (error == null) {
        _aadhaarOtpSent = true;
        _put('aadhaarOtp', null);
      }
    });
  }

  void _verifyMobile() {
    final ok = profileOtpMatches(_mobileOtp.text);
    setState(() {
      _mobileVerified = ok;
      _put(
        'mobileOtp',
        ok ? null : 'That code does not match. The demo code is 000000.',
      );
    });
  }

  void _verifyEmail() {
    final ok = profileOtpMatches(_emailOtp.text);
    setState(() {
      _emailVerified = ok;
      _put(
        'emailOtp',
        ok ? null : 'That code does not match. The demo code is 000000.',
      );
    });
  }

  void _verifyAadhaar() {
    final digitsOk = validateAadhaarDigits(_aadhaarDigits) == null;
    final ok = digitsOk && profileOtpMatches(_aadhaarOtp.text);
    setState(() {
      _aadhaarVerified = ok;
      _put('aadhaar', digitsOk ? null : validateAadhaarDigits(_aadhaarDigits));
      _put(
        'aadhaarOtp',
        ok ? null : 'That code does not match. The demo code is 000000.',
      );
    });
  }

  Future<Uint8List?> _readPicker(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file == null) {
        return null;
      }
      return file.readAsBytes();
    } on Object {
      return null;
    }
  }

  Future<void> _capture() async {
    Uint8List? bytes;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file != null) {
        bytes = await file.readAsBytes();
      }
    } on Object {
      bytes = await _readPicker(ImageSource.gallery);
    }
    if (!mounted) {
      return;
    }
    if (bytes == null) {
      setState(() => _cameraUnavailable = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            homiziText(
              context,
              'The camera could not be opened. Choose a photo, or use the sample in this demo.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _selfieBytes = bytes;
      _sampleAvatar = null;
      _selfieVerified = true;
      _put('selfie', null);
    });
  }

  Future<void> _choosePhoto() async {
    final bytes = await _readPicker(ImageSource.gallery);
    if (!mounted) {
      return;
    }
    if (bytes == null) {
      setState(() => _cameraUnavailable = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            homiziText(
              context,
              'The photo library could not be opened. Use the sample in this demo.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _selfieBytes = bytes;
      _sampleAvatar = null;
      _selfieVerified = true;
      _put('selfie', null);
    });
  }

  void _useSample() {
    setState(() {
      _selfieBytes = null;
      _sampleAvatar = profileSampleAvatar;
      _selfieVerified = true;
      _put('selfie', null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = _stepCopy[_step];
    final done = _step == _stepCopy.length - 1;
    final allowSample = demoModeOn(ref) || _cameraUnavailable;
    return Scaffold(
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  ProfileCreateProgress(step: _step),
                  const SizedBox(height: 24),
                  Text(
                    homiziText(context, copy.$1),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    homiziText(context, copy.$2),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: HomiziColors.muted),
                  ),
                  const SizedBox(height: 24),
                  if (_step == 0) _basicStep(),
                  if (_step == 1) _contactStep(),
                  if (_step == 2) _aadhaarStep(),
                  if (_step == 3) _selfieStep(allowSample: allowSample),
                  if (done) const _CompletedStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ProfileCreateButton(
                label: done ? 'Start Exploring' : 'Continue',
                busy: _saving,
                onPressed: () => unawaited(_continue()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicStep() {
    final range = ageRangeForBirthYear(_birthYear);
    return Column(
      children: [
        TextField(
          key: const Key('profile-create-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: profileFieldDecoration(
            context,
            label: 'Full name',
            error: _errors['name'],
          ),
          onChanged: (_) => setState(() => _put('name', null)),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('profile-create-dob'),
          controller: _dob,
          readOnly: true,
          onTap: () => unawaited(_pickYear()),
          decoration: profileFieldDecoration(
            context,
            label: 'Date of birth',
            hint: 'Year of birth',
            error: _errors['birthYear'],
            helper: range == null ? null : 'Shown on your profile as $range.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: Key('profile-create-gender-$_generation'),
          initialValue: _gender,
          isExpanded: true,
          decoration: profileFieldDecoration(
            context,
            label: 'Gender',
            error: _errors['gender'],
          ),
          items: [
            for (final option in profileGenderOptions)
              DropdownMenuItem(
                value: option,
                child: Text(homiziText(context, option)),
              ),
          ],
          onChanged: (value) => setState(() {
            _gender = value;
            _put('gender', null);
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: Key('profile-create-occupation-$_generation'),
          initialValue: _occupation,
          isExpanded: true,
          decoration: profileFieldDecoration(
            context,
            label: 'Occupation',
            error: _errors['occupation'],
          ),
          items: [
            for (final option in profileOccupationOptions)
              DropdownMenuItem(
                value: option,
                child: Text(homiziText(context, option)),
              ),
          ],
          onChanged: (value) => setState(() {
            _occupation = value;
            _put('occupation', null);
          }),
        ),
      ],
    );
  }

  Widget _contactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile-create-mobile'),
          controller: _mobile,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: profileFieldDecoration(
            context,
            label: 'Mobile number',
            prefix: '+91 ',
            error: _errors['mobile'],
          ),
          onChanged: (_) => setState(() {
            _mobileVerified = false;
            _put('mobile', null);
          }),
        ),
        const SizedBox(height: 8),
        _otpBlock(
          sent: _mobileOtpSent,
          verified: _mobileVerified,
          sendKey: const Key('profile-create-mobile-send'),
          fieldKey: const Key('profile-create-mobile-otp'),
          verifyKey: const Key('profile-create-mobile-verify'),
          checkKey: const Key('profile-create-mobile-check'),
          controller: _mobileOtp,
          error: _errors['mobileOtp'],
          onSend: _sendMobile,
          onVerify: _verifyMobile,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('profile-create-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: profileFieldDecoration(
            context,
            label: 'Email',
            error: _errors['email'],
          ),
          onChanged: (_) => setState(() {
            _emailVerified = false;
            _put('email', null);
          }),
        ),
        const SizedBox(height: 8),
        _otpBlock(
          sent: _emailOtpSent,
          verified: _emailVerified,
          sendKey: const Key('profile-create-email-send'),
          fieldKey: const Key('profile-create-email-otp'),
          verifyKey: const Key('profile-create-email-verify'),
          checkKey: const Key('profile-create-email-check'),
          controller: _emailOtp,
          error: _errors['emailOtp'],
          onSend: _sendEmail,
          onVerify: _verifyEmail,
        ),
      ],
    );
  }

  Widget _otpBlock({
    required bool sent,
    required bool verified,
    required Key sendKey,
    required Key fieldKey,
    required Key verifyKey,
    required Key checkKey,
    required TextEditingController controller,
    required String? error,
    required VoidCallback onSend,
    required VoidCallback onVerify,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: profileFieldDecoration(
              context,
              label: 'OTP',
              helper: 'Demo code 000000',
              error: error,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                key: verifyKey,
                onPressed: onVerify,
                child: Text(homiziText(context, 'Verify')),
              ),
              if (verified) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  key: checkKey,
                  color: profileVerifiedGreen,
                ),
              ],
            ],
          ),
        ] else if (error != null)
          Text(
            homiziText(context, error),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _aadhaarStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: ProfileSunburst()),
        const SizedBox(height: 16),
        const ProfileCheckLine(
          label: 'Enter Aadhaar number',
          color: HomiziColors.accent,
        ),
        const ProfileCheckLine(
          label: 'Verify with OTP',
          color: HomiziColors.accent,
        ),
        const ProfileCheckLine(
          label: 'Your data is secure',
          color: HomiziColors.accent,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('profile-create-aadhaar'),
          controller: _aadhaar,
          keyboardType: TextInputType.number,
          inputFormatters: [_AadhaarFormatter(this)],
          decoration: profileFieldDecoration(
            context,
            label: 'Aadhaar number',
            hint: 'XXXX XXXX 1234',
            error: _errors['aadhaar'],
          ),
          onChanged: (_) => setState(() => _put('aadhaar', null)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('profile-create-aadhaar-send'),
            onPressed: _sendAadhaar,
            child: Text(homiziText(context, 'Send OTP')),
          ),
        ),
        if (!_aadhaarOtpSent && _errors['aadhaarOtp'] != null)
          Text(
            homiziText(context, _errors['aadhaarOtp']!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        if (_aadhaarOtpSent) ...[
          TextField(
            key: const Key('profile-create-aadhaar-otp'),
            controller: _aadhaarOtp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: profileFieldDecoration(
              context,
              label: 'Demo verification',
              helper:
                  'Demo verification — Digio is not live. The code is 000000.',
              error: _errors['aadhaarOtp'],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                key: const Key('profile-create-aadhaar-verify'),
                onPressed: _verifyAadhaar,
                child: Text(homiziText(context, 'Verify')),
              ),
              if (_aadhaarVerified) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  key: Key('profile-create-aadhaar-check'),
                  color: profileVerifiedGreen,
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          homiziText(
            context,
            'We use secure and government authorized verification.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
        ),
      ],
    );
  }

  Widget _selfieStep({required bool allowSample}) {
    return Column(
      children: [
        Center(
          child: Container(
            key: _selfieVerified
                ? const Key('profile-create-selfie-ready')
                : null,
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomiziColors.mist,
              border: Border.all(color: HomiziColors.accent, width: 4),
            ),
            child: ClipOval(child: _selfiePreview()),
          ),
        ),
        const SizedBox(height: 24),
        const ProfileCheckLine(
          label: 'Look into the camera',
          color: HomiziColors.accent,
        ),
        const ProfileCheckLine(
          label: 'Ensure good lighting',
          color: HomiziColors.accent,
        ),
        const ProfileCheckLine(
          label: 'Keep your face clearly visible',
          color: HomiziColors.accent,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('profile-create-capture'),
            onPressed: () => unawaited(_capture()),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.ink,
              side: const BorderSide(color: HomiziColors.accent, width: 2),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(homiziText(context, 'Capture Selfie')),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('profile-create-gallery'),
          onPressed: () => unawaited(_choosePhoto()),
          child: Text(homiziText(context, 'Choose a photo')),
        ),
        if (allowSample)
          TextButton(
            key: const Key('profile-create-sample'),
            onPressed: _useSample,
            child: Text(homiziText(context, 'Use sample photo')),
          ),
        if (_sampleAvatar != null)
          Text(
            homiziText(context, 'Sample photo for this demo'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
          ),
        if (_errors['selfie'] != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, _errors['selfie']!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _selfiePreview() {
    final bytes = _selfieBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, width: 192, height: 192);
    }
    final sample = _sampleAvatar;
    if (sample != null) {
      return Image.asset(
        sample,
        key: const Key('profile-create-sample-preview'),
        fit: BoxFit.cover,
        width: 192,
        height: 192,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 72, color: HomiziColors.muted),
      );
    }
    return const Icon(Icons.person, size: 72, color: HomiziColors.muted);
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

class _CompletedStep extends StatelessWidget {
  const _CompletedStep();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: profileVerifiedWash,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Icon(Icons.check, color: profileVerifiedGreen, size: 56),
            ),
          ),
        ),
        SizedBox(height: 24),
        ProfileCheckLine(
          label: 'Mobile Verified',
          color: profileVerifiedGreen,
          iconKey: Key('profile-verified-mobile'),
        ),
        ProfileCheckLine(
          label: 'Email Verified',
          color: profileVerifiedGreen,
          iconKey: Key('profile-verified-email'),
        ),
        ProfileCheckLine(
          label: 'Aadhaar Verified',
          color: profileVerifiedGreen,
          iconKey: Key('profile-verified-aadhaar'),
        ),
        ProfileCheckLine(
          label: 'Selfie Verified',
          color: profileVerifiedGreen,
          iconKey: Key('profile-verified-selfie'),
        ),
      ],
    );
  }
}
