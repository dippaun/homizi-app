/// A curated locality. Rows come from `public.localities`.
class Locality {
  const Locality({
    required this.city,
    required this.name,
    required this.slug,
    required this.popularity,
  });

  final String city;
  final String name;
  final String slug;
  final int popularity;
}

/// Highest popularity first. Blank city and blank query return the whole list.
List<Locality> filterLocalities(
  List<Locality> all, {
  String? city,
  String query = '',
}) {
  final place = city?.trim() ?? '';
  final needle = query.trim().toLowerCase();
  final rows = <Locality>[
    for (final locality in all)
      if ((place.isEmpty || locality.city == place) &&
          (needle.isEmpty ||
              locality.name.toLowerCase().contains(needle) ||
              locality.slug.contains(needle)))
        locality,
  ];
  rows.sort((a, b) => b.popularity.compareTo(a.popularity));
  return rows;
}

List<Locality> popularLocalities(
  List<Locality> all,
  String city, {
  int limit = 8,
}) {
  final rows = filterLocalities(all, city: city);
  if (rows.length <= limit) {
    return rows;
  }
  return rows.sublist(0, limit);
}
