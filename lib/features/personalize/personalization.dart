import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

const personalizationPreferenceKey = 'flutter.homizi.personalization';

const personalCities = <String>[
  'Ahmedabad',
  'Bengaluru',
  'Chennai',
  'Delhi NCR',
  'Hyderabad',
  'Jaipur',
  'Kochi',
  'Kolkata',
  'Mumbai',
  'Pune',
];

const personalLookingFor = <String, String>{
  'home': 'A whole home',
  'room': 'A private room',
  'flatmate': 'A flatmate',
  'tenants': 'Tenants for my property',
  'commercial': 'A commercial space',
};

/// User-picked bands. These are not listing prices.
const personalBudgets = <({String id, String label, int? min, int? max})>[
  (id: 'unsure', label: 'Not sure yet', min: null, max: null),
  (id: 'under15', label: 'Under ₹15,000', min: null, max: 15000),
  (id: '15to30', label: '₹15,000 – ₹30,000', min: 15000, max: 30000),
  (id: '30to50', label: '₹30,000 – ₹50,000', min: 30000, max: 50000),
  (id: 'over50', label: 'Above ₹50,000', min: 50000, max: null),
];

const personalPreferenceChoices = <String, String>{
  'furnished': 'Furnished',
  'pets_ok': 'Pets ok',
  'non_smoker': 'Non-smoker',
  'wfh': 'Work from home',
  'couple_friendly': 'Couple friendly',
};

class Personalization {
  const Personalization({
    this.roleWire,
    this.city = '',
    this.lookingFor = '',
    this.budgetMin,
    this.budgetMax,
    this.preferences = const [],
    this.language = 'en',
    this.theme = 'light',
    this.skipped = false,
    this.copied = false,
    this.locationNote = '',
  });

  final String? roleWire;
  final String city;
  final String lookingFor;
  final int? budgetMin;
  final int? budgetMax;
  final List<String> preferences;
  final String language;
  final String theme;
  final bool skipped;
  final bool copied;
  final String locationNote;

  bool get hasChoices =>
      (roleWire != null && roleWire!.isNotEmpty) || city.trim().isNotEmpty;

  Personalization copyWith({
    String? roleWire,
    String? city,
    String? lookingFor,
    int? budgetMin,
    int? budgetMax,
    List<String>? preferences,
    String? language,
    String? theme,
    bool? skipped,
    bool? copied,
    String? locationNote,
    bool clearRole = false,
    bool clearBudgetMin = false,
    bool clearBudgetMax = false,
  }) {
    return Personalization(
      roleWire: clearRole ? null : (roleWire ?? this.roleWire),
      city: city ?? this.city,
      lookingFor: lookingFor ?? this.lookingFor,
      budgetMin: clearBudgetMin ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudgetMax ? null : (budgetMax ?? this.budgetMax),
      preferences: preferences ?? this.preferences,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      skipped: skipped ?? this.skipped,
      copied: copied ?? this.copied,
      locationNote: locationNote ?? this.locationNote,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'role': roleWire,
      'city': city,
      'lookingFor': lookingFor,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'preferences': preferences,
      'language': language,
      'theme': theme,
      'skipped': skipped,
      'copied': copied,
      'locationNote': locationNote,
    };
  }

  static Personalization? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final prefs = decoded['preferences'];
      return Personalization(
        roleWire: _role(decoded['role']),
        city: decoded['city'] is String ? decoded['city'] as String : '',
        lookingFor: decoded['lookingFor'] is String
            ? decoded['lookingFor'] as String
            : '',
        budgetMin: _int(decoded['budgetMin']),
        budgetMax: _int(decoded['budgetMax']),
        preferences: prefs is List
            ? [
                for (final item in prefs)
                  if (item is String &&
                      personalPreferenceChoices.containsKey(item))
                    item,
              ]
            : const [],
        language: decoded['language'] == 'hi' ? 'hi' : 'en',
        theme: decoded['theme'] == 'dark' ? 'dark' : 'light',
        skipped: decoded['skipped'] == true,
        copied: decoded['copied'] == true,
        locationNote: decoded['locationNote'] is String
            ? decoded['locationNote'] as String
            : '',
      );
    } on FormatException {
      return null;
    }
  }
}

