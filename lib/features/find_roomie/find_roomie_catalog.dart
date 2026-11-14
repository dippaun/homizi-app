import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/shared_home/shared_home_catalog.dart';

/// Sample people and homes used when nobody is signed in, the project is in
/// demo mode, or the new tables are not there yet. No phone or email.
const findRoomieViewerFirstName = 'Meera';

FindRoomieDeck sampleFindRoomieDeck() {
  return FindRoomieDeck(
    people: demoRoommateSeekers.take(5).toList(),
    sample: true,
    viewer: demoViewerTraits,
    viewerId: demoViewerUserId,
    viewerFirstName: findRoomieViewerFirstName,
  );
}

/// Shared-home samples, so "open home" lands on a real home screen.
List<Listing> get sampleFindRoomieHomes => [
  for (final home in sampleSharedHomes) home.listing,
];
