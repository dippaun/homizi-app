import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/seeker_board.dart';

/// Homes the host can match seekers against: posted on this device or
/// just published, else the labelled sample homes.
final hostPropertiesProvider = Provider<List<HostProperty>>((ref) {
  return collectHostProperties(
    owned: ref.watch(demoListingMemoryProvider).homes.values,
    published: ref.watch(publishedSearchProvider),
  );
});

/// Sample rows and the demo owner's seeded homes are not the user's own
/// posts, so they are never shown as "Property posted".
bool isSampleHostHome(HostProperty home) =>
    home.sample || home.id.startsWith('demo-own-');
