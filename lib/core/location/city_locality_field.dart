import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/homizi_map_view.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/maps/domain/geo.dart';

/// A place the person picked from Places or the bundled catalogue.
///
/// Typed text is not a place. A row exists only after a suggestion is chosen.
class PickedPlace {
  const PickedPlace({required this.label, this.latitude, this.longitude});

  final String label;
  final double? latitude;
  final double? longitude;

  bool get hasPoint => latitude != null && longitude != null;
}

/// City plus the localities inside it.
class CityLocalitySelection {
  const CityLocalitySelection({
    required this.city,
    this.cityLatitude,
    this.cityLongitude,
    this.localities = const [],
  });

  final String city;
  final double? cityLatitude;
  final double? cityLongitude;
  final List<PickedPlace> localities;
}

/// Cities and neighbourhoods the picker can offer when Maps has no key.
/// Coordinates are public neighbourhood centres, used only to bias search
/// and to score a nearby roommate.
const catalogCities = <String>[
  'Ahmedabad',
  'Vadodara',
  'Surat',
  'Mumbai',
  'Pune',
  'Bengaluru',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Jaipur',
  'Delhi',
  'Delhi NCR',
];

const catalogLocalities = <String, List<String>>{
  'Ahmedabad': [
    'Gurukul',
    'Bodakdev',
    'Satellite',
    'Vastrapur',
    'Prahlad Nagar',
    'SG Highway',
    'Thaltej',
    'Navrangpura',
    'Maninagar',
    'CG Road',
    'Paldi',
    'Bopal',
    'Naranpura',
    'Chandkheda',
  ],
  'Vadodara': ['Alkapuri', 'Akota', 'Fatehgunj'],
  'Surat': ['Adajan', 'Vesu', 'Piplod', 'Athwa'],
  'Mumbai': ['Andheri West', 'Bandra West', 'Powai', 'Juhu'],
  'Pune': ['Kothrud', 'Baner', 'Viman Nagar', 'Kharadi'],
  'Bengaluru': ['Koramangala', 'Indiranagar', 'HSR Layout', 'Whitefield'],
  'Hyderabad': ['Gachibowli', 'Madhapur', 'Banjara Hills', 'Kondapur'],
  'Chennai': ['Adyar', 'T. Nagar', 'Velachery', 'Anna Nagar'],
  'Kolkata': ['Salt Lake', 'Park Street', 'Ballygunge'],
  'Jaipur': ['C Scheme', 'Malviya Nagar', 'Vaishali Nagar'],
  'Delhi': ['Saket', 'Dwarka', 'Hauz Khas', 'Karol Bagh'],
  'Delhi NCR': ['Saket', 'Dwarka', 'Gurugram', 'Noida'],
};

/// City name from a Places row. The full label often includes the state.
String pickedCityName(PlaceSuggestion place) {
  final city = place.city?.trim() ?? '';
  if (city.isNotEmpty) {
    return city;
  }
  final label = place.label.split(',').first.trim();
  return label;
}

/// Neighbourhood name. Drops a trailing city when Places includes it.
String pickedLocalityName(PlaceSuggestion place, String city) {
  final locality = place.locality?.trim() ?? '';
  if (locality.isNotEmpty) {
    return locality;
  }
  final first = place.label.split(',').first.trim();
  if (city.trim().isNotEmpty &&
      first.toLowerCase() == city.trim().toLowerCase()) {
    return '';
  }
  return first;
}

bool samePlaceName(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  return left == right || left.contains(right) || right.contains(left);
}

List<PlaceSuggestion> catalogCitySuggestions() {
  return [
    for (final name in catalogCities)
      PlaceSuggestion(
        label: name,
        city: name,
        latitude: cityCentreFor(name)?.latitude,
        longitude: cityCentreFor(name)?.longitude,
      ),
  ];
}

List<PlaceSuggestion> catalogLocalitySuggestions(String city) {
  final names = catalogLocalities[city] ?? const <String>[];
  return [
    for (final name in names)
      PlaceSuggestion(
        label: name,
        locality: name,
        city: city,
        latitude: localityCentroids[localityKey(city, name)]?.latitude,
        longitude: localityCentroids[localityKey(city, name)]?.longitude,
      ),
  ];
}

/// City from Places (cities), then localities inside that city as chips.
///
/// Nothing is saved from the keyboard. A row is added only when a suggestion
/// is chosen. With no maps key the bundled catalogue is the suggestion list.
class CityLocalityField extends ConsumerStatefulWidget {
  const CityLocalityField({
    required this.city,
    required this.localities,
    required this.onChanged,
    this.cityLatitude,
    this.cityLongitude,
    this.cityKey,
    this.localityKey,
    this.addKey,
    this.maxLocalities,
    super.key,
  });

  final String city;
  final double? cityLatitude;
  final double? cityLongitude;
  final List<PickedPlace> localities;
  final ValueChanged<CityLocalitySelection> onChanged;
  final Key? cityKey;
  final Key? localityKey;
  final Key? addKey;

  /// Null means as many localities as the person adds.
  final int? maxLocalities;

  @override
  ConsumerState<CityLocalityField> createState() => _CityLocalityFieldState();
}

class _CityLocalityFieldState extends ConsumerState<CityLocalityField> {
  late final TextEditingController _city = TextEditingController(
    text: widget.city,
  );
  final _query = TextEditingController();
  var _adding = false;
  String? _reject;

