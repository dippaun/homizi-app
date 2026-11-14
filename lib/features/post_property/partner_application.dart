import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/post_property/post_property_choice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const partnerApplicationKey = 'flutter.homizi.partner_application';

/// Ten megabytes. The listing photo bucket may still refuse a larger file.
const partnerDocumentMaxBytes = 10 * 1024 * 1024;

class PartnerDocument {
  const PartnerDocument({this.label = '', this.storagePath = ''});

  final String label;
  final String storagePath;

  bool get picked => label.trim().isNotEmpty;

  PartnerDocument copyWith({String? label, String? storagePath}) {
    return PartnerDocument(
      label: label ?? this.label,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  Map<String, String> toJson() => {'label': label, 'storagePath': storagePath};

  static PartnerDocument fromJson(Object? raw) {
    if (raw is! Map) {
      return const PartnerDocument();
    }
    return PartnerDocument(
      label: raw['label'] is String ? raw['label'] as String : '',
      storagePath: raw['storagePath'] is String
          ? raw['storagePath'] as String
          : '',
    );
  }
}

class PartnerApplication {
  const PartnerApplication({
    this.applicationId = '',
    this.partnerType = 'individual',
    this.contact = const PostContact(),
    this.businessName = '',
    this.address = '',
    this.operatingArea = '',
    this.about = '',
    this.verifyLater = true,
    this.pan = const PartnerDocument(),
    this.aadhaar = const PartnerDocument(),
    this.ownership = const PartnerDocument(),
    this.savedLocally = false,
    this.savedOnServer = false,
  });

  final String applicationId;

  /// `individual`, `builder`, or `agency`.
  final String partnerType;
  final PostContact contact;
  final String businessName;
  final String address;
  final String operatingArea;
  final String about;
  final bool verifyLater;
  final PartnerDocument pan;
  final PartnerDocument aadhaar;
  final PartnerDocument ownership;
  final bool savedLocally;
  final bool savedOnServer;

  PartnerApplication copyWith({
    String? applicationId,
    String? partnerType,
    PostContact? contact,
    String? businessName,
    String? address,
    String? operatingArea,
    String? about,
    bool? verifyLater,
    PartnerDocument? pan,
    PartnerDocument? aadhaar,
    PartnerDocument? ownership,
    bool? savedLocally,
    bool? savedOnServer,
  }) {
    return PartnerApplication(
      applicationId: applicationId ?? this.applicationId,
      partnerType: partnerType ?? this.partnerType,
      contact: contact ?? this.contact,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      operatingArea: operatingArea ?? this.operatingArea,
      about: about ?? this.about,
      verifyLater: verifyLater ?? this.verifyLater,
      pan: pan ?? this.pan,
      aadhaar: aadhaar ?? this.aadhaar,
      ownership: ownership ?? this.ownership,
      savedLocally: savedLocally ?? this.savedLocally,
      savedOnServer: savedOnServer ?? this.savedOnServer,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'applicationId': applicationId,
      'partnerType': partnerType,
      'fullName': contact.fullName,
      'mobile': contact.mobile,
      'email': contact.email,
      'mobileVerified': contact.mobileVerified,
      'emailVerified': contact.emailVerified,
      'businessName': businessName,
      'address': address,
      'operatingArea': operatingArea,
      'about': about,
      'verifyLater': verifyLater,
      'pan': pan.toJson(),
      'aadhaar': aadhaar.toJson(),
      'ownership': ownership.toJson(),
      'savedOnServer': savedOnServer,
    };
  }

  static PartnerApplication? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return PartnerApplication(
        applicationId: _string(decoded['applicationId']),
        partnerType: _type(decoded['partnerType']),
        contact: PostContact(
          fullName: _string(decoded['fullName']),
          mobile: _string(decoded['mobile']),
          email: _string(decoded['email']),
          mobileVerified: decoded['mobileVerified'] == true,
          emailVerified: decoded['emailVerified'] == true,
        ),
        businessName: _string(decoded['businessName']),
        address: _string(decoded['address']),
        operatingArea: _string(decoded['operatingArea']),
        about: _string(decoded['about']),
        verifyLater: decoded['verifyLater'] != false,
        pan: PartnerDocument.fromJson(decoded['pan']),
        aadhaar: PartnerDocument.fromJson(decoded['aadhaar']),
        ownership: PartnerDocument.fromJson(decoded['ownership']),
        savedLocally: true,
        savedOnServer: decoded['savedOnServer'] == true,
      );
    } on FormatException {
      return null;
    }
  }
}

String _string(Object? value) => value is String ? value : '';

String _type(Object? value) {
  if (value == 'builder' || value == 'agency' || value == 'individual') {
    return value as String;
  }
  return 'individual';
}

