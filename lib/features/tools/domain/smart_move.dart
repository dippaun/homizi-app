/// Illustrative rent-to-own maths for the "Smart Move" concept page.
///
/// Numbers are educational only. HOMIZI is not offering a financial product.
library;

class SmartMoveInput {
  const SmartMoveInput({
    required this.monthlyRentInr,
    required this.years,
    this.returnShare = 0.70,
  });

  final int monthlyRentInr;
  final int years;

  /// Share of rent that could count back as a return in the concept. Default 70%.
  final double returnShare;
}

class SmartMoveResult {
  const SmartMoveResult({
    required this.monthlyRentInr,
    required this.years,
    required this.months,
    required this.totalRentPaidInr,
    required this.estimatedReturnInr,
    required this.depreciatedInr,
    required this.returnShare,
  });

  final int monthlyRentInr;
  final int years;
  final int months;
  final int totalRentPaidInr;
  final int estimatedReturnInr;
  final int depreciatedInr;
  final double returnShare;
}

/// Total rent paid over [years], with an illustrative return at [returnShare].
SmartMoveResult smartMove(SmartMoveInput input) {
  if (input.monthlyRentInr <= 0) {
    throw ArgumentError('Monthly rent must be more than zero.');
  }
  if (input.years <= 0 || input.years > 30) {
    throw ArgumentError('Years must be between 1 and 30.');
  }
  if (input.returnShare < 0 || input.returnShare > 1) {
    throw ArgumentError('Return share must be between 0 and 1.');
  }

  final months = input.years * 12;
  final paid = input.monthlyRentInr * months;
  final returned = (paid * input.returnShare).round();
  final lost = paid - returned;

  return SmartMoveResult(
    monthlyRentInr: input.monthlyRentInr,
    years: input.years,
    months: months,
    totalRentPaidInr: paid,
    estimatedReturnInr: returned,
    depreciatedInr: lost,
    returnShare: input.returnShare,
  );
}

/// Growing-city flat price band named in the concept notes.
const smartMoveFlatMinLakh = 15;
const smartMoveFlatMaxLakh = 30;

const smartMoveCities = <String>[
  'Ahmedabad',
  'Surat',
  'Indore',
  'Jaipur',
  'Nagpur',
  'Coimbatore',
  'Lucknow',
  'Bhopal',
];

class SmartMoveInterest {
  const SmartMoveInterest({
    required this.name,
    required this.city,
    required this.contact,
    required this.monthlyRentInr,
    required this.notes,
    required this.savedAt,
  });

  final String name;
  final String city;
  final String contact;
  final int monthlyRentInr;
  final String notes;
  final DateTime savedAt;
}

/// Session-only interest list. Nothing leaves the device.
class SmartMoveInterestStore {
  SmartMoveInterestStore._();

  static final SmartMoveInterestStore instance = SmartMoveInterestStore._();

  final List<SmartMoveInterest> _rows = <SmartMoveInterest>[];

  List<SmartMoveInterest> get rows => List.unmodifiable(_rows);

  void clear() => _rows.clear();

  String? validate({
    required String name,
    required String city,
    required String contact,
    required int? monthlyRentInr,
  }) {
    if (name.trim().isEmpty) {
      return 'Enter your name.';
    }
    if (city.trim().isEmpty) {
      return 'Pick a city.';
    }
    if (contact.trim().isEmpty) {
      return 'Enter a phone or email so we can reach you.';
    }
    if (monthlyRentInr == null || monthlyRentInr <= 0) {
      return 'Enter your current monthly rent in whole rupees.';
    }
    return null;
  }

  SmartMoveInterest save({
    required String name,
    required String city,
    required String contact,
    required int monthlyRentInr,
    String notes = '',
  }) {
    final problem = validate(
      name: name,
      city: city,
      contact: contact,
      monthlyRentInr: monthlyRentInr,
    );
    if (problem != null) {
      throw ArgumentError(problem);
    }
    final row = SmartMoveInterest(
      name: name.trim(),
      city: city.trim(),
      contact: contact.trim(),
      monthlyRentInr: monthlyRentInr,
      notes: notes.trim(),
      savedAt: DateTime.now().toUtc(),
    );
    _rows.insert(0, row);
    return row;
  }
}
