import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';

/// SAMPLE DATA. Seed shared homes so the flow can be tried before any host
/// has added occupancy details. Every card built from these says "Sample".
/// Names are first name + last initial only; there is no contact detail.
const sampleSharedHomePrefix = 'sample-shared-';

bool isSampleSharedHome(String id) => id.startsWith(sampleSharedHomePrefix);

Listing _listing({
  required String id,
  required String title,
  required String locality,
  required String city,
  required int rentPerRoom,
  required int bedrooms,
  required int capacity,
  required String host,
  required String occupation,
  required String summary,
  required List<String> photos,
  String type = 'shared_room',
  String hostKind = 'Flatmate',
  String furnishing = 'semi_furnished',
  String availableFrom = '2026-12-01',
  bool nonVeg = false,
  List<String> amenities = const ['Wifi', 'Washing machine', 'Power backup'],
}) {
  return Listing(
    id: '$sampleSharedHomePrefix$id',
    hostUserId: 'sample-host-$id',
    title: title,
    city: city,
    locality: locality,
    rentInr: rentPerRoom,
    depositInr: rentPerRoom * 2,
    furnishing: furnishing,
    propertyType: type,
    bedrooms: bedrooms,
    occupancyMax: capacity,
    hostDisplayName: host,
    hostOccupation: occupation,
    hostKind: hostKind,
    amenities: amenities,
    summary: summary,
    photoAssets: photos,
    availableFromIso: availableFrom,
    nonVegAllowed: nonVeg,
  );
}

