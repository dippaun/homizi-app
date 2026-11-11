import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_profile.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

class BrokerProfileFields extends StatelessWidget {
  const BrokerProfileFields({
    required this.name,
    required this.agency,
    required this.rera,
    required this.phone,
    required this.email,
    required this.locality,
    required this.cities,
    required this.localities,
    required this.years,
    required this.onCity,
    required this.onAddLocality,
    required this.onRemoveLocality,
    required this.onYears,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController agency;
  final TextEditingController rera;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController locality;
  final Set<String> cities;
  final List<String> localities;
  final int years;
  final void Function(String city, bool selected) onCity;
  final VoidCallback onAddLocality;
  final ValueChanged<String> onRemoveLocality;
  final ValueChanged<int> onYears;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          context,
          keyName: 'broker-flow-name',
          controller: name,
          label: 'Your name',
        ),
        _field(
          context,
          keyName: 'broker-flow-agency',
          controller: agency,
          label: 'Agency name',
        ),
        _field(
          context,
          keyName: 'broker-flow-rera',
          controller: rera,
          label: 'RERA number (optional)',
          hint: 'PRM/KA/RERA/1251/446/AG/171018/000441',
        ),
        Text(
          homiziText(context, 'Areas served'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final city in exploreCities)
              FilterChip(
                key: Key('broker-flow-city-$city'),
                label: Text(homiziText(context, city)),
                selected: cities.contains(city),
                onSelected: (selected) => onCity(city, selected),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          context,
          keyName: 'broker-flow-locality',
          controller: locality,
          label: 'Locality',
          hint: 'Bandra West',
        ),
        OutlinedButton(
          key: const Key('broker-flow-add-locality'),
          onPressed: onAddLocality,
          child: Text(homiziText(context, 'Add locality')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final place in localities)
              InputChip(
                label: Text(homiziText(context, place)),
                onDeleted: () => onRemoveLocality(place),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Experience'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          homiziText(context, 'Years of experience: $years'),
          key: const Key('broker-flow-years-label'),
        ),
        Slider(
          key: const Key('broker-flow-years'),
          value: years.clamp(0, 40).toDouble(),
          max: 40,
          divisions: 40,
          label: '$years',
          onChanged: (value) => onYears(value.round()),
        ),
        Text(
          homiziText(context, 'Contact details'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _field(
          context,
          keyName: 'broker-flow-phone',
          controller: phone,
          label: 'Mobile number',
          hint: '9876543210',
          phone: true,
        ),
        _field(
          context,
          keyName: 'broker-flow-email',
          controller: email,
          label: 'Email',
          hint: 'meenal.deshpande@deshpanderealty.in',
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required String keyName,
    required TextEditingController controller,
    required String label,
    String? hint,
    bool phone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(keyName),
        controller: controller,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        textCapitalization: phone
            ? TextCapitalization.none
            : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: homiziText(context, label),
          hintText: hint == null ? null : homiziText(context, hint),
        ),
      ),
    );
  }
}

BrokerProfileDraft brokerProfileDraft({
  required String name,
  required String agency,
  required String rera,
  required String phone,
  required Set<String> cities,
  required List<String> localities,
  required String pendingLocality,
  required int years,
}) {
  final extra = pendingLocality.trim();
  return BrokerProfileDraft(
    fullName: name,
    agencyName: agency,
    reraNumber: rera,
    cities: cities.toList(),
    localities: [
      ...localities,
      if (extra.isNotEmpty && !localities.contains(extra)) extra,
    ],
    phone: phone,
    yearsExperience: years,
  );
}

String? brokerProfileIssue({
  required BrokerProfileDraft draft,
  required String email,
}) {
  final issues = draft.errors();
  if (issues.isNotEmpty) {
    return issues.first;
  }
  return validateEmailAddress(email);
}

class BrokerVerifyFields extends StatelessWidget {
  const BrokerVerifyFields({
    required this.phone,
    required this.email,
    required this.mobileOtp,
    required this.emailOtp,
    required this.mobileSent,
    required this.emailSent,
    required this.mobileVerified,
    required this.emailVerified,
    required this.demoCode,
    required this.kyc,
    required this.onSendMobile,
    required this.onSendEmail,
    required this.onVerifyMobile,
    required this.onVerifyEmail,
    required this.onDigio,
    required this.digioBusy,
    super.key,
  });

  final String phone;
  final String email;
  final TextEditingController mobileOtp;
  final TextEditingController emailOtp;
  final bool mobileSent;
  final bool emailSent;
  final bool mobileVerified;
  final bool emailVerified;
  final bool demoCode;
  final KycSnapshot kyc;
  final VoidCallback onSendMobile;
  final VoidCallback onSendEmail;
  final VoidCallback onVerifyMobile;
  final VoidCallback onVerifyEmail;
  final VoidCallback onDigio;
  final bool digioBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _otpBlock(
          context,
          title: 'Mobile',
          detail: phone,
          sent: mobileSent,
          verified: mobileVerified,
          otp: mobileOtp,
          sendKey: 'broker-send-mobile',
          otpKey: 'broker-mobile-otp',
          verifyKey: 'broker-verify-mobile',
          onSend: onSendMobile,
          onVerify: onVerifyMobile,
        ),
        const SizedBox(height: 16),
        _otpBlock(
          context,
          title: 'Email',
          detail: email,
          sent: emailSent,
          verified: emailVerified,
          otp: emailOtp,
          sendKey: 'broker-send-email',
          otpKey: 'broker-email-otp',
          verifyKey: 'broker-verify-email',
          onSend: onSendEmail,
          onVerify: onVerifyEmail,
        ),
        if (demoCode) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Demo code 000000'),
            style: const TextStyle(color: HomiziColors.muted),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          homiziText(context, 'Aadhaar'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            'Aadhaar stays on live Digio. Homizi does not store the number, and this screen never marks it verified.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, aadhaarStatusLabel(kyc.aadhaarStatus)),
          key: const Key('broker-aadhaar-state'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (kyc.message.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            homiziText(context, kyc.message),
            key: const Key('broker-aadhaar-note'),
            style: const TextStyle(color: HomiziColors.muted, height: 1.35),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('broker-open-digio'),
          onPressed: digioBusy ? null : onDigio,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(
            homiziText(context, digioBusy ? 'Opening Digio…' : 'Open Digio'),
          ),
        ),
      ],
    );
  }

  Widget _otpBlock(
    BuildContext context, {
    required String title,
    required String detail,
    required bool sent,
    required bool verified,
    required TextEditingController otp,
    required String sendKey,
    required String otpKey,
    required String verifyKey,
    required VoidCallback onSend,
    required VoidCallback onVerify,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                homiziText(context, title),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              verified ? Icons.check_circle : Icons.radio_button_unchecked,
              color: verified ? HomiziColors.success : HomiziColors.muted,
              key: Key('$verifyKey-mark'),
            ),
          ],
        ),
        Text(detail, style: const TextStyle(color: HomiziColors.inkSoft)),
        const SizedBox(height: 8),
        OutlinedButton(
          key: Key(sendKey),
          onPressed: onSend,
          child: Text(
            homiziText(context, sent ? 'Send code again' : 'Send code'),
          ),
        ),
        if (sent) ...[
          const SizedBox(height: 8),
          TextField(
            key: Key(otpKey),
            controller: otp,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: homiziText(context, 'Code')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: Key(verifyKey),
            onPressed: onVerify,
            child: Text(
              homiziText(context, verified ? 'Verified' : 'Verify code'),
            ),
          ),
        ],
      ],
    );
  }
}