String? _role(Object? value) {
  if (value is! String) {
    return null;
  }
  return switch (value) {
    'tenant' || 'host' || 'broker' || 'roommate' => value,
    _ => null,
  };
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

class PersonalizationController extends Notifier<Personalization> {
  int _generation = 0;
  bool deviceWriteOk = true;

  @override
  Personalization build() {
    final generation = ++_generation;
    ref.listen(sessionProvider, (previous, next) {
      if (next.phase == SessionPhase.ready &&
          previous?.phase != SessionPhase.ready) {
        unawaited(copyIntoAccount());
      }
    });
    unawaited(_restore(generation));
    return const Personalization();
  }

  Future<void> _restore(int generation) async {
    final raw = await readDeviceString(personalizationPreferenceKey);
    if (generation != _generation || !ref.mounted || raw == null) {
      return;
    }
    final parsed = Personalization.tryParse(raw);
    if (parsed == null) {
      return;
    }
    state = parsed;
    _applyChrome(parsed);
    await copyIntoAccount();
  }

  void setRole(String wire) {
    state = state.copyWith(roleWire: wire, skipped: false, copied: false);
  }

  void setCity(String city) {
    state = state.copyWith(city: city, skipped: false, copied: false);
  }

  void setLookingFor(String value) {
    state = state.copyWith(lookingFor: value, skipped: false, copied: false);
  }

  void setBudget(int? min, int? max) {
    state = state.copyWith(
      budgetMin: min,
      budgetMax: max,
      clearBudgetMin: min == null,
      clearBudgetMax: max == null,
      skipped: false,
      copied: false,
    );
  }

  void togglePreference(String token) {
    final next = [...state.preferences];
    if (next.contains(token)) {
      next.remove(token);
    } else {
      next.add(token);
    }
    state = state.copyWith(preferences: next, skipped: false, copied: false);
  }

  void setLanguage(String code) {
    final language = code == 'hi' ? 'hi' : 'en';
    state = state.copyWith(language: language, copied: false);
    ref.read(localeProvider.notifier).setCode(language);
  }

  void setTheme(String theme) {
    state = state.copyWith(
      theme: theme == 'dark' ? 'dark' : 'light',
      copied: false,
    );
  }

  void setLocationNote(String note) {
    state = state.copyWith(locationNote: note);
  }

  Future<String?> skip() async {
    state = state.copyWith(skipped: true);
    await _persist();
    return null;
  }

  /// Returns an error sentence, or null when the choices are stored.
  Future<String?> save() async {
    if (state.roleWire == null) {
      return 'Choose how you will use HOMIZI.';
    }
    if (state.city.trim().length < 2) {
      return 'Choose a city, or type one.';
    }
    state = state.copyWith(skipped: false, copied: false);
    await _persist();
    return copyIntoAccount();
  }

  /// Copies a stored role and budget into the account once a session exists.
  /// An existing account role is left as it is.
  Future<String?> copyIntoAccount() async {
    if (state.copied || state.roleWire == null) {
      return null;
    }
    final session = ref.read(sessionProvider);
    final signedIn =
        session.phase == SessionPhase.ready ||
        session.phase == SessionPhase.needsRole;
    if (!signedIn) {
      return null;
    }
    try {
      if (session.homiziWire == null || session.homiziWire!.isEmpty) {
        final error = await ref
            .read(sessionProvider.notifier)
            .selectPrimaryRole(state.roleWire!);
        if (error != null) {
          return error;
        }
      }
      final gateway = ref.read(accountGatewayProvider);
      final profile = await gateway.loadTenantProfile();
      if (profile.preferences.isBlank && _hasPreferenceCopy) {
        await gateway.saveTenantProfile(
          profile.copyWith(preferences: _preferencesFrom(profile.preferences)),
        );
      }
    } on AccountFailure catch (error) {
      return error.message;
    }
    if (!ref.mounted) {
      return null;
    }
    state = state.copyWith(copied: true);
    await _persist();
    return null;
  }

  bool get _hasPreferenceCopy =>
      state.city.trim().isNotEmpty ||
      state.budgetMin != null ||
      state.budgetMax != null ||
      state.preferences.isNotEmpty;

  TenantPreferences _preferencesFrom(TenantPreferences current) {
    const lifestyleKeys = {'pets_ok', 'non_smoker', 'wfh'};
    return current.copyWith(
      budgetMinInr: state.budgetMin,
      budgetMaxInr: state.budgetMax,
      localities: state.city.trim().isEmpty ? const [] : [state.city.trim()],
      lifestyle: [
        for (final token in state.preferences)
          if (lifestyleKeys.contains(token)) token,
      ],
    );
  }

  void _applyChrome(Personalization value) {
    ref.read(localeProvider.notifier).setCode(value.language);
  }

  Future<void> _persist() async {
    deviceWriteOk = await writeDeviceString(
      personalizationPreferenceKey,
      jsonEncode(state.toJson()),
    );
  }
}

final personalizationProvider =
    NotifierProvider<PersonalizationController, Personalization>(
      PersonalizationController.new,
    );

final themeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(personalizationProvider).theme;
  return theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
});
