import 'package:homizi/features/requirements/domain/requirement_draft.dart';

const requirementInsertColumns = <String>[
  'id',
  'user_id',
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'occupancy',
];

const requirementUpdateColumns = <String>[
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'move_in_date',
  'occupancy',
];

String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseIsoDate(Object? value) {
  if (value is! String || value.length < 10) {
    return null;
  }
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

Map<String, dynamic> requirementInsertPayload({
  required String id,
  required String userId,
  required RequirementDraft draft,
}) {
  final payload = <String, dynamic>{
    'id': id,
    'user_id': userId,
    'city': draft.city.trim(),
    'localities': [draft.locality.trim()],
    'budget_min_inr': draft.budgetMinInr,
    'budget_max_inr': draft.budgetMaxInr,
    'occupancy': draft.occupancy,
  };
  final moveIn = draft.moveInDate;
  if (moveIn != null) {
    payload['move_in_date'] = formatIsoDate(moveIn);
  }
  return payload;
}

Map<String, dynamic> requirementUpdatePayload(RequirementDraft draft) {
  return {
    'city': draft.city.trim(),
    'localities': [draft.locality.trim()],
    'budget_min_inr': draft.budgetMinInr,
    'budget_max_inr': draft.budgetMaxInr,
    'move_in_date': draft.moveInDate == null
        ? null
        : formatIsoDate(draft.moveInDate!),
    'occupancy': draft.occupancy,
  };
}

RequirementDraft requirementDraftFromRow(Map<String, dynamic> row) {
  final localities = row['localities'];
  final locality = localities is List && localities.isNotEmpty
      ? localities.first.toString()
      : '';
  final occupancy = _asInt(row['occupancy']);
  return RequirementDraft(
    id: row['id'] as String?,
    budgetMinInr: _asInt(row['budget_min_inr']),
    budgetMaxInr: _asInt(row['budget_max_inr']),
    city: row['city'] is String ? row['city'] as String : '',
    locality: locality,
    moveInDate: parseIsoDate(row['move_in_date']),
    occupancy: occupancy == null || occupancy < 1 ? 1 : occupancy,
  );
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
