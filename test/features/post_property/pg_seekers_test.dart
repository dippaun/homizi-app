import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/post_property/pg_seekers.dart';
import 'package:homizi/features/shell/role_nav.dart';

void main() {
  test('PG seekers are people who asked for a PG or a shared room', () {
    expect(
      requirementWantsPg({
        'property_types': ['apartment'],
        'room_type': ['2bhk'],
      }),
      isFalse,
    );
    expect(
      requirementWantsPg({
        'property_types': ['pg', 'apartment'],
      }),
      isTrue,
    );
    expect(
      requirementWantsPg({
        'room_type': ['shared'],
      }),
      isTrue,
    );
    final seeker = pgSeekerFromRows(
      requirement: {
        'city': 'Pune',
        'budget_min_inr': 8000,
        'budget_max_inr': 12000,
        'property_types': ['pg'],
      },
      profile: {
        'user_id': '11111111-1111-4111-8111-111111111111',
        'display_name': 'Meera N.',
      },
    );
    expect(seeker?.name, 'Meera N.');
    expect(seeker?.city, 'Pune');
    expect(seeker?.looking, contains('PG'));
  });

  test('a PG owner keeps three tabs', () {
    final tabs = pgOwnerDestinations.map((item) => item.label).toList();
    expect(tabs, ['Home', 'Chat', 'Profile']);
    expect(pgOwnerDestinations.last.path, '/profile/me');
  });

  test('staging tools stay off a release build', () {
    const staging = AppConfig(
      environment: AppEnvironment.staging,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public',
      policyVersion: '2026-10-11-draft',
    );
    const production = AppConfig(
      environment: AppEnvironment.prod,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public',
      policyVersion: '2026-10-11-draft',
    );
    expect(showStagingTools(staging, release: true), isFalse);
    expect(showStagingTools(production), isFalse);
    expect(showStagingTools(staging), isTrue);
  });
}
