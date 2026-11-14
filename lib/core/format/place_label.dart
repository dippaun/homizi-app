/// Coarse kilometres from a city centre for localities in the demo catalog.
///
/// This is a presentation hint only. It is not a device location, a route,
/// or a street address. Unknown localities return null so the card stays
/// on the locality name.
int? aboutKmFromCityCentre(String locality) => _kmFromCityCentre[locality];

const _kmFromCityCentre = <String, int>{
  'Koramangala': 6,
  'HSR Layout': 9,
  'Indiranagar': 6,
  'Jayanagar': 5,
  'BTM Layout': 7,
  'JP Nagar': 8,
  'Hebbal': 10,
  'Bellandur': 14,
  'Marathahalli': 14,
  'Whitefield': 17,
  'Electronic City': 18,
  'Baner': 11,
  'Kharadi': 12,
  'Kothrud': 7,
  'Viman Nagar': 10,
  'Aundh': 8,
  'Koregaon Park': 5,
  'Wakad': 14,
  'Hinjewadi': 16,
  'Bandra West': 15,
  'Chembur': 16,
  'Andheri West': 22,
  'Powai': 25,
  'Goregaon East': 26,
  'Malad West': 30,
  'Thane': 30,
  'Mulund': 32,
  'Banjara Hills': 6,
  'Kukatpally': 14,
  'Madhapur': 15,
  'Gachibowli': 16,
  'Hitech City': 17,
  'Kondapur': 18,
  'Saket': 13,
  'Dwarka': 18,
  'Indirapuram': 16,
  'Noida Sector 62': 22,
  'Gurugram': 28,
  'Greater Noida': 38,
};

/// "Locality, City · About N km" — the one place line for a listing, used
/// on its card and its detail screen so both read the same.
String listingPlaceLine(String locality, String city) {
  final place = [locality, city].where((part) => part.isNotEmpty).join(', ');
  final km = aboutKmFromCityCentre(locality);
  return km == null ? place : '$place · About $km km';
}
