import 'package:homizi/features/tools/domain/deposit_math.dart';

final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

const paymentModes = <String>['upi', 'bank_transfer', 'cash', 'cheque'];

const inventoryRooms = <String>[
  'Living room',
  'Bedroom',
  'Kitchen',
  'Bathroom',
  'Balcony',
];

const inventoryConditions = <String>['good', 'fair', 'worn', 'damaged'];

String paymentModeLabel(String mode) {
  return switch (mode) {
    'upi' => 'UPI',
    'bank_transfer' => 'Bank transfer',
    'cash' => 'Cash',
    'cheque' => 'Cheque',
    _ => mode,
  };
}

String conditionLabel(String condition) {
  return switch (condition) {
    'good' => 'Good',
    'fair' => 'Fair',
    'worn' => 'Worn',
    'damaged' => 'Damaged',
    _ => condition,
  };
}

const monthLabels = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monthSpan(DateTime start, DateTime end) {
  final from = '${monthLabels[start.month - 1]} ${start.year}';
  final to = '${monthLabels[end.month - 1]} ${end.year}';
  if (from == to) {
    return from;
  }
  return '$from – $to';
}

String? normalizePan(String raw) {
  final trimmed = raw.trim().toUpperCase();
  if (trimmed.isEmpty) {
    return null;
  }
  if (!panPattern.hasMatch(trimmed)) {
    return '';
  }
  return trimmed;
}

DateTime? parseDay(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) {
    return null;
  }
  return date;
}

int? wholeRupees(String raw) {
  final trimmed = raw.trim().replaceAll(',', '');
  if (trimmed.isEmpty) {
    return null;
  }
  final value = int.tryParse(trimmed);
  if (value == null || value < 0) {
    return null;
  }
  return value;
}

class RentReceipt {
  const RentReceipt({
    required this.id,
    required this.tenantName,
    required this.ownerName,
    required this.propertyAddress,
    required this.monthlyRentInr,
    required this.periodStart,
    required this.periodEnd,
    required this.paymentMode,
    this.ownerPan,
    required this.createdAt,
  });

  final String id;
  final String tenantName;
  final String ownerName;
  final String propertyAddress;
  final int monthlyRentInr;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? ownerPan;
  final String paymentMode;
  final DateTime createdAt;
}

String? receiptError({
  required String tenantName,
  required String ownerName,
  required String propertyAddress,
  required int? monthlyRentInr,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String? ownerPan,
  required String paymentMode,
}) {
  if (tenantName.trim().length < 2 || tenantName.trim().length > 80) {
    return 'Enter the tenant name, between 2 and 80 characters.';
  }
  if (ownerName.trim().length < 2 || ownerName.trim().length > 80) {
    return 'Enter the owner name, between 2 and 80 characters.';
  }
  if (propertyAddress.trim().length < 8 ||
      propertyAddress.trim().length > 240) {
    return 'Enter the property address, between 8 and 240 characters.';
  }
  if (monthlyRentInr == null ||
      monthlyRentInr < 1 ||
      monthlyRentInr > 10000000) {
    return 'Enter the monthly rent in whole rupees.';
  }
  final startKey = periodStart.year * 12 + periodStart.month;
  final endKey = periodEnd.year * 12 + periodEnd.month;
  if (endKey < startKey) {
    return 'The end month cannot be before the start month.';
  }
  if (ownerPan != null && !panPattern.hasMatch(ownerPan)) {
    return 'Owner PAN must look like ABCDE1234F, or stay blank.';
  }
  if (!paymentModes.contains(paymentMode)) {
    return 'Choose a payment mode.';
  }
  return null;
}

/// Shown on the draft PDF and on the agreement screen.
const agreementWatermark =
    'Draft – not stamped or registered, for reference only';

class AgreementDraft {
  const AgreementDraft({
    required this.id,
    required this.licensorName,
    required this.licenseeName,
    required this.propertyAddress,
    required this.city,
    required this.monthlyRentInr,
    required this.depositInr,
    required this.maintenanceInr,
    required this.startDate,
    this.termMonths = 11,
    required this.createdAt,
  });

  final String id;
  final String licensorName;
  final String licenseeName;
  final String propertyAddress;
  final String city;
  final int monthlyRentInr;
  final int depositInr;
  final int maintenanceInr;
  final DateTime startDate;
  final int termMonths;
  final DateTime createdAt;