  @override
  void didUpdateWidget(covariant CityLocalityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city && _city.text != widget.city) {
      _city.text = widget.city;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _query.dispose();
    super.dispose();
  }

  GeoFix? get _cityPoint {
    if (widget.cityLatitude != null && widget.cityLongitude != null) {
      return GeoFix(
        latitude: widget.cityLatitude!,
        longitude: widget.cityLongitude!,
      );
    }
    return cityCentreFor(widget.city);
  }

  void _emit({
    String? city,
    double? cityLatitude,
    double? cityLongitude,
    bool clearCityPoint = false,
    List<PickedPlace>? localities,
  }) {
    widget.onChanged(
      CityLocalitySelection(
        city: city ?? widget.city,
        cityLatitude: clearCityPoint
            ? null
            : (cityLatitude ?? widget.cityLatitude),
        cityLongitude: clearCityPoint
            ? null
            : (cityLongitude ?? widget.cityLongitude),
        localities: localities ?? widget.localities,
      ),
    );
  }

  void _chooseCity(PlaceSuggestion place) {
    final name = pickedCityName(place);
    if (name.isEmpty) {
      return;
    }
    final changed = !samePlaceName(name, widget.city);
    _city.text = name;
    _query.clear();
    setState(() {
      _adding = false;
      _reject = null;
    });
    _emit(
      city: name,
      cityLatitude: place.latitude ?? cityCentreFor(name)?.latitude,
      cityLongitude: place.longitude ?? cityCentreFor(name)?.longitude,
      localities: changed ? const [] : widget.localities,
    );
  }

  void _addLocality(PlaceSuggestion place) {
    final city = widget.city.trim();
    if (city.isEmpty) {
      setState(() => _reject = 'Choose a city before adding a locality.');
      return;
    }
    final reported = place.city?.trim() ?? '';
    if (reported.isNotEmpty && !samePlaceName(reported, city)) {
      setState(() => _reject = 'That place is outside $city.');
      _query.clear();
      return;
    }
    final name = pickedLocalityName(place, city);
    if (name.isEmpty) {
      setState(() => _reject = 'Pick a locality inside $city.');
      return;
    }
    if (widget.localities.any((item) => samePlaceName(item.label, name))) {
      _query.clear();
      setState(() => _adding = false);
      return;
    }
    final cap = widget.maxLocalities;
    if (cap != null && widget.localities.length >= cap) {
      setState(() => _reject = 'You can add $cap localities.');
      return;
    }
    final point = localityCentroids[localityKey(city, name)];
    _query.clear();
    setState(() {
      _adding = false;
      _reject = null;
    });
    _emit(
      localities: [
        ...widget.localities,
        PickedPlace(
          label: name,
          latitude: place.latitude ?? point?.latitude,
          longitude: place.longitude ?? point?.longitude,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final point = _cityPoint;
    final cap = widget.maxLocalities;
    final canAdd = cap == null || widget.localities.length < cap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaceAutocompleteField(
          controller: _city,
          fieldKey: widget.cityKey,
          labelText: homiziText(context, 'City'),
          hintText: homiziText(context, 'Search a city'),
          includedPrimaryTypes: const ['locality'],
          nearbyLocalities: catalogCitySuggestions(),
          biasPoint: point,
          prefixIcon: const Icon(
            Icons.location_city_outlined,
            color: HomiziColors.logoOrange,
          ),
          onSelected: _chooseCity,
        ),
        if (point != null) ...[
          const SizedBox(height: 12),
          HomiziMapView(
            mapsEnabled: config.mapsEnabled,
            apiKey: config.mapsApiKey,
            latitude: point.latitude,
            longitude: point.longitude,
            label: widget.city.isEmpty ? 'City' : widget.city,
          ),
        ],
        const SizedBox(height: 12),
        if (widget.localities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final place in widget.localities)
                InputChip(
                  key: Key('locality-chip-${place.label}'),
                  label: Text(place.label),
                  deleteButtonTooltipMessage: homiziText(
                    context,
                    'Remove ${place.label}',
                  ),
                  onDeleted: () => _emit(
                    localities: [
                      for (final item in widget.localities)
                        if (!samePlaceName(item.label, place.label)) item,
                    ],
                  ),
                ),
            ],
          ),
        if (canAdd && !_adding) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: widget.addKey,
              onPressed: widget.city.trim().isEmpty
                  ? null
                  : () => setState(() {
                      _adding = true;
                      _reject = null;
                    }),
              icon: const Icon(Icons.add, color: HomiziColors.logoOrange),
              label: Text(homiziText(context, 'Add locality')),
            ),
          ),
        ],
        if (_adding) ...[
          const SizedBox(height: 8),
          PlaceAutocompleteField(
            controller: _query,
            fieldKey: widget.localityKey,
            labelText: homiziText(context, 'Locality'),
            hintText: homiziText(context, 'Search inside ${widget.city}'),
            includedPrimaryTypes: const ['sublocality', 'neighborhood'],
            nearbyLocalities: catalogLocalitySuggestions(widget.city),
            biasPoint: point,
            commitLabel: false,
            prefixIcon: const Icon(
              Icons.place_outlined,
              color: HomiziColors.logoOrange,
            ),
            onSelected: _addLocality,
          ),
        ],
        if (_reject != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, _reject!),
            style: const TextStyle(color: HomiziColors.error),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Choose a city, then add each locality from the suggestions. Typed text is not saved.',
          ),
          style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
