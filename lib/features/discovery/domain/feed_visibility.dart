import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

/// Published homes stay in Discover and Explore when the tenant has no
/// preference row, and also when a preference is saved.
///
/// Budget, locality, and property type score a card. They are not a filter.
/// The 40 staging seed listings remain visible to a fresh tenant.
List<Listing> listingsVisibleToTenant(
  List<Listing> published, {
  TenantPreferences? preferences,
}) {
  if (preferences == null || preferences.isBlank) {
    return List<Listing>.of(published);
  }
  return List<Listing>.of(published);
}
