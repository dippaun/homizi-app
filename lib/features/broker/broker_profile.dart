import 'package:homizi/features/discovery/data/locality_seed.dart';

final brokerReraPattern = RegExp(r'^[A-Za-z0-9/-]{5,40}$');

class BrokerProfileDraft {
  const BrokerProfileDraft({
    this.fullName = '',
    this.agencyName = '',
    this.reraNumber = '',
    this.cities = const [],
    this.localities = const [],
    this.phone = '',
    this.yearsExperience = 0,
  });

  final String fullName;
  final String agencyName;
  final String reraNumber;
  final List<String> cities;
  final List<String> localities;
  final String phone;
  final int yearsExperience;

  String? get phoneE164 {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits)) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      if (RegExp(r'^[6-9][0-9]{9}$').hasMatch(local)) {
        return '+91$local';
      }
    }
    return null;
  }

  List<String> errors() {
    final issues = <String>[];
    if (fullName.trim().length < 2) {
      issues.add('Enter your name.');
    }
    if (agencyName.trim().length < 2) {
      issues.add('Enter the agency name.');
    }
    final rera = reraNumber.trim();
    if (rera.isNotEmpty && !brokerReraPattern.hasMatch(rera)) {
      issues.add('RERA number should be 5 to 40 letters, digits, or slashes.');
    }
    if (cities.isEmpty) {
      issues.add('Choose at least one city.');
    }
    if (cities.any((city) => !exploreCities.contains(city))) {
      issues.add('Choose a city from the list.');
    }
    if (localities.every((item) => item.trim().isEmpty)) {
      issues.add('Add at least one locality.');
    }
    if (phoneE164 == null) {
      issues.add('Enter a 10-digit Indian mobile number.');
    }
    if (yearsExperience < 0 || yearsExperience > 60) {
      issues.add('Years of experience must be between 0 and 60.');
    }
    return issues;
  }
}

abstract interface class BrokerGateway {
  Future<BrokerProfileDraft?> load();

  Future<void> save(BrokerProfileDraft draft);
}
