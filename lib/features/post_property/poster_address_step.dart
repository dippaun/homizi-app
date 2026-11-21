import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/homizi_map_view.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/ui/kit/kit.dart';

/// First page of a PG, broker, or room-sharer listing.
///
/// Building, flat, street, locality, and city come from Google Places.
/// The map pin follows the chosen place. A PG also picks rooms available.
class PosterAddressStep extends ConsumerStatefulWidget {
  const PosterAddressStep({
    required this.draft,
    required this.onChanged,
    this.rooms = false,
    super.key,
  });

  final ListingDraft draft;
  final ValueChanged<ListingDraft> onChanged;

  /// PG owners count beds that are free, with a sharing type.
  final bool rooms;

  @override
  ConsumerState<PosterAddressStep> createState() => _PosterAddressStepState();
}

class _PosterAddressStepState extends ConsumerState<PosterAddressStep> {
  late final TextEditingController _building;
  late final TextEditingController _flat;
  late final TextEditingController _street;
  late final TextEditingController _locality;
  late final TextEditingController _city;
  late final TextEditingController _pin;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _building = TextEditingController(text: draft.buildingName);
    _flat = TextEditingController(text: draft.flatNo);
    _street = TextEditingController(text: draft.addressLine);
    _locality = TextEditingController(text: draft.locality);
    _city = TextEditingController(text: draft.city);
    _pin = TextEditingController(text: draft.pincode);
  }

  @override
  void didUpdateWidget(PosterAddressStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assign(_flat, widget.draft.flatNo);
    if (oldWidget.draft.buildingName != widget.draft.buildingName &&
        (_building.text == oldWidget.draft.buildingName ||
            _building.text.isEmpty)) {
      _assign(_building, widget.draft.buildingName);
    }
    _assign(_street, widget.draft.addressLine);
    _assign(_locality, widget.draft.locality);
    _assign(_city, widget.draft.city);
    _assign(_pin, widget.draft.pincode);
  }

  void _assign(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _building.dispose();
    _flat.dispose();
    _street.dispose();
    _city.dispose();
    _locality.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _emit({
    String? building,
    String? flat,
    String? street,
    String? locality,
    String? city,
    String? pin,
    double? latitude,
    double? longitude,
    bool clearPoint = false,
    int? rooms,
    String? sharing,
  }) {
    final streetLine = street ?? _street.text;
    final cappedStreet = streetLine.trim().length <= 160
        ? streetLine.trim()
        : streetLine.trim().substring(0, 160).trimRight();
    widget.onChanged(
      widget.draft.copyWith(
        buildingName: shortBuildingName(building ?? _building.text),
        flatNo: flat ?? _flat.text,
        addressLine: cappedStreet,
        locality: locality ?? _locality.text,
        city: city ?? _city.text,
        pincode: pin ?? _pin.text,
        latitude: latitude,
        longitude: longitude,
        clearPoint: clearPoint,
        occupancy: rooms ?? widget.draft.occupancy,
        rentableArea: sharing ?? widget.draft.rentableArea,
      ),
    );
  }

  void _place(PlaceSuggestion place) {
    final formatted = (place.address ?? '').trim();
    final label = place.label.trim();
    final city = (place.city ?? '').trim();
    final locality = (place.locality ?? '').trim();
    final route = formatted.isNotEmpty ? formatted : label;
    final pin = (place.postalCode ?? '').trim().isNotEmpty
        ? place.postalCode!.trim()
        : (RegExp(r'\b\d{6}\b').firstMatch(route)?.group(0) ?? '');
    _building.text = shortBuildingName(label.isEmpty ? route : label);
    if (route.isNotEmpty) {
      _street.text = route.length <= 160
          ? route
          : route.substring(0, 160).trimRight();
    }
    if (locality.isNotEmpty) {
      _locality.text = locality;
    }
    if (city.isNotEmpty) {
      _city.text = city;
    }
    if (pin.isNotEmpty) {
      _pin.text = pin;
    }
    _emit(
      latitude: place.latitude,
      longitude: place.longitude,
      clearPoint: place.latitude == null || place.longitude == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final draft = widget.draft;
    final bias = draft.latitude != null && draft.longitude != null
        ? GeoFix(latitude: draft.latitude!, longitude: draft.longitude!)
        : null;
    return Column(
      key: const Key('poster-address-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Where is this home?'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            'Pick the building from Places. Street, locality, city, and pincode fill in from that place. You can edit them.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 16),
        PlaceAutocompleteField(
          fieldKey: const Key('poster-building'),
          controller: _building,
          labelText: homiziText(context, 'Building / PG name'),
          hintText: homiziText(context, 'Narayan Exotica'),
          textCapitalization: TextCapitalization.words,
          includedPrimaryTypes: const ['establishment'],
          commitLabel: false,
          biasPoint: bias,
          prefixIcon: const Icon(
            Icons.apartment,
            color: HomiziColors.logoOrange,
          ),
          onSelected: (place) => _place(place),
        ),
        const SizedBox(height: 12),
        HomiziMapView(
          mapsEnabled: config.mapsEnabled,
          apiKey: config.mapsApiKey,
          latitude: draft.latitude,
          longitude: draft.longitude,
          label: _locality.text.trim().isEmpty
              ? 'Your home'
              : _locality.text.trim(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('poster-street'),
          controller: _street,
          textCapitalization: TextCapitalization.sentences,
          decoration: postFieldDecoration(
            context,
            'Street',
            Icons.signpost_outlined,
          ),
          onChanged: (value) => _emit(street: value),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('poster-locality'),
          controller: _locality,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'Locality',
            Icons.place_outlined,
          ),
          onChanged: (value) => _emit(locality: value),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('poster-city'),
          controller: _city,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'City',
            Icons.location_city_outlined,
          ),
          onChanged: (value) => _emit(city: value),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('poster-pincode'),
          controller: _pin,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: postFieldDecoration(
            context,
            'Pincode',
            Icons.markunread_mailbox_outlined,
          ),
          onChanged: (value) => _emit(pin: value),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('poster-flat'),
          controller: _flat,
          textCapitalization: TextCapitalization.characters,
          decoration: postFieldDecoration(
            context,
            'House / flat no. (optional)',
            Icons.door_front_door_outlined,
            hint: 'B-1204',
          ),
          onChanged: (value) => _emit(flat: value),
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('poster-flat-private'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomiziColors.homiziPurple),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: HomiziColors.homiziPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  homiziText(
                    context,
                    'Private: never shown on your public listing or profile',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.rooms) ...[
          const SizedBox(height: 18),
          Text(
            homiziText(context, 'Rooms available'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              'How many rooms or beds are free, and how they are shared.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.3),
          ),
          const SizedBox(height: 10),
          OptionGrid(
            minTileWidth: 72,
            maxColumns: 4,
            children: [
              for (var count = 1; count <= 8; count++)
                OptionTile(
                  key: Key('poster-rooms-$count'),
                  label: '$count',
                  icon: Icons.bed_outlined,
                  selected: draft.occupancy == count,
                  onTap: () => _emit(rooms: count),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OptionGrid(
            children: [
              for (final option in const [
                ('single', 'Single', Icons.person_outline),
                ('double', 'Double', Icons.people_outline),
                ('triple', 'Triple', Icons.groups_outlined),
              ])
                OptionTile(
                  key: Key('poster-sharing-${option.$1}'),
                  label: option.$2,
                  icon: option.$3,
                  selected: draft.rentableArea == option.$1,
                  onTap: () => _emit(sharing: option.$1),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// What the address page still needs before the rest of the listing.
String? posterAddressGap(ListingDraft draft, {required bool rooms}) {
  if (draft.addressLine.trim().length < 3 && draft.locality.trim().length < 2) {
    return 'Pick the home from Places.';
  }
  if (draft.city.trim().length < 2 && draft.locality.trim().length < 2) {
    return 'Pick the home on the map.';
  }
  if (rooms && draft.occupancy < 1) {
    return 'Choose how many rooms are available.';
  }
  if (rooms &&
      draft.rentableArea != 'single' &&
      draft.rentableArea != 'double' &&
      draft.rentableArea != 'triple') {
    return 'Choose the sharing type for the rooms available.';
  }
  return null;
}