final sampleSharedHomes = <SharedHome>[
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'andheri-3bhk',
      title: '3 BHK shared home, Andheri East',
      locality: 'Andheri East',
      city: 'Mumbai',
      rentPerRoom: 12000,
      bedrooms: 3,
      capacity: 3,
      host: 'Rohit S.',
      occupation: 'IT Professional',
      photos: const [
        'assets/images/real/living_b.webp',
        'assets/images/real/bedroom_b.webp',
        'assets/images/real/kitchen.webp',
      ],
      summary:
          'Rohit lives in one room. Two separate rooms are free, a short walk '
          'from Chakala metro. Sample home.',
      amenities: const ['Wifi', 'Washing machine', 'Lift', 'Power backup'],
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 3,
      totalCapacity: 3,
      currentlyLiving: 1,
      vacantRooms: 2,
      housemates: [
        Housemate(
          firstName: 'Rohit',
          lastInitial: 'S',
          age: 29,
          occupation: 'IT Professional',
          food: 'veg',
          gender: 'male',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'powai-2bhk',
      title: '2 BHK room sharing, Powai',
      locality: 'Powai',
      city: 'Mumbai',
      rentPerRoom: 8000,
      bedrooms: 2,
      capacity: 4,
      host: 'Neha K.',
      occupation: 'UX Designer',
      nonVeg: true,
      photos: const [
        'assets/images/real/living_b.webp',
        'assets/images/real/bedroom.webp',
      ],
      summary:
          'Double occupancy: two people share each room. Neha has one bed; '
          'three places are free. Ideal for friends or cost sharing. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 2,
      totalCapacity: 4,
      currentlyLiving: 1,
      vacantRooms: 1,
      type: HostOccupancy.double,
      housemates: [
        Housemate(
          firstName: 'Neha',
          lastInitial: 'K',
          age: 26,
          occupation: 'UX Designer',
          food: 'non_veg',
          gender: 'female',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'baner-3bhk',
      title: '3 BHK with single or double rooms, Baner',
      locality: 'Baner',
      city: 'Pune',
      rentPerRoom: 7500,
      bedrooms: 3,
      capacity: 6,
      host: 'Kabir S.',
      occupation: 'Software Engineer',
      photos: const [
        'assets/images/real/living.webp',
        'assets/images/real/bedroom.webp',
      ],
      summary:
          'Choose single or double occupancy per room. Kabir and Arjun share '
          'one room; two rooms are free. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 3,
      totalCapacity: 6,
      currentlyLiving: 2,
      vacantRooms: 2,
      type: HostOccupancy.double,
      housemates: [
        Housemate(
          firstName: 'Kabir',
          lastInitial: 'S',
          age: 28,
          occupation: 'Software Engineer',
          food: 'eggetarian',
          gender: 'male',
        ),
        Housemate(
          firstName: 'Arjun',
          lastInitial: 'M',
          age: 27,
          occupation: 'QA Engineer',
          food: 'veg',
          gender: 'male',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'hsr-2bhk',
      title: '2 BHK shared home, HSR Layout',
      locality: 'HSR Layout',
      city: 'Bengaluru',
      rentPerRoom: 15500,
      bedrooms: 2,
      capacity: 2,
      host: 'Ananya P.',
      occupation: 'Product Manager',
      photos: const [
        'assets/images/real/dining.webp',
        'assets/images/real/bedroom_b.webp',
      ],
      availableFrom: '2026-12-15',
      summary:
          'Ananya lives in one room. The other room, with its own balcony, '
          'is free from 15 Dec. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 2,
      totalCapacity: 2,
      currentlyLiving: 1,
      vacantRooms: 1,
      housemates: [
        Housemate(
          firstName: 'Ananya',
          lastInitial: 'P',
          age: 27,
          occupation: 'Product Manager',
          food: 'veg',
          gender: 'female',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'malad-3bhk',
      title: '3 BHK shared home, Malad West',
      locality: 'Malad West',
      city: 'Mumbai',
      rentPerRoom: 13500,
      bedrooms: 3,
      capacity: 3,
      host: 'Imran K.',
      occupation: 'Chartered Accountant',
      nonVeg: true,
      photos: const [
        'assets/images/real/living.webp',
        'assets/images/real/bedroom_b.webp',
      ],
      summary:
          'Imran lives in the master room. Two separate rooms are free near '
          'Mindspace. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 3,
      totalCapacity: 3,
      currentlyLiving: 1,
      vacantRooms: 2,
      housemates: [
        Housemate(
          firstName: 'Imran',
          lastInitial: 'K',
          age: 31,
          occupation: 'Chartered Accountant',
          food: 'non_veg',
          gender: 'male',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'hinjewadi-4bhk',
      title: '4 BHK shared home, Hinjewadi',
      locality: 'Hinjewadi',
      city: 'Pune',
      rentPerRoom: 11000,
      bedrooms: 4,
      capacity: 4,
      host: 'Siddharth J.',
      occupation: 'Data Analyst',
      nonVeg: true,
      photos: const [
        'assets/images/real/living_b.webp',
        'assets/images/real/bedroom.webp',
      ],
      summary:
          'Three working professionals live here. One separate room is free '
          'near Phase 1. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 4,
      totalCapacity: 4,
      currentlyLiving: 3,
      vacantRooms: 1,
      housemates: [
        Housemate(
          firstName: 'Siddharth',
          lastInitial: 'J',
          age: 30,
          occupation: 'Data Analyst',
          food: 'non_veg',
          gender: 'male',
        ),
      ],
    ),
  ),
  SharedHome(
    sample: true,
    listing: _listing(
      id: 'koramangala-1rk',
      title: '1 RK studio, Koramangala',
      locality: 'Koramangala',
      city: 'Bengaluru',
      rentPerRoom: 9000,
      bedrooms: 1,
      capacity: 2,
      host: 'Lakshmi R.',
      occupation: 'Owner',
      hostKind: 'Owner',
      type: 'studio',
      furnishing: 'furnished',
      photos: const ['assets/images/real/bedroom.webp'],
      summary:
          'A furnished studio for one person or a couple. Nobody lives here '
          'yet. Sample home.',
    ),
    occupancy: const HomeOccupancy(
      totalRooms: 1,
      totalCapacity: 2,
      currentlyLiving: 0,
      vacantRooms: 1,
      type: HostOccupancy.double,
    ),
  ),
];
