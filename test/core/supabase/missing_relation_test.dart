import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';

void main() {
  test('a missing table or function is recognised', () {
    expect(
      isMissingRelation(
        Exception(
          "Could not find the table 'public.property_partner_applications' in the schema cache",
        ),
      ),
      isTrue,
    );
    expect(
      isMissingRelation(
        const DiscoveryFailure(
          'Could not find the function public.public_listings (PGRST202)',
        ),
      ),
      isTrue,
    );
    expect(
      isMissingRelation(Exception('relation "rent_splits" does not exist')),
      isTrue,
    );
    expect(
      isMissingRelation(
        const DiscoveryFailure(
          'permission denied for table properties (42501)',
        ),
      ),
      isFalse,
    );
    expect(
      isMissingRelation(
        const DiscoveryFailure('Sign in before browsing homes.'),
      ),
      isFalse,
    );
  });
}
