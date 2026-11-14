import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/personalize/personalization.dart';

const roleSetupPreferenceKey = 'flutter.homizi.role_setup';

const ownerPropertyTypes = <String, String>{
  'apartment': 'Apartment',
  'house': 'Independent house',
  'villa': 'Villa',
  'builder': 'Builder floor',
};

const ownerPropertyCounts = <String, String>{
  '1': 'Just one',
  'few': '2 to 5',
  'many': '6 or more',
};

const sharerRoomKinds = <String, String>{
  'private': 'Private room',
  'shared': 'Shared room',
};

const sharerGenders = <String, String>{
  'any': 'No preference',
  'women': 'Women',
  'men': 'Men',
};

const sharerFood = <String, String>{
  'any': 'No preference',
  'veg': 'Vegetarian',
  'egg': 'Eggetarian',
};

const sharerSmoking = <String, String>{
  'no': 'Non-smoker',
  'ok': 'Smoking is ok',
};

const sharerBudgetShares = <String, String>{
  'under8': 'Under ₹8,000',
  '8to15': '₹8,000 – ₹15,000',
  'over15': 'Above ₹15,000',
};

class RoleSetup {
  const RoleSetup({
    this.propertyType = '',
    this.propertyCount = '',
    this.agencyName = '',
    this.rera = '',
    this.cities = const [],
    this.locality = '',
    this.roomKind = '',
    this.gender = 'any',
    this.food = 'any',
    this.smoking = 'no',
    this.budgetShare = '',
  });

  final String propertyType;
  final String propertyCount;
  final String agencyName;
  final String rera;
  final List<String> cities;
  final String locality;
  final String roomKind;
  final String gender;
  final String food;
  final String smoking;
  final String budgetShare;

  RoleSetup copyWith({
    String? propertyType,
    String? propertyCount,
    String? agencyName,
    String? rera,
    List<String>? cities,
    String? locality,
    String? roomKind,
    String? gender,
    String? food,
    String? smoking,
    String? budgetShare,
  }) {
    return RoleSetup(
      propertyType: propertyType ?? this.propertyType,
      propertyCount: propertyCount ?? this.propertyCount,
      agencyName: agencyName ?? this.agencyName,
      rera: rera ?? this.rera,
      cities: cities ?? this.cities,
      locality: locality ?? this.locality,
      roomKind: roomKind ?? this.roomKind,
      gender: gender ?? this.gender,
      food: food ?? this.food,
      smoking: smoking ?? this.smoking,
      budgetShare: budgetShare ?? this.budgetShare,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'propertyType': propertyType,
      'propertyCount': propertyCount,
      'agencyName': agencyName,
      'rera': rera,
      'cities': cities,
      'locality': locality,
      'roomKind': roomKind,
      'gender': gender,
      'food': food,
      'smoking': smoking,
      'budgetShare': budgetShare,
    };
  }

  static RoleSetup? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final cities = decoded['cities'];
      return RoleSetup(
        propertyType: _known(decoded['propertyType'], ownerPropertyTypes),
        propertyCount: _known(decoded['propertyCount'], ownerPropertyCounts),
        agencyName: decoded['agencyName'] is String
            ? decoded['agencyName'] as String
            : '',
        rera: decoded['rera'] is String ? decoded['rera'] as String : '',
        cities: cities is List
            ? [
                for (final city in cities)
                  if (city is String && personalCities.contains(city)) city,
              ]
            : const [],
        locality: decoded['locality'] is String
            ? decoded['locality'] as String
            : '',
        roomKind: _known(decoded['roomKind'], sharerRoomKinds),
        gender: _known(decoded['gender'], sharerGenders, fallback: 'any'),
        food: _known(decoded['food'], sharerFood, fallback: 'any'),
        smoking: _known(decoded['smoking'], sharerSmoking, fallback: 'no'),
        budgetShare: _known(decoded['budgetShare'], sharerBudgetShares),
      );
    } on FormatException {
      return null;
    }
  }
}

String _known(
  Object? value,
  Map<String, String> options, {
  String fallback = '',
}) {
  if (value is String && options.containsKey(value)) {
    return value;
  }
  return fallback;
}

class RoleSetupController extends Notifier<RoleSetup> {
  var _generation = 0;

  @override
  RoleSetup build() {
    final generation = ++_generation;
    unawaited(_restore(generation));
    return const RoleSetup();
  }

  Future<void> _restore(int generation) async {
    final raw = await readDeviceString(roleSetupPreferenceKey);
    if (generation != _generation || !ref.mounted || raw == null) {
      return;
    }
    final parsed = RoleSetup.tryParse(raw);
    if (parsed != null) {
      state = parsed;
    }
  }

  void setPropertyType(String value) {
    state = state.copyWith(propertyType: value);
    _persist();
  }

  void setPropertyCount(String value) {
    state = state.copyWith(propertyCount: value);
    _persist();
  }

  void setAgencyName(String value) =>
      _update(state.copyWith(agencyName: value));

  void setRera(String value) => _update(state.copyWith(rera: value));

  void toggleCity(String city) {
    final next = [...state.cities];
    if (next.contains(city)) {
      next.remove(city);
    } else {
      next.add(city);
    }
    _update(state.copyWith(cities: next));
  }

  void setLocality(String value) => _update(state.copyWith(locality: value));

  void setRoomKind(String value) => _update(state.copyWith(roomKind: value));

  void setGender(String value) => _update(state.copyWith(gender: value));

  void setFood(String value) => _update(state.copyWith(food: value));

  void setSmoking(String value) => _update(state.copyWith(smoking: value));

  void setBudgetShare(String value) =>
      _update(state.copyWith(budgetShare: value));

  void _update(RoleSetup next) {
    state = next;
    _persist();
  }

  void _persist() {
    final raw = jsonEncode(state.toJson());
    unawaited(writeDeviceString(roleSetupPreferenceKey, raw));
  }
}

final roleSetupProvider = NotifierProvider<RoleSetupController, RoleSetup>(
  RoleSetupController.new,
);
