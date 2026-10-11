import 'package:homizi/features/discovery/domain/listing.dart';

/// Fake homes for the offline shell. No phone numbers, emails, or street addresses.
abstract final class DemoCatalog {
  static const listings = <Listing>[
    Listing(
      id: 'lst_koramangala',
      hostUserId: 'demo-host-rohan',
      title: 'Sunlit 2BHK in Koramangala',
      city: 'Bengaluru',
      locality: 'Koramangala',
      rentInr: 22000,
      depositInr: 80000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Rohan M.',
      amenities: ['Lift', 'Power backup', 'Washing machine'],
      summary:
          'A published demo listing. The exact address stays off this card.',
      demoReciprocal: true,
    ),
    Listing(
      id: 'lst_indiranagar',
      hostUserId: 'demo-host-meera',
      title: 'Studio near Indiranagar metro',
      city: 'Bengaluru',
      locality: 'Indiranagar',
      rentInr: 28000,
      depositInr: 56000,
      furnishing: 'furnished',
      propertyType: 'studio',
      hostDisplayName: 'Meera K.',
      amenities: ['Security', 'Gym'],
      summary: 'Compact studio for one person. Brokerage is listed as zero in this demo.',
    ),
    Listing(
      id: 'lst_baner',
      hostUserId: 'demo-host-kabir',
      title: 'Private room in Baner',
      city: 'Pune',
      locality: 'Baner',
      rentInr: 14000,
      depositInr: 28000,
      furnishing: 'semi_furnished',
      propertyType: 'private_room',
      hostDisplayName: 'Kabir S.',
      amenities: ['Wifi', 'Two bathrooms'],
      summary: 'Room in a shared flat. Lifestyle tags are limited to pets and smoking.',
    ),
    Listing(
      id: 'lst_kothrud',
      hostUserId: 'demo-host-anika',
      title: 'Shared room in Kothrud',
      city: 'Pune',
      locality: 'Kothrud',
      rentInr: 9000,
      depositInr: 18000,
      furnishing: 'unfurnished',
      propertyType: 'shared_room',
      hostDisplayName: 'Anika D.',
      amenities: ['Parking', 'Balcony'],
      summary: 'Lower rent, unfurnished. Useful for filter and budget tests.',
    ),
  ];

  static Listing? byId(String id) {
    for (final listing in listings) {
      if (listing.id == id) {
        return listing;
      }
    }
    return null;
  }
}
