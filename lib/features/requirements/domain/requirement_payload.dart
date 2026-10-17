import 'package:homizi/features/requirements/domain/requirement_draft.dart';

const requirementInsertColumns = <String>[
  'id',
  'user_id',
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'occupancy',
  'property_types',
  'furnishing',
  'lifestyle',
];

const requirementUpdateColumns = <String>[
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'move_in_date',
  'occupancy',
  'property_types',
  'furnishing',
  'lifestyle',
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
    'property_types': [draft.propertyType],
    'furnishing': draft.furnishing,
    'lifestyle': draft.lifestyle,
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
    'property_types': [draft.propertyType],
    'furnishing': draft.furnishing,
    'lifestyle': draft.lifestyle,
  };
}

RequirementDraft requirementDraftFromRow(Map<String, dynamic> row) {
  final localities = row['localities'];
  final locality = localities is List && localities.isNotEmpty
      ? localities.first.toString()
      : '';
  final occupancy = _asInt(row['occupancy']);
  final propertyType = _firstText(row['property_types']);
  final furnishing = row['furnishing'] is String
      ? row['furnishing'] as String
      : '';
  return RequirementDraft(
    id: row['id'] as String?,
    budgetMinInr: _asInt(row['budget_min_inr']),
    budgetMaxInr: _asInt(row['budget_max_inr']),
    city: row['city'] is String ? row['city'] as String : '',
    locality: locality,
    moveInDate: parseIsoDate(row['move_in_date']),
    occupancy: occupancy == null || occupancy < 1 ? 1 : occupancy,
    propertyType: requirementPropertyTypes.contains(propertyType)
        ? propertyType
        : 'apartment',
    furnishing: requirementFurnishings.contains(furnishing)
        ? furnishing
        : 'semi_furnished',
    lifestyle: _lifestyle(row['lifestyle']),
  );
}

String _firstText(Object? value) {
  if (value is List && value.isNotEmpty) {
    return value.first.toString();
  }
  if (value is String) {
    return value;
  }
  return '';
}

List<String> _lifestyle(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (requirementLifestyles.contains(item.toString())) item.toString(),
  ];
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