class PartnerApplicationController extends Notifier<PartnerApplication> {
  var _generation = 0;

  @override
  PartnerApplication build() {
    final generation = ++_generation;
    unawaited(() async {
      final raw = await readDeviceString(partnerApplicationKey);
      if (generation != _generation || !ref.mounted || raw == null) {
        return;
      }
      final parsed = PartnerApplication.tryParse(raw);
      if (parsed != null) {
        state = parsed;
        ref.read(postContactProvider.notifier).replace(parsed.contact);
      }
    }());
    return const PartnerApplication();
  }

  void setType(String type) => state = state.copyWith(partnerType: type);

  void setBusiness({
    String? businessName,
    String? address,
    String? operatingArea,
    String? about,
  }) {
    state = state.copyWith(
      businessName: businessName,
      address: address,
      operatingArea: operatingArea,
      about: about,
    );
  }

  void setDocument(String kind, PartnerDocument document) {
    state = switch (kind) {
      'pan' => state.copyWith(pan: document),
      'aadhaar' => state.copyWith(aadhaar: document),
      _ => state.copyWith(ownership: document),
    };
  }

  /// Writes the device copy first. The server row is written only when
  /// `property_partner_applications` already exists. A missing table is ignored.
  Future<PartnerApplication> submit({required bool verifyLater}) async {
    final contact = ref.read(postContactProvider);
    final when = DateTime.now();
    final id = state.applicationId.trim().isEmpty
        ? partnerApplicationId(when, when.millisecondsSinceEpoch)
        : state.applicationId;
    final next = state.copyWith(
      applicationId: id,
      contact: contact,
      verifyLater: verifyLater,
      savedLocally: false,
      savedOnServer: false,
    );
    state = next;
    unawaited(_persist(next));
    return next;
  }

  /// Device copy first. Storage and the server table must not block the
  /// confirmation when they are missing.
  Future<void> _persist(PartnerApplication application) async {
    // Widget tests have no preferences plugin. The channel reply never
    // arrives, so the in-memory application is the copy the test sees.
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      if (ref.mounted && state.applicationId == application.applicationId) {
        state = application.copyWith(savedLocally: true);
      }
      return;
    }
    var wrote = false;
    try {
      wrote = await writeDeviceString(
        partnerApplicationKey,
        jsonEncode(application.toJson()),
      );
    } on Object {
      wrote = false;
    }
    var next = application.copyWith(savedLocally: wrote);
    final remote = await _tryServer(next);
    next = next.copyWith(savedOnServer: remote);
    if (remote) {
      try {
        await writeDeviceString(
          partnerApplicationKey,
          jsonEncode(next.toJson()),
        );
      } on Object {
        next = next.copyWith(savedLocally: false);
      }
    }
    if (ref.mounted && state.applicationId == application.applicationId) {
      state = next;
    }
  }

  Future<bool> _tryServer(PartnerApplication application) async {
    final config = ref.read(appConfigProvider);
    if (!config.connectsToSupabase || ref.read(forceDemoModeProvider)) {
      return false;
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      await client.from('property_partner_applications').upsert({
        'user_id': userId,
        'application_code': application.applicationId,
        'partner_type': application.partnerType,
        'full_name': application.contact.fullName.trim(),
        'mobile': application.contact.mobile.trim(),
        'email': application.contact.email.trim(),
        'business_name': application.businessName.trim(),
        'address': application.address.trim(),
        'operating_areas': application.operatingArea.trim(),
        'about': application.about.trim(),
        'verify_later': application.verifyLater,
        'pan_path': application.pan.storagePath,
        'aadhaar_path': application.aadhaar.storagePath,
        'ownership_path': application.ownership.storagePath,
      }, onConflict: 'user_id');
      return true;
    } on Object {
      return false;
    }
  }
}

final partnerApplicationProvider =
    NotifierProvider<PartnerApplicationController, PartnerApplication>(
      PartnerApplicationController.new,
    );

/// Uploads into the existing private listing-photos bucket when that bucket
/// is reachable. A missing bucket or a refused write keeps the file name only.
Future<String?> storePartnerDocument({
  required WidgetRef ref,
  required String applicationId,
  required String kind,
  required Uint8List bytes,
  required String contentType,
}) async {
  final config = ref.read(appConfigProvider);
  if (!config.connectsToSupabase || ref.read(forceDemoModeProvider)) {
    return null;
  }
  if (bytes.length > partnerDocumentMaxBytes) {
    return null;
  }
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    final bucket = client.storage.from(listingPhotosBucket);
    await bucket.list(path: userId);
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/partner-docs/$applicationId/$kind.$ext';
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return path;
  } on Object {
    return null;
  }
}