  DateTime get endDate {
    final month = startDate.month + termMonths;
    final year = startDate.year + ((month - 1) ~/ 12);
    final wrapped = ((month - 1) % 12) + 1;
    final day = startDate.day;
    final last = DateTime(year, wrapped + 1, 0).day;
    return DateTime(year, wrapped, day > last ? last : day);
  }
}

String? agreementError({
  required String licensorName,
  required String licenseeName,
  required String propertyAddress,
  required String city,
  required int? monthlyRentInr,
  required int? depositInr,
  required int? maintenanceInr,
}) {
  if (licensorName.trim().length < 2 || licensorName.trim().length > 80) {
    return 'Enter the licensor name, between 2 and 80 characters.';
  }
  if (licenseeName.trim().length < 2 || licenseeName.trim().length > 80) {
    return 'Enter the licensee name, between 2 and 80 characters.';
  }
  if (propertyAddress.trim().length < 8 ||
      propertyAddress.trim().length > 240) {
    return 'Enter the property address, between 8 and 240 characters.';
  }
  if (city.trim().length < 2 || city.trim().length > 40) {
    return 'Enter the city.';
  }
  if (monthlyRentInr == null ||
      monthlyRentInr < 1 ||
      monthlyRentInr > 10000000) {
    return 'Enter the monthly rent in whole rupees.';
  }
  if (depositInr == null || depositInr < 0) {
    return 'Enter the deposit in whole rupees, or 0.';
  }
  if (maintenanceInr == null || maintenanceInr < 0) {
    return 'Enter the maintenance in whole rupees, or 0.';
  }
  return null;
}

List<String> agreementParagraphs(AgreementDraft draft) {
  final start = _longDate(draft.startDate);
  final end = _longDate(draft.endDate);
  return [
    'This leave and licence is a draft for ${draft.termMonths} months.',
    'Licensor: ${draft.licensorName.trim()}.',
    'Licensee: ${draft.licenseeName.trim()}.',
    'Premises: ${draft.propertyAddress.trim()}, ${draft.city.trim()}.',
    'The licence fee is ${draft.monthlyRentInr} rupees each month.',
    'The interest-free deposit is ${draft.depositInr} rupees.',
    'Maintenance noted here is ${draft.maintenanceInr} rupees each month.',
    'The term starts on $start and runs for 11 months, ending on $end.',
    'The licensee may use the premises as a residence. This draft does not transfer ownership.',
    agreementWatermark,
  ];
}

String _longDate(DateTime date) {
  return '${date.day} ${monthLabels[date.month - 1]} ${date.year}';
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.room,
    required this.name,
    required this.condition,
    this.notes = '',
    this.photoPath,
    this.photoBytes,
  });

  final String id;
  final String room;
  final String name;
  final String condition;
  final String notes;
  final String? photoPath;
  final List<int>? photoBytes;

  InventoryItem copyWith({
    String? notes,
    String? photoPath,
    List<int>? photoBytes,
    String? condition,
  }) {
    return InventoryItem(
      id: id,
      room: room,
      name: name,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      photoBytes: photoBytes ?? this.photoBytes,
    );
  }
}

class MoveInChecklist {
  const MoveInChecklist({
    required this.id,
    required this.title,
    required this.ownedByMe,
    this.matchId,
    this.items = const [],
  });

  final String id;
  final String title;
  final bool ownedByMe;
  final String? matchId;
  final List<InventoryItem> items;

  MoveInChecklist copyWith({
    String? matchId,
    bool clearMatch = false,
    List<InventoryItem>? items,
  }) {
    return MoveInChecklist(
      id: id,
      title: title,
      ownedByMe: ownedByMe,
      matchId: clearMatch ? null : (matchId ?? this.matchId),
      items: items ?? this.items,
    );
  }
}

class DepositTracker {
  const DepositTracker({
    required this.id,
    required this.propertyLabel,
    required this.depositPaidInr,
    this.refundDueOn,
    this.deductions = const [],
  });

  final String id;
  final String propertyLabel;
  final int depositPaidInr;
  final DateTime? refundDueOn;
  final List<DepositDeduction> deductions;

  int get deductionsInr =>
      deductionTotal(deductions.map((item) => item.amountInr));

  int get refundInr => refundDueInr(depositPaidInr, deductionsInr);
}