class BrokerTrustBadgePage extends StatelessWidget {
  const BrokerTrustBadgePage({
    required this.agency,
    required this.rera,
    required this.years,
    required this.areas,
    required this.mobileVerified,
    required this.emailVerified,
    required this.kyc,
    super.key,
  });

  final String agency;
  final String rera;
  final int years;
  final String areas;
  final bool mobileVerified;
  final bool emailVerified;
  final KycSnapshot kyc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('broker-trust-badge'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HomiziColors.accentWash,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomiziColors.accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified, color: HomiziColors.ink, size: 36),
              const SizedBox(height: 8),
              Text(
                homiziText(context, 'Broker'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(context, agency),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rera.trim().isNotEmpty)
                Text(
                  homiziText(context, 'RERA ${rera.trim()}'),
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
              Text(
                homiziText(context, '$years years · $areas'),
                style: const TextStyle(color: HomiziColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _row(
          context,
          mobileVerified ? 'Mobile verified' : 'Mobile not verified',
          mobileVerified,
        ),
        _row(
          context,
          emailVerified ? 'Email verified' : 'Email not verified',
          emailVerified,
        ),
        _row(
          context,
          aadhaarStatusLabel(kyc.aadhaarStatus),
          kyc.aadhaarVerified,
          keyName: 'broker-trust-aadhaar',
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Aadhaar and face badges appear only after Digio confirms them. Homizi stores the result, the time, the request id, and the last 4 digits.',
          ),
          style: const TextStyle(color: HomiziColors.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    bool done, {
    String? keyName,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        key: keyName == null ? null : Key(keyName),
        children: [
          Icon(
            done ? Icons.check_circle : Icons.hourglass_top,
            color: done ? HomiziColors.success : HomiziColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(context, label),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class BrokerOnboardDone extends StatelessWidget {
  const BrokerOnboardDone({
    required this.agency,
    required this.areas,
    required this.years,
    super.key,
  });

  final String agency;
  final String areas;
  final int years;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('broker-onboard-confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 48),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            '$agency is ready to list homes in $areas. $years years on the desk.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
        ),
      ],
    );
  }
}
