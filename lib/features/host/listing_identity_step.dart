import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/host_flow/host_flow_chrome.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

/// Step 4 of 8. Aadhaar and the selfie never block the next step.
class ListingIdentityStep extends ConsumerWidget {
  const ListingIdentityStep({
    required this.demoIdentity,
    required this.mobileVerified,
    required this.emailVerified,
    required this.aadhaarVerified,
    required this.selfieVerified,
    required this.reused,
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
    required this.showPhoto,
    required this.onShowPhoto,
    required this.onSelfieCamera,
    required this.onSelfieUpload,
    required this.onVerifyLater,
    this.selfieNote,
    super.key,
  });

  final bool demoIdentity;
  final bool mobileVerified;
  final bool emailVerified;
  final bool aadhaarVerified;
  final bool selfieVerified;
  final bool reused;
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
  final bool showPhoto;
  final ValueChanged<bool> onShowPhoto;
  final VoidCallback onSelfieCamera;
  final VoidCallback onSelfieUpload;
  final VoidCallback onVerifyLater;
  final String? selfieNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kyc = ref.watch(myKycProvider).asData?.value;
    final aadhaarDone = aadhaarVerified || (kyc?.aadhaarVerified ?? false);
    final selfie = ref.watch(profileMediaProvider).selfie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepProgress(),
        const SizedBox(height: 16),
        if (reused)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              homiziText(
                context,
                'Using your Create Your Profile verification.',
              ),
              key: const Key('host-verification-reused'),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: HomiziColors.inkSoft,
              ),
            ),
          ),
        if (mobileVerified)
          const ProfileCheckLine(
            label: 'Mobile Verified',
            color: profileVerifiedGreen,
            iconKey: Key('host-mobile-check'),
          )
        else
          _card(
            context,
            title: 'Mobile Number Verification',
            child: _otp(
              context,
              sent: mobileOtpSent,
              sendKey: const Key('host-mobile-send'),
              fieldKey: const Key('host-mobile-otp'),
              verifyKey: const Key('host-mobile-verify'),
              controller: mobileOtp,
              onSend: onSendMobile,
              onVerify: onVerifyMobile,
              helper: demoIdentity ? 'Demo code 000000' : null,
            ),
          ),
        if (emailVerified)
          const ProfileCheckLine(
            label: 'Email Verified',
            color: profileVerifiedGreen,
            iconKey: Key('host-email-check'),
          )
        else
          _card(
            context,
            title: 'Email Verification',
            child: _otp(
              context,
              sent: emailOtpSent,
              sendKey: const Key('host-email-send'),
              fieldKey: const Key('host-email-otp'),
              verifyKey: const Key('host-email-verify'),
              controller: emailOtp,
              onSend: onSendEmail,
              onVerify: onVerifyEmail,
              helper: demoIdentity ? 'Demo code 000000' : null,
            ),
          ),
        if (aadhaarDone)
          const _VerifiedAadhaar()
        else
          _card(
            context,
            title: 'Aadhaar Verification',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  homiziText(
                    context,
                    'Official Aadhaar checks stay on Digio. You can verify later and still publish.',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: HomiziColors.inkSoft,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                if (demoIdentity)
                  _aadhaarFields(context)
                else ...[
                  Text(homiziText(context, kycComingSoonCopy)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('host-open-digio'),
                      onPressed: onOpenDigio,
                      child: Text(homiziText(context, 'Open the Digio check')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        _card(context, title: 'Selfie', child: _selfie(context, selfie)),
        Material(
          color: HomiziColors.white,
          elevation: 1,
          shadowColor: HomiziColors.shadow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            key: const Key('host-photo-toggle'),
            tileColor: HomiziColors.white,
            selectedTileColor: HomiziColors.white,
            value: showPhoto,
            onChanged: onShowPhoto,
            title: Text(homiziText(context, 'Show my photo to verified users')),
            subtitle: Text(
              homiziText(
                context,
                'Off by default. Other people see your initials unless this is on and they are verified.',
              ),
            ),
          ),
        ),
        if (!aadhaarDone) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              key: const Key('host-verify-later'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomiziColors.ink,
                side: const BorderSide(color: HomiziColors.accent),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              onPressed: onVerifyLater,
              child: Text(
                homiziText(context, 'Verify later'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selfie(BuildContext context, Uint8List? selfie) {
    final note = selfieNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          homiziText(
            context,
            'Optional selfie. It stays on this device unless the photo bucket is already on this project.',
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            color: HomiziColors.muted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (selfie != null && selfie.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: Image.memory(
                selfie,
                key: const Key('host-selfie-preview'),
                height: 160,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
          )
        else if (!selfieVerified)
          Container(
            key: const Key('host-selfie-empty'),
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomiziColors.soft,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: HomiziColors.line),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: HomiziColors.accent,
              size: 36,
            ),
          ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, note),
            key: const Key('host-selfie-note'),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: HomiziColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (!selfieVerified) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('host-selfie-camera'),
                onPressed: onSelfieCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(homiziText(context, 'Take a photo')),
              ),
              OutlinedButton.icon(
                key: const Key('host-selfie-upload'),
                onPressed: onSelfieUpload,
                icon: const Icon(Icons.upload_outlined),
                label: Text(homiziText(context, 'Upload a photo')),
              ),
            ],
          ),
          if (demoIdentity) ...[
            const SizedBox(height: 8),
            if (!sampleReady)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('host-sample-photo'),
                  onPressed: onSamplePhoto,
                  child: Text(homiziText(context, 'Use sample photo')),
                ),
              )
            else ...[
              Text(
                homiziText(context, 'Sample photo for this demo'),
                key: const Key('host-sample-ready'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('host-liveness'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.accent,
                    foregroundColor: HomiziColors.ink,
                  ),
                  onPressed: onLiveness,
                  child: Text(homiziText(context, 'I blinked')),
                ),
              ),
            ],
          ],
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: ProfileCheckLine(
              label: 'Selfie Verified',
              color: profileVerifiedGreen,
              iconKey: Key('host-liveness-check'),
            ),
          ),
      ],
    );
  }

  Widget _aadhaarFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          homiziText(
            context,
            'We use secure and government authorized verification.',
          ),
        ),
        TextField(
          key: const Key('host-aadhaar'),
          controller: aadhaar,
          keyboardType: TextInputType.number,
          inputFormatters: aadhaarFormatters,
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
            onPressed: onSendAadhaar,
            child: Text(homiziText(context, 'Send OTP')),
          ),
        ),
        if (aadhaarOtpSent) ...[
          TextField(
            key: const Key('host-aadhaar-otp'),
            controller: aadhaarOtp,
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
              onPressed: onVerifyAadhaar,
              child: Text(homiziText(context, 'Verify')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _otp(
    BuildContext context, {
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

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: flowCard(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, title),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: homiziText(context, 'Step 4 of 8'),
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        child: LinearProgressIndicator(
          key: Key('host-identity-progress'),
          value: 4 / hostOnboardingStepCount,
          minHeight: 6,
          color: HomiziColors.accent,
          backgroundColor: HomiziColors.line,
        ),
      ),
    );
  }
}

class _VerifiedAadhaar extends StatelessWidget {
  const _VerifiedAadhaar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: flowCard(color: HomiziColors.successWash),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: HomiziColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      homiziText(context, 'Verified'),
                      key: const Key('host-verified-banner'),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: HomiziColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(context, 'Aadhaar is verified. You can continue.'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HomiziColors.inkSoft,
                ),
              ),
              const ProfileCheckLine(
                label: 'Aadhaar Verified',
                color: profileVerifiedGreen,
                iconKey: Key('host-aadhaar-check'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
