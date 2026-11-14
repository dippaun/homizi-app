import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/indian_phone_field.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';

class OwnerDocs {
  const OwnerDocs({this.pan = '', this.aadhaar = '', this.ownership = ''});

  final String pan;
  final String aadhaar;
  final String ownership;

  bool get any => pan.isNotEmpty || aadhaar.isNotEmpty || ownership.isNotEmpty;

  OwnerDocs copyWith({String? pan, String? aadhaar, String? ownership}) {
    return OwnerDocs(
      pan: pan ?? this.pan,
      aadhaar: aadhaar ?? this.aadhaar,
      ownership: ownership ?? this.ownership,
    );
  }
}

class OwnerDocsController extends Notifier<OwnerDocs> {
  @override
  OwnerDocs build() => const OwnerDocs();

  void set(OwnerDocs next) => state = next;
}

final ownerDocsProvider = NotifierProvider<OwnerDocsController, OwnerDocs>(
  OwnerDocsController.new,
);

/// Name, mobile, and email on the owner Basic Info stage. OTP reuses the
/// partner verification screen and the existing demo code.
class OwnerContactFields extends ConsumerStatefulWidget {
  const OwnerContactFields({super.key});

  @override
  ConsumerState<OwnerContactFields> createState() => _OwnerContactFieldsState();
}

class _OwnerContactFieldsState extends ConsumerState<OwnerContactFields> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  String? _note;

  @override
  void initState() {
    super.initState();
    final contact = ref.read(postContactProvider);
    _name = TextEditingController(text: contact.fullName);
    _mobile = TextEditingController(text: contact.mobile);
    _email = TextEditingController(text: contact.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  void _sync() {
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

  Future<void> _send(bool mobile) async {
    _sync();
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

  @override
  Widget build(BuildContext context) {
    final contact = ref.watch(postContactProvider);
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
          onChanged: (_) => _sync(),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('post-send-mobile-otp'),
            onPressed: () => unawaited(_send(true)),
            icon: Icon(
              contact.mobileVerified ? Icons.verified : Icons.sms_outlined,
              color: contact.mobileVerified
                  ? HomiziColors.success
                  : HomiziColors.logoOrange,
            ),
            label: Text(
              homiziText(
                context,
                contact.mobileVerified ? 'Mobile verified' : 'Send OTP',
              ),
              style: TextStyle(
                color: contact.mobileVerified
                    ? HomiziColors.success
                    : HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        TextField(
          key: const Key('post-email'),
          controller: _email,
          onChanged: (_) => _sync(),
          keyboardType: TextInputType.emailAddress,
          decoration: postFieldDecoration(
            context,
            'Email',
            Icons.mail_outline,
            hint: 'meera@example.com',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('post-send-email-otp'),
            onPressed: () => unawaited(_send(false)),
            icon: Icon(
              contact.emailVerified ? Icons.verified : Icons.sms_outlined,
              color: contact.emailVerified
                  ? HomiziColors.success
                  : HomiziColors.logoOrange,
            ),
            label: Text(
              homiziText(
                context,
                contact.emailVerified ? 'Email verified' : 'Send OTP',
              ),
              style: TextStyle(
                color: contact.emailVerified
                    ? HomiziColors.success
                    : HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (_note != null)
          Text(
            homiziText(context, _note!),
            style: const TextStyle(color: HomiziColors.error),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class OwnerVerifyPanel extends ConsumerWidget {
  const OwnerVerifyPanel({required this.onVerifyLater, super.key});

  final VoidCallback onVerifyLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(ownerDocsProvider);
    return Column(
      key: const Key('post-owner-verify'),
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
        _Doc(
          rowKey: const Key('post-owner-pan'),
          title: 'PAN',
          done: docs.pan.isNotEmpty,
          onTap: () => unawaited(_pick(ref, 'pan')),
        ),
        const SizedBox(height: 8),
        _Doc(
          rowKey: const Key('post-owner-aadhaar'),
          title: 'Aadhaar',
          done: docs.aadhaar.isNotEmpty,
          onTap: () => unawaited(_pick(ref, 'aadhaar')),
        ),
        const SizedBox(height: 8),
        _Doc(
          rowKey: const Key('post-owner-ownership'),
          title: 'Property ownership (optional)',
          done: docs.ownership.isNotEmpty,
          onTap: () => unawaited(_pick(ref, 'ownership')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('post-verify-later'),
          onPressed: onVerifyLater,
          child: Text(homiziText(context, 'Verify later')),
        ),
      ],
    );
  }

  Future<void> _pick(WidgetRef ref, String kind) async {
    try {
      final picked = await ref.read(photoFilePickerProvider).pick();
      if (picked == null) {
        return;
      }
      final type = picked.contentType ?? '';
      if (type != 'image/jpeg' && type != 'image/png') {
        return;
      }
      final path = await storePartnerDocument(
        ref: ref,
        applicationId: 'owner',
        kind: kind,
        bytes: picked.bytes,
        contentType: type,
      );
      final label = path ?? kind;
      final current = ref.read(ownerDocsProvider);
      ref.read(ownerDocsProvider.notifier).set(switch (kind) {
        'pan' => current.copyWith(pan: label),
        'aadhaar' => current.copyWith(aadhaar: label),
        _ => current.copyWith(ownership: label),
      });
    } on PhotoPickUnavailable {
      return;
    }
  }
}

class _Doc extends StatelessWidget {
  const _Doc({
    required this.rowKey,
    required this.title,
    required this.done,
    required this.onTap,
  });

  final Key rowKey;
  final String title;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      leading: Icon(
        done ? Icons.verified : Icons.upload_file_outlined,
        color: done ? HomiziColors.success : HomiziColors.logoOrange,
      ),
      title: Text(
        homiziText(context, title),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Text(
        homiziText(context, done ? 'Added' : 'Upload'),
        style: TextStyle(
          color: done ? HomiziColors.success : HomiziColors.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
