import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/features/interest/tenant_card.dart';

/// Sample people a host can review in demo mode. No phone or email.
const demoTenantCards = <TenantCard>[
  TenantCard(
    userId: 'demo-tenant-meera',
    name: 'Meera K.',
    occupation: 'Architect',
    about:
        'I work from a studio three days a week and like a quiet flat. I cook most nights and keep common spaces clear.',
    city: 'Ahmedabad',
    ageRange: '25-30',
    lifestyle: ['wfh', 'non_smoker', 'early_riser'],
    budgetMinInr: 15000,
    budgetMaxInr: 28000,
    moveInIso: '2026-11-15',
    photoRef: 'assets/avatars/avatar_01.webp',
  ),
  TenantCard(
    userId: 'demo-tenant-arjun',
    name: 'Arjun P.',
    occupation: 'Software engineer',
    about:
        'Looking for a 2 BHK with a desk corner. I am out most weekends and happy to share a kitchen.',
    city: 'Bengaluru',
    ageRange: '25-30',
    lifestyle: ['wfh', 'night_owl'],
    budgetMinInr: 18000,
    budgetMaxInr: 32000,
    moveInIso: '2026-12-01',
    photoRef: 'assets/avatars/avatar_02.webp',
  ),
  TenantCard(
    userId: 'demo-tenant-neha',
    name: 'Neha S.',
    occupation: 'School teacher',
    about:
        'I need a home near a bus route. I have a small dog and I am home by evening.',
    city: 'Pune',
    ageRange: '31-35',
    lifestyle: ['pets_ok', 'early_riser', 'non_smoker'],
    budgetMinInr: 12000,
    budgetMaxInr: 22000,
    moveInIso: '2026-11-01',
    photoRef: 'assets/avatars/avatar_03.webp',
  ),
  TenantCard(
    userId: 'demo-tenant-kabir',
    name: 'Kabir R.',
    occupation: 'Product manager',
    about:
        'Moving with my partner. We want a gated society and a parking slot for one car.',
    city: 'Mumbai',
    ageRange: '31-35',
    lifestyle: ['non_smoker'],
    budgetMinInr: 30000,
    budgetMaxInr: 55000,
    moveInIso: '2026-12-15',
    photoRef: 'assets/avatars/avatar_04.webp',
  ),
  TenantCard(
    userId: 'demo-tenant-isha',
    name: 'Isha D.',
    occupation: 'Doctor',
    about:
        'Night shifts some weeks. I am looking for a furnished place I can move into this month.',
    city: 'Ahmedabad',
    ageRange: '25-30',
    lifestyle: ['night_owl', 'non_smoker'],
    budgetMinInr: 20000,
    budgetMaxInr: 35000,
    moveInIso: '2026-10-28',
    photoRef: 'assets/avatars/avatar_05.webp',
  ),
  TenantCard(
    userId: 'demo-tenant-vivek',
    name: 'Vivek N.',
    occupation: 'Chef',
    about:
        'I cook for work and at home. A kitchen with a window matters more than a large bedroom.',
    city: 'Hyderabad',
    ageRange: '36-45',
    lifestyle: ['early_riser'],
    budgetMinInr: 14000,
    budgetMaxInr: 26000,
    moveInIso: '2026-11-20',
    photoRef: 'assets/avatars/avatar_06.webp',
  ),
];

String demoAvatarUrl(int index) =>
    demoMediaUrl(demoAvatarFiles[index % demoAvatarFiles.length]);
