import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';

const tenantPhotoLabels = <String>[
  'Room (Main Photo)',
  'Kitchen',
  'WC',
  'Hall',
  'Balcony',
  'Building exterior',
];

String tenantPhotoCaption(int index, int total) {
  final label = index < tenantPhotoLabels.length
      ? tenantPhotoLabels[index]
      : 'Photo ${index + 1}';
  final count = total < 1 ? 1 : total;
  final shown = index + 1 > count ? count : index + 1;
  return '$shown/$count $label';
}

String tenantFlowFactorTitle(TenantFactorId id) {
  return switch (id) {
    TenantFactorId.location => 'Preferred Location',
    _ => tenantFactorTitle(id),
  };
}

String tenantFlowFactorValue(TenantPriorities priorities, TenantFactorId id) {
  return switch (id) {
    TenantFactorId.budget =>
      '${formatInr(priorities.budgetMinInr)} – ${formatInr(priorities.budgetMaxInr)}',
    TenantFactorId.occupancy => switch (priorities.occupancy) {
      'shared' => 'Shared',
      'any' => 'Any',
      _ => 'Single',
    },
    TenantFactorId.location => priorities.localities.join(', '),
    TenantFactorId.moveIn =>
      '${priorities.moveIn.day} ${_month(priorities.moveIn.month)} ${priorities.moveIn.year}',
    TenantFactorId.gender => switch (priorities.gender) {
      'women' => 'Women',
      'men' => 'Men',
      _ => 'Any',
    },
    TenantFactorId.propertyType => 'Flat / PG / Shared Room',
    TenantFactorId.lifestyle => 'Non-smoker, Non-drinker',
    TenantFactorId.furnishing => switch (priorities.furnishing) {
      'semi_furnished' => 'Semi Furnished',
      'unfurnished' => 'Unfurnished',
      _ => 'Furnished',
    },
    TenantFactorId.commute => 'Office commute',
    TenantFactorId.food => switch (priorities.food) {
      'non_veg' => 'Non-veg',
      'any' => 'Any',
      _ => 'Veg',
    },
    TenantFactorId.bathroom => switch (priorities.bathroom) {
      'attached' => 'Attached',
      'private' => 'Private',
      'shared' => 'Shared',
      _ => 'Any',
    },
    TenantFactorId.amenities =>
      priorities.amenities.isEmpty
          ? 'No amenity requirement'
          : priorities.amenities.join(', '),
  };
}

IconData tenantFlowFactorIcon(TenantFactorId id) {
  return switch (id) {
    TenantFactorId.budget => Icons.account_balance_wallet_outlined,
    TenantFactorId.occupancy => Icons.person_outline,
    TenantFactorId.location => Icons.location_on_outlined,
    TenantFactorId.moveIn => Icons.event_outlined,
    TenantFactorId.gender => Icons.wc_outlined,
    TenantFactorId.propertyType => Icons.apartment_outlined,
    TenantFactorId.lifestyle => Icons.spa_outlined,
    TenantFactorId.furnishing => Icons.chair_outlined,
    TenantFactorId.commute => Icons.commute_outlined,
    TenantFactorId.food => Icons.restaurant_outlined,
    TenantFactorId.bathroom => Icons.bathtub_outlined,
    TenantFactorId.amenities => Icons.wifi,
  };
}

String hostFlowFactorValue(HostPriorities priorities, HostFactorId id) {
  return switch (id) {
    HostFactorId.gender => switch (priorities.gender) {
      'women' => 'Women',
      'men' => 'Men',
      _ => 'Any',
    },
    HostFactorId.furnishing => switch (priorities.furnishing) {
      'semi_furnished' => 'Semi Furnished',
      'unfurnished' => 'Unfurnished',
      'any' => 'Any',
      _ => 'Furnished',
    },
    HostFactorId.pets => priorities.petsAllowed ? 'Pets allowed' : 'No pets',
    HostFactorId.workingProfessional => 'Working professional',
    HostFactorId.nonDrinker => 'Non-drinker',
    HostFactorId.nonSmoker => 'Non-smoker',
    HostFactorId.clean => 'Clean and responsible',
    HostFactorId.longStay => 'Long-term stay',
  };
}

IconData hostFlowFactorIcon(HostFactorId id) {
  return switch (id) {
    HostFactorId.workingProfessional => Icons.work_outline,
    HostFactorId.nonDrinker => Icons.no_drinks_outlined,
    HostFactorId.nonSmoker => Icons.smoke_free_outlined,
    HostFactorId.clean => Icons.cleaning_services_outlined,
    HostFactorId.gender => Icons.wc_outlined,
    HostFactorId.longStay => Icons.calendar_month_outlined,
    HostFactorId.furnishing => Icons.chair_outlined,
    HostFactorId.pets => Icons.pets_outlined,
  };
}

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _month(int month) => _months[month - 1];
