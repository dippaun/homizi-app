import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/indian_phone_field.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

const partnerSteps = ['Basic Info', 'Business Details', 'Verification'];

class PartnerFlowScreen extends ConsumerStatefulWidget {
  const PartnerFlowScreen({super.key});

  @override
  ConsumerState<PartnerFlowScreen> createState() => _PartnerFlowScreenState();
}

class _PartnerFlowScreenState extends ConsumerState<PartnerFlowScreen> {
  var _page = 0;
  var _busy = false;
  String? _note;
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _business;
  late final TextEditingController _address;
  late final TextEditingController _area;
  late final TextEditingController _about;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(partnerApplicationProvider);
    final contact = ref.read(postContactProvider);
    _name = TextEditingController(
      text: contact.fullName.isEmpty
          ? draft.contact.fullName
          : contact.fullName,
    );
    _mobile = TextEditingController(
      text: contact.mobile.isEmpty ? draft.contact.mobile : contact.mobile,
    );
    _email = TextEditingController(
      text: contact.email.isEmpty ? draft.contact.email : contact.email,
    );
    _business = TextEditingController(text: draft.businessName);
    _address = TextEditingController(text: draft.address);
    _area = TextEditingController(text: draft.operatingArea);
    _about = TextEditingController(text: draft.about);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _business.dispose();
    _address.dispose();
    _area.dispose();
    _about.dispose();
    super.dispose();
  }

  void _syncContact() {
    ref
        .read(postContactProvider.notifier)
        .replace(
          ref
              .read(postContactProvider)
              .copyWith(
                fullName: _name.text.trim(),
                mobile: _mobile.text.trim(),
                email: _email.text.trim(),
              ),
        );
  }

  void _back() {
    if (_page > 0) {
      setState(() {
        _page -= 1;
        _note = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.postProperty);
  }

  void _continueType() {
    setState(() {
      _page = 1;
      _note = null;
    });
  }

  void _continueBasic() {
    _syncContact();
    if (_name.text.trim().length < 2) {
      setState(() => _note = 'Enter your full name.');
      return;
    }
    if (indianMobileE164(_mobile.text) == null) {
      setState(() => _note = indianMobileInvalidMessage);
      return;
    }
    final emailError = validateEmailAddress(_email.text);
    if (emailError != null) {
      setState(() => _note = emailError);
      return;
    }
    setState(() {
      _page = 2;
      _note = null;
    });
  }

  void _continueBusiness() {
    if (_address.text.trim().length < 3) {
      setState(() => _note = 'Add a business address.');
      return;
    }
    if (_area.text.trim().isEmpty) {
      setState(() => _note = 'Add the city or locality you operate in.');
      return;
    }
    ref
        .read(partnerApplicationProvider.notifier)
        .setBusiness(
          businessName: _business.text.trim(),
          address: _address.text.trim(),
          operatingArea: _area.text.trim(),
          about: _about.text.trim(),
        );
    setState(() {
      _page = 3;
      _note = null;
    });
  }

  Future<void> _send(bool mobile) async {
    _syncContact();
    final contact = mobile ? _mobile.text.trim() : _email.text.trim();
    final error = await sendPostCode(ref, mobile: mobile, contact: contact);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    ref
        .read(postOtpTargetProvider.notifier)
        .set(
          PostOtpTarget(
            channel: mobile ? PostOtpChannel.mobile : PostOtpChannel.email,
            contact: contact,
          ),
        );
    await context.push<bool>(RoutePaths.postPartnerOtp);
    if (mounted) {
      setState(() => _note = null);
    }
  }

  Future<void> _pick(String kind) async {
    try {
      final picked = await ref.read(photoFilePickerProvider).pick();
      if (picked == null || !mounted) {
        return;
      }
      if (picked.bytes.length > partnerDocumentMaxBytes) {
        setState(() => _note = 'That file is over 10MB.');
        return;
      }
      final type = picked.contentType ?? '';
      if (type != 'image/jpeg' && type != 'image/png' && type != 'image/webp') {
        setState(() => _note = 'Use a JPG or PNG.');
        return;
      }
      final id = ref.read(partnerApplicationProvider).applicationId;
      final path = await storePartnerDocument(
        ref: ref,
        applicationId: id.isEmpty ? 'pending' : id,
        kind: kind,
        bytes: picked.bytes,
        contentType: type,
      );
      ref
          .read(partnerApplicationProvider.notifier)
          .setDocument(
            kind,
            PartnerDocument(
              label: switch (kind) {
                'pan' => 'PAN card',
                'aadhaar' => 'Aadhaar card',
                _ => 'Ownership or authorisation',
              },
              storagePath: path ?? '',
            ),
          );
      if (mounted) {
        setState(() => _note = null);
      }
    } on PhotoPickUnavailable catch (error) {
      if (mounted) {
        setState(() => _note = error.toString());
      }
    }
  }

  Future<void> _submit({required bool verifyLater}) async {
    setState(() => _busy = true);
    final saved = await ref
        .read(partnerApplicationProvider.notifier)
        .submit(verifyLater: verifyLater);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    context.go(RoutePaths.postPartnerDone);
    if (saved.applicationId.isEmpty) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(partnerApplicationProvider);
    final contact = ref.watch(postContactProvider);
    final stepper = _page == 0 ? null : _page - 1;
    return PostPropertyPage(
      pageKey: Key(_page == 0 ? 'post-partner-type' : 'post-partner-step'),
      onBack: _back,
      footer: PostGradientButton(
        buttonKey: Key(_page == 3 ? 'post-submit' : 'post-partner-continue'),
        label: _page == 3 ? 'Submit Application' : 'Continue',
        busy: _busy,
        onPressed: _busy
            ? null
            : () {
                switch (_page) {
                  case 0:
                    _continueType();
                  case 1:
                    _continueBasic();
                  case 2:
                    _continueBusiness();
                  default:
                    unawaited(_submit(verifyLater: _documentsMissing(draft)));
                }
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (stepper != null) ...[
            PostStepper(labels: partnerSteps, index: stepper),
            const SizedBox(height: 16),
          ],
          if (_page == 0) _typePage(draft.partnerType),
          if (_page == 1) _basicPage(contact),
          if (_page == 2) _businessPage(draft.partnerType),
          if (_page == 3) _verifyPage(draft),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note!),
              key: const Key('post-partner-note'),
              style: const TextStyle(color: HomiziColors.error),
            ),
          ],
        ],
      ),
    );
  }

  bool _documentsMissing(PartnerApplication draft) {
    return !draft.pan.picked &&
        !draft.aadhaar.picked &&
        !draft.ownership.picked;
  }

  Widget _typePage(String selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/home/apartment.webp',
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Become a Property Partner'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 26,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(context, 'Select Partner Type'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _TypeTile(
          tileKey: const Key('post-partner-individual'),
          icon: Icons.person_outline,
          title: 'Individual Owner',
          detail: 'List homes you manage for private owners.',
          selected: selected == 'individual',
          onTap: () => ref
              .read(partnerApplicationProvider.notifier)
              .setType('individual'),
        ),
        const SizedBox(height: 10),
        _TypeTile(
          tileKey: const Key('post-partner-builder'),
          icon: Icons.domain_outlined,
          title: 'Builder-Developer',
          detail: 'List projects for a builder or developer.',
          selected: selected == 'builder',
          onTap: () =>
              ref.read(partnerApplicationProvider.notifier).setType('builder'),
        ),
        const SizedBox(height: 10),
        _TypeTile(
          tileKey: const Key('post-partner-agency'),
          icon: Icons.storefront_outlined,
          title: 'Real Estate Agency',
          detail: 'List inventory for an agency.',
          selected: selected == 'agency',
          onTap: () =>
              ref.read(partnerApplicationProvider.notifier).setType('agency'),
        ),
        const SizedBox(height: 16),
        const PostTrustPill(text: 'Trusted by verified users across India.'),
      ],
    );
  }

  Widget _basicPage(PostContact contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Basic Info'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-full-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'Full Name',
            Icons.badge_outlined,
            hint: 'Meera Krishnan',
          ),
        ),
        const SizedBox(height: 12),
        IndianPhoneField(
          controller: _mobile,
          fieldKey: const Key('post-mobile'),
        ),
        const SizedBox(height: 8),
        _OtpRow(
          buttonKey: const Key('post-send-mobile-otp'),
          verified: contact.mobileVerified,
          label: contact.mobileVerified ? 'Mobile verified' : 'Send OTP',
          onPressed: () => unawaited(_send(true)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: postFieldDecoration(
            context,
            'Email',
            Icons.mail_outline,
            hint: 'meera@example.com',
          ),
        ),
        const SizedBox(height: 8),
        _OtpRow(
          buttonKey: const Key('post-send-email-otp'),
          verified: contact.emailVerified,
          label: contact.emailVerified ? 'Email verified' : 'Send OTP',
          onPressed: () => unawaited(_send(false)),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('post-sign-in'),
          onPressed: () => context.push(RoutePaths.login),
          child: Text(
            homiziText(context, 'Already have an account? Sign in'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _businessPage(String type) {
    final label = switch (type) {
      'builder' => 'Builder-Developer',
      'agency' => 'Real Estate Agency',
      _ => 'Individual Owner',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Business Details'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(context, 'Partner type'),
          style: const TextStyle(color: HomiziColors.inkSoft),
        ),
        const SizedBox(height: 6),
        PostChip(label: label),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-business-name'),
          controller: _business,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'Business name (optional)',
            Icons.business_outlined,
            hint: 'Krishnan Estates',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-business-address'),
          controller: _address,
          textCapitalization: TextCapitalization.sentences,
          decoration: postFieldDecoration(
            context,
            'Address',
            Icons.location_on_outlined,
            hint: '12, 4th Cross, Indiranagar, Bengaluru',
          ),
        ),
        const SizedBox(height: 12),
        PlaceAutocompleteField(
          controller: _area,
          fieldKey: const Key('post-operating-area'),
          labelText: homiziText(context, 'Operating areas'),
          hintText: homiziText(context, 'Koramangala, Bengaluru'),
          prefixIcon: const Icon(
            Icons.location_city_outlined,
            color: HomiziColors.logoOrange,
          ),
          onSelected: (place) {
            _area.text = place.label;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-about'),
          controller: _about,
          maxLength: 500,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: postFieldDecoration(
            context,
            'About',
            Icons.notes_outlined,
            hint: 'Homes we list across Bengaluru and Pune.',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_about.text.length}/500',
            key: const Key('post-about-count'),
            style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _verifyPage(PartnerApplication draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Verification'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Documents are optional. You can publish and verify later.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 12),
        _DocRow(
          rowKey: const Key('post-doc-pan'),
          title: 'PAN',
          done: draft.pan.picked,
          stored: draft.pan.storagePath.isNotEmpty,
          onTap: () => unawaited(_pick('pan')),
        ),
        const SizedBox(height: 8),
        _DocRow(
          rowKey: const Key('post-doc-aadhaar'),
          title: 'Aadhaar',
          done: draft.aadhaar.picked,
          stored: draft.aadhaar.storagePath.isNotEmpty,
          onTap: () => unawaited(_pick('aadhaar')),
        ),
        const SizedBox(height: 8),
        _DocRow(
          rowKey: const Key('post-doc-ownership'),
          title: 'Property ownership / authorisation (optional)',
          done: draft.ownership.picked,
          stored: draft.ownership.storagePath.isNotEmpty,
          onTap: () => unawaited(_pick('ownership')),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('post-verify-later'),
          onPressed: _busy ? null : () => unawaited(_submit(verifyLater: true)),
          child: Text(homiziText(context, 'Verify later')),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.homiziLavender : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? HomiziColors.homiziPurple : HomiziColors.line,
        ),
      ),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: HomiziColors.logoOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      homiziText(context, detail),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? HomiziColors.homiziPurple
                    : HomiziColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpRow extends StatelessWidget {
  const _OtpRow({
    required this.buttonKey,
    required this.verified,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool verified;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(
          verified ? Icons.verified : Icons.sms_outlined,
          color: verified ? HomiziColors.success : HomiziColors.logoOrange,
        ),
        label: Text(
          homiziText(context, label),
          style: TextStyle(
            color: verified ? HomiziColors.success : HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.rowKey,
    required this.title,
    required this.done,
    required this.stored,
    required this.onTap,
  });

  final Key rowKey;
  final String title;
  final bool done;
  final bool stored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        key: rowKey,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                done ? Icons.verified : Icons.upload_file_outlined,
                color: done ? HomiziColors.success : HomiziColors.logoOrange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                homiziText(
                  context,
                  done ? (stored ? 'Saved' : 'Added') : 'Upload',
                ),
                style: TextStyle(
                  color: done ? HomiziColors.success : HomiziColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
