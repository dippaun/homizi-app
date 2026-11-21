import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/location/homizi_map_view.dart';
import 'package:homizi/core/location/location_models.dart'
    show GeoFix, PlaceSuggestion, cityCentreFor;
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/flow_accent.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_field_anchor.dart';
import 'package:homizi/features/listings/rent_cost_breakdown.dart';
import 'package:homizi/features/listings/room_share_offer.dart';
import 'package:homizi/features/nearby/nearby_icons.dart';
import 'package:homizi/ui/kit/kit.dart';

OutlineInputBorder _fieldBorder(Color color, [double width = 1.5]) {
  return OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: color, width: width),
  );
}

InputDecoration listingFieldDecoration(
  BuildContext context,
  String label,
  IconData icon, {
  String? hint,
  String? helper,
}) {
  final accent = FlowAccentScope.active(context)
      ? HomiziColors.homiziPurple
      : HomiziColors.logoOrange;
  return InputDecoration(
    labelText: homiziText(context, label),
    hintText: hint == null ? null : homiziText(context, hint),
    helperText: helper == null ? null : homiziText(context, helper),
    prefixIcon: Icon(icon, color: HomiziColors.logoOrange),
    filled: true,
    fillColor: HomiziColors.white,
    enabledBorder: _fieldBorder(HomiziColors.line),
    border: _fieldBorder(HomiziColors.line),
    focusedBorder: _fieldBorder(accent, 2),
  );
}

IconData listingIntentIcon(String intent) => switch (intent) {
  'room' => RealLifeIcons.privateRoom,
  'whole_flat' => RealLifeIcons.house,
  'pg' => RealLifeIcons.pg,
  _ => RealLifeIcons.sharedRoom,
};

/// Visible title box. The label, hint, and outline stay on screen when empty.
class ListingTitleField extends StatelessWidget {
  const ListingTitleField({
    required this.controller,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = FlowAccentScope.active(context)
        ? HomiziColors.homiziPurple
        : HomiziColors.logoOrange;
    return wizardAnchor(
      context,
      'title',
      TextField(
        key: const Key('listing-title'),
        controller: controller,
        focusNode: wizardFocus(context, 'title'),
        textCapitalization: TextCapitalization.sentences,
        onChanged: onChanged,
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: homiziText(context, 'Listing title'),
          hintText: homiziText(context, 'PG in Gurukul, Ahmedabad'),
          helperText: homiziText(
            context,
            'Shown on your listing. You can edit this.',
          ),
          filled: true,
          fillColor: HomiziColors.white,
          prefixIcon: const Icon(
            Icons.edit_outlined,
            color: HomiziColors.logoOrange,
          ),
          enabledBorder: _fieldBorder(HomiziColors.line),
          border: _fieldBorder(HomiziColors.line),
          focusedBorder: _fieldBorder(accent, 2),
        ),
      ),
    );
  }
}

class IntentStep extends StatelessWidget {
  const IntentStep({
    required this.draft,
    required this.title,
    required this.onIntent,
    this.showTitle = true,
    this.hostPair = false,
    this.onTitleChanged,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController title;
  final ValueChanged<String> onIntent;

  /// Host "I want to list" offers only a room or a shared space.
  final bool hostPair;

  /// Post Property writes a title from the type and place, and edits it
  /// on Property Details. The eight-step wizard still shows the field here.
  final bool showTitle;
  final ValueChanged<String>? onTitleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            'Choose what you want to list. Rank comes later, from the tenant\'s priorities.',
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 16),
          ListingTitleField(controller: title, onChanged: onTitleChanged),
        ],
        const SizedBox(height: 16),
        wizardAnchor(
          context,
          'intent',
          hostPair
              ? _HostIntentPair(draft: draft, onIntent: onIntent)
              : OptionGrid(
                  maxColumns: 2,
                  minTileWidth: 140,
                  children: [
                    for (final option in listingIntentOptions)
                      SizedBox(
                        height: 176,
                        child: OptionTile(
                          key: Key('listing-intent-${option.$1}'),
                          label: homiziText(context, option.$2),
                          subtitle: homiziText(context, option.$3),
                          icon: listingIntentIcon(option.$1),
                          selected: draft.listingIntent == option.$1,
                          onTap: () => onIntent(option.$1),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HostIntentPair extends StatelessWidget {
  const _HostIntentPair({required this.draft, required this.onIntent});

  final ListingDraft draft;
  final ValueChanged<String> onIntent;

  @override
  Widget build(BuildContext context) {
    const options = <(String, String, String, IconData, Color)>[
      (
        'room',
        'A Room / Shared Room',
        'Single room or double sharing',
        Icons.bed_outlined,
        HomiziColors.accentWash,
      ),
      (
        'shared_space',
        'Shared Space (I am an existing tenant)',
        'Looking for a flatmate / roomie',
        Icons.groups_outlined,
        HomiziColors.homiziLavender,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _HostIntentCard(
              option: options[i],
              selected: draft.listingIntent == options[i].$1,
              onTap: () => onIntent(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _HostIntentCard extends StatelessWidget {
  const _HostIntentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final (String, String, String, IconData, Color) option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Material(
        color: selected ? HomiziColors.logoOrange : option.$5,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: Key('listing-intent-${option.$1}'),
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  option.$4,
                  color: selected
                      ? HomiziColors.white
                      : HomiziColors.logoOrange,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  homiziText(context, option.$2),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: selected ? HomiziColors.white : HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  homiziText(context, option.$3),
                  style: TextStyle(
                    color: selected ? HomiziColors.white : HomiziColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocationStep extends StatelessWidget {
  const LocationStep({
    required this.draft,
    required this.locality,
    required this.building,
    required this.area,
    required this.floor,
    required this.totalFloors,
    required this.landmark,
    required this.onCity,
    required this.onLocality,
    required this.onBuildingKind,
    required this.onConfiguration,
    this.hidePlace = false,
    this.hideArea = false,
    this.onShare,
    this.onFlat,
    this.onPlace,
    this.onLandmarkPlace,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController locality;
  final TextEditingController building;
  final TextEditingController area;
  final TextEditingController floor;
  final TextEditingController totalFloors;
  final TextEditingController landmark;
  final ValueChanged<String> onCity;
  final ValueChanged<String> onLocality;
  final ValueChanged<String> onBuildingKind;
  final ValueChanged<String> onConfiguration;
  final bool hidePlace;
  final bool hideArea;
  final ValueChanged<String>? onShare;
  final ValueChanged<String>? onFlat;

  /// A Google place picked in the locality box. Null keeps a plain field.
  final ValueChanged<PlaceSuggestion>? onPlace;
  final ValueChanged<PlaceSuggestion>? onLandmarkPlace;

  @override
  Widget build(BuildContext context) {
    // With a detected point the service biases tightly around the device's
    // last fix; otherwise bias widely around the picked city.
    final GeoFix? bias = draft.latitude != null && draft.longitude != null
        ? null
        : cityCentreFor(draft.city);
    final showFloors = floorApplies(draft.buildingKind);
    final savedLocality = draft.locality.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hidePlace) ...[
          wizardAnchor(
            context,
            'place',
            CityLocalityField(
              cityKey: const Key('listing-city'),
              localityKey: const Key('listing-locality'),
              addKey: const Key('listing-add-locality'),
              maxLocalities: 1,
              city: draft.city,
              cityLatitude: draft.latitude,
              cityLongitude: draft.longitude,
              localities: [
                if (savedLocality.isNotEmpty)
                  PickedPlace(
                    label: savedLocality,
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                  ),
              ],
              onChanged: (selection) {
                onCity(selection.city);
                final place = selection.localities.isEmpty
                    ? null
                    : selection.localities.first;
                onLocality(place?.label ?? '');
                if (place != null) {
                  onPlace?.call(
                    PlaceSuggestion(
                      label: place.label,
                      locality: place.label,
                      city: selection.city,
                      latitude: place.latitude,
                      longitude: place.longitude,
                      address: [
                        place.label,
                        selection.city,
                      ].where((part) => part.trim().isNotEmpty).join(', '),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('listing-flat'),
            initialValue: draft.flatNo,
            textCapitalization: TextCapitalization.characters,
            decoration: listingFieldDecoration(
              context,
              'House / flat no. (optional)',
              Icons.lock_outline,
            ),
            onChanged: onFlat,
          ),
          const SizedBox(height: 8),
          const _PrivateFlatNote(),
          const SizedBox(height: 12),
          wizardAnchor(
            context,
            'building',
            TextField(
              key: const Key('listing-building'),
              controller: building,
              textCapitalization: TextCapitalization.words,
              decoration: listingFieldDecoration(
                context,
                'Tower / building name (optional)',
                Icons.apartment_outlined,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        wizardAnchor(
          context,
          'propertyType',
          _ListingMenu(
            fieldKey: const Key('listing-property-type'),
            label: 'Property type',
            icon: Icons.home_work_outlined,
            value: draft.buildingKind,
            options: buildingKindOptions,
            onChanged: onBuildingKind,
          ),
        ),
        if (showFloors) ...[
          const SizedBox(height: 12),
          wizardAnchor(
            context,
            'floor',
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('listing-floor'),
                    focusNode: wizardFocus(context, 'floor'),
                    controller: floor,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [WholeAmountFormatter()],
                    decoration: listingFieldDecoration(
                      context,
                      'Floor number',
                      Icons.stairs_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('listing-total-floors'),
                    controller: totalFloors,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [WholeAmountFormatter()],
                    decoration: listingFieldDecoration(
                      context,
                      'of N floors',
                      Icons.layers_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        wizardAnchor(
          context,
          'configuration',
          _ListingMenu(
            fieldKey: const Key('listing-configuration'),
            label: 'Property configuration',
            icon: Icons.meeting_room_outlined,
            value: draft.configuration,
            options: configurationOptions,
            onChanged: onConfiguration,
          ),
        ),
        if (draft.listingIntent == 'shared_space') ...[
          const SizedBox(height: 16),
          RoomShareOffer(
            configuration: draft.configuration,
            raw: draft.shareJson,
            onChanged: (value) => onShare?.call(value),
          ),
        ],
        if (!hideArea) ...[
          const SizedBox(height: 12),
          wizardAnchor(
            context,
            'area',
            TextField(
              key: const Key('listing-area'),
              focusNode: wizardFocus(context, 'area'),
              controller: area,
              keyboardType: TextInputType.number,
              inputFormatters: const [WholeAmountFormatter()],
              decoration: listingFieldDecoration(
                context,
                'Total area (sq ft)',
                Icons.square_foot_outlined,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        PlaceAutocompleteField(
          fieldKey: const Key('listing-landmark'),
          controller: landmark,
          textCapitalization: TextCapitalization.words,
          labelText: homiziText(context, 'Landmark'),
          prefixIcon: const Icon(
            Icons.flag_outlined,
            color: HomiziColors.logoOrange,
          ),
          biasPoint: bias,
          onSelected: (place) => onLandmarkPlace?.call(place),
        ),
      ],
    );
  }
}

class NearbyStep extends StatelessWidget {
  const NearbyStep({
    required this.draft,
    required this.onChanged,
    this.latitude,
    this.longitude,
    this.mapsEnabled = false,
    this.apiKey = '',
    this.mapLabel = 'Your home',
    super.key,
  });

  final ListingDraft draft;
  final void Function(int index, NearbyPlace place) onChanged;
  final double? latitude;
  final double? longitude;
  final bool mapsEnabled;
  final String apiKey;
  final String mapLabel;

  @override
  Widget build(BuildContext context) {
    final where = [
      draft.locality.trim(),
      draft.city.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return wizardAnchor(
      context,
      'nearby',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomiziMapView(
            key: const Key('listing-nearby-map'),
            mapsEnabled: mapsEnabled,
            apiKey: apiKey,
            latitude: latitude,
            longitude: longitude,
            label: mapLabel,
          ),
          const SizedBox(height: 12),
          Text(
            key: draft.nearby.isEmpty
                ? const Key('listing-nearby-empty')
                : const Key('listing-nearby-manual'),
            homiziText(
              context,
              draft.nearby.isEmpty
                  ? 'Add a locality first. Nearby places fill in from maps, or as estimates you can edit.'
                  : 'We show approximate distance and time. You can edit if needed.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
          ),
          if (where.isNotEmpty) ...[
            const SizedBox(height: 10),
            Chip(
              key: const Key('listing-nearby-place'),
              avatar: const Icon(
                Icons.place,
                color: HomiziColors.logoOrange,
                size: 18,
              ),
              label: Text(homiziText(context, where)),
              backgroundColor: HomiziColors.white,
              side: const BorderSide(color: HomiziColors.line),
            ),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < draft.nearby.length; index++)
            _NearbyRow(
              place: draft.nearby[index],
              onChanged: (place) => onChanged(index, place),
            ),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatefulWidget {
  const _NearbyRow({required this.place, required this.onChanged});

  final NearbyPlace place;
  final ValueChanged<NearbyPlace> onChanged;

  @override
  State<_NearbyRow> createState() => _NearbyRowState();
}

class _NearbyRowState extends State<_NearbyRow> {
  late final TextEditingController _name;
  late final TextEditingController _km;
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.place.name);
    _km = TextEditingController(text: _kmText(widget.place.km));
    _minutes = TextEditingController(text: _minutesText(widget.place.minutes));
  }

  @override
  void didUpdateWidget(_NearbyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.kind != widget.place.kind ||
        oldWidget.place.name != widget.place.name) {
      _name.text = widget.place.name;
      _km.text = _kmText(widget.place.km);
      _minutes.text = _minutesText(widget.place.minutes);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _km.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _emit() {
    final kmText = _km.text.trim();
    final minutesText = _minutes.text.trim();
    final km = kmText.isEmpty ? null : double.tryParse(kmText);
    final minutes = minutesText.isEmpty ? null : int.tryParse(minutesText);
    widget.onChanged(
      widget.place.copyWith(
        name: _name.text.trim(),
        km: km != null && km >= 0 ? km : null,
        minutes: minutes != null && minutes > 0 ? minutes : null,
        setDistance: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final color = nearbyKindColor(place.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(nearbyKindIcon(place.kind), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, nearbyKindLabel(place.kind)),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                    TextField(
                      key: Key('listing-nearby-${place.kind}-name'),
                      controller: _name,
                      onChanged: (_) => _emit(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Place name',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            key: Key('listing-nearby-${place.kind}-km'),
                            controller: _km,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _emit(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'km',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: TextField(
                            key: Key('listing-nearby-${place.kind}-minutes'),
                            controller: _minutes,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _emit(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'min',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            key: Key('listing-nearby-${place.kind}-time'),
                            homiziText(context, place.distanceLabel),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _kmText(double? km) {
  if (km == null || km < 0) {
    return '';
  }
  final text = km.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _minutesText(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '';
  }
  return '$minutes';
}

class LivingStep extends StatelessWidget {
  const LivingStep({
    required this.draft,
    required this.age,
    required this.waterHours,
    required this.onFurnishing,
    required this.onParking,
    required this.onWc,
    required this.onWater,
    required this.onAmenity,
    this.showAmenities = true,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController age;
  final TextEditingController waterHours;
  final ValueChanged<String> onFurnishing;
  final ValueChanged<String> onParking;
  final ValueChanged<String> onWc;
  final ValueChanged<String> onWater;
  final void Function(String key, bool selected) onAmenity;
  final bool showAmenities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChoiceLabel(icon: Icons.chair_outlined, label: 'Furnishing'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('furnished', 'Furnished'),
              ('semi_furnished', 'Semi-furnished'),
              ('unfurnished', 'Non-furnished'),
            ])
              FilterChip(
                key: Key('listing-furnishing-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.furnishing == item.$1,
                onSelected: (_) => onFurnishing(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        wizardAnchor(
          context,
          'parking',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ChoiceLabel(
                icon: Icons.local_parking_outlined,
                label: 'Parking',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    ('car', 'Car'),
                    ('bike', 'Bike'),
                    ('none', 'No parking'),
                  ])
                    FilterChip(
                      key: Key('listing-parking-${item.$1}'),
                      label: Text(homiziText(context, item.$2)),
                      selected: draft.parkingKind == item.$1,
                      onSelected: (_) => onParking(item.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        wizardAnchor(
          context,
          'age',
          TextField(
            key: const Key('listing-age'),
            focusNode: wizardFocus(context, 'age'),
            controller: age,
            keyboardType: TextInputType.number,
            inputFormatters: const [WholeAmountFormatter()],
            decoration: listingFieldDecoration(
              context,
              'Age of property (years)',
              Icons.calendar_today_outlined,
            ),
          ),
        ),
        const SizedBox(height: 12),
        wizardAnchor(
          context,
          'wc',
          _ListingMenu(
            fieldKey: const Key('listing-wc'),
            label: 'WC / bathroom type',
            icon: Icons.bathtub_outlined,
            value: draft.wcType,
            options: const [('separate', 'Separate'), ('shared', 'Shared')],
            onChanged: onWc,
          ),
        ),
        const SizedBox(height: 12),
        wizardAnchor(
          context,
          'water',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ListingMenu(
                fieldKey: const Key('listing-water'),
                label: 'Water supply',
                icon: Icons.water_drop_outlined,
                value: draft.waterSupply,
                options: const [
                  ('municipal', 'Municipal (24/7)'),
                  ('tanker', 'Tanker'),
                ],
                onChanged: onWater,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('listing-water-hours'),
                focusNode: wizardFocus(context, 'water'),
                controller: waterHours,
                decoration: listingFieldDecoration(
                  context,
                  'Water hours',
                  Icons.schedule_outlined,
                  hint: '24/7',
                ),
              ),
            ],
          ),
        ),
        if (showAmenities) ...[
          const SizedBox(height: 16),
          wizardAnchor(
            context,
            'amenities',
            const _ChoiceLabel(
              icon: Icons.chair_outlined,
              label: 'In-flat amenities',
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            children: [
              for (final key in inFlatAmenityKeys)
                Row(
                  key: Key('listing-amenity-$key'),
                  children: [
                    Checkbox(
                      value: draft.inFlatAmenities.contains(key),
                      onChanged: (selected) =>
                          onAmenity(key, selected ?? false),
                    ),
                    Icon(
                      _amenityIcon(key),
                      size: 18,
                      color: HomiziColors.logoOrange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        homiziText(context, _amenityTitle(key)),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: HomiziColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class RulesStep extends StatelessWidget {
  const RulesStep({
    required this.draft,
    required this.onPets,
    required this.onSmoking,
    required this.onSchedule,
    required this.onGuests,
    required this.onNonVeg,
    required this.onDrinking,
    required this.onPartying,
    required this.onSuitable,
    required this.onFriendlyTag,
    required this.onGender,
    required this.onOccupation,
    super.key,
  });

  final ListingDraft draft;
  final ValueChanged<bool> onPets;
  final ValueChanged<bool> onSmoking;
  final ValueChanged<String> onSchedule;
  final ValueChanged<bool> onGuests;
  final ValueChanged<bool> onNonVeg;
  final ValueChanged<bool> onDrinking;
  final ValueChanged<bool> onPartying;
  final ValueChanged<String> onSuitable;
  final ValueChanged<String> onFriendlyTag;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onOccupation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            'These are host preferences shown on the listing. Homizi does not use gender, religion, caste, or age to score a match.',
          ),
        ),
        const SizedBox(height: 12),
        wizardAnchor(
          context,
          'pets',
          YesNoField(
            label: 'Pets allowed',
            value: draft.petsChoice,
            yesKey: 'listing-pets-yes',
            noKey: 'listing-pets-no',
            onChanged: onPets,
          ),
        ),
        wizardAnchor(
          context,
          'smoking',
          YesNoField(
            label: 'Smoking allowed',
            value: draft.smokingChoice,
            yesKey: 'listing-smoking-yes',
            noKey: 'listing-smoking-no',
            onChanged: onSmoking,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Occupant schedule'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        wizardAnchor(
          context,
          'schedule',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const [
                ('early', 'Early', Icons.wb_sunny_outlined),
                ('flexible', 'Flexible', Icons.schedule_outlined),
                ('night', 'Night', Icons.bedtime_outlined),
              ])
                ChoiceChip(
                  key: Key('listing-schedule-${item.$1}'),
                  avatar: Icon(item.$3, size: 18),
                  label: Text(homiziText(context, item.$2)),
                  selected: draft.occupantSchedule == item.$1,
                  selectedColor: HomiziColors.logoOrange,
                  onSelected: (_) => onSchedule(item.$1),
                ),
            ],
          ),
        ),
        wizardAnchor(
          context,
          'guests',
          YesNoField(
            label: 'Guests allowed',
            value: draft.guestsAllowed,
            yesKey: 'listing-guests-yes',
            noKey: 'listing-guests-no',
            onChanged: onGuests,
          ),
        ),
        wizardAnchor(
          context,
          'nonveg',
          YesNoField(
            label: 'Non-veg allowed',
            value: draft.nonVegChoice,
            yesKey: 'listing-nonveg-yes',
            noKey: 'listing-nonveg-no',
            onChanged: onNonVeg,
          ),
        ),
        wizardAnchor(
          context,
          'drinking',
          YesNoField(
            label: 'Drinking allowed',
            value: draft.drinkingAllowed,
            yesKey: 'listing-drinking-yes',
            noKey: 'listing-drinking-no',
            onChanged: onDrinking,
          ),
        ),
        wizardAnchor(
          context,
          'partying',
          YesNoField(
            label: 'Partying allowed',
            value: draft.partyingAllowed,
            yesKey: 'listing-partying-yes',
            noKey: 'listing-partying-no',
            onChanged: onPartying,
          ),
        ),
        const SizedBox(height: 8),
        wizardAnchor(
          context,
          'suitable',
          Text(homiziText(context, 'Suitable for')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('bachelors', 'Bachelors'),
              ('couple', 'Couple'),
              ('married', 'Married'),
            ])
              FilterChip(
                key: Key('listing-suitable-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.suitableFor.contains(item.$1),
                onSelected: (_) => onSuitable(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Friendly tags')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('couple_friendly', 'Couple friendly'),
              ('lgbtq_friendly', 'LGBTQ+ friendly'),
            ])
              FilterChip(
                key: Key('listing-tag-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.friendlyTags.contains(item.$1),
                onSelected: (_) => onFriendlyTag(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        wizardAnchor(context, 'gender', Text(homiziText(context, 'Open for'))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [
              ('male', 'Male'),
              ('female', 'Female'),
              ('any', 'Any'),
            ])
              FilterChip(
                key: Key('listing-gender-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.genderPreference == item.$1,
                onSelected: (_) => onGender(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        wizardAnchor(
          context,
          'occupation',
          Text(homiziText(context, 'Preferred occupation')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('working_professional', 'Working professional'),
              ('student', 'Student'),
              ('actor', 'Actor / actress'),
              ('any', 'Any'),
            ])
              FilterChip(
                key: Key('listing-occupation-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: occupationChoices(
                  draft.preferredOccupation,
                ).contains(item.$1),
                onSelected: (_) => onOccupation(
                  toggleOccupation(draft.preferredOccupation, item.$1),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ServicesStep extends StatelessWidget {
  const ServicesStep({
    required this.draft,
    required this.flatmates,
    required this.possession,
    required this.highlights,
    required this.onCook,
    required this.onMaid,
    required this.onConsent,
    this.hidePossession = false,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController flatmates;
  final TextEditingController possession;
  final TextEditingController highlights;
  final ValueChanged<bool> onCook;
  final ValueChanged<bool> onMaid;
  final ValueChanged<bool> onConsent;
  final bool hidePossession;

  @override
  Widget build(BuildContext context) {
    final shared = showsFlatmates(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wizardAnchor(
          context,
          'cook',
          YesNoField(
            label: 'Cook service',
            value: draft.cookService,
            yesKey: 'listing-cook-yes',
            noKey: 'listing-cook-no',
            onChanged: onCook,
          ),
        ),
        wizardAnchor(
          context,
          'maid',
          YesNoField(
            label: 'Maid service',
            value: draft.maidService,
            yesKey: 'listing-maid-yes',
            noKey: 'listing-maid-no',
            onChanged: onMaid,
          ),
        ),
        if (shared) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('listing-flatmates'),
            controller: flatmates,
            maxLength: 240,
            maxLines: 3,
            decoration: listingFieldDecoration(
              context,
              'Existing flatmates (brief)',
              Icons.groups_outlined,
              hint: '2 working professionals, 1 male and 1 female, IT sector',
            ),
          ),
          Material(
            color: HomiziColors.white,
            child: SwitchListTile(
              key: const Key('listing-flatmate-consent'),
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, 'Link Homizi profiles')),
              subtitle: Text(
                homiziText(
                  context,
                  'Only with each flatmate\'s consent. Names stay off the public card until they agree.',
                ),
              ),
              value: draft.linkFlatmateProfiles,
              onChanged: onConsent,
            ),
          ),
        ],
        if (!hidePossession) ...[
          const SizedBox(height: 8),
          wizardAnchor(
            context,
            'possession',
            HomiziDateField(
              fieldKey: const Key('listing-possession'),
              controller: possession,
              label: 'Possession date',
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              initialWhenEmpty: DateTime(2026, 12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-highlights'),
          controller: highlights,
          maxLength: 280,
          maxLines: 3,
          decoration: listingFieldDecoration(
            context,
            'Other highlights',
            Icons.wb_sunny_outlined,
            hint: 'Well-lit, close to the metro, good natural light',
          ),
        ),
      ],
    );
  }
}

class ChargesStep extends StatelessWidget {
  const ChargesStep({
    required this.draft,
    required this.rent,
    required this.deposit,
    required this.brokerage,
    required this.oneTime,
    required this.maintenance,
    required this.electricity,
    required this.water,
    required this.wifi,
    required this.other,
    required this.brokerageTerms,
    required this.showBroker,
    this.hideRent = false,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController rent;
  final TextEditingController deposit;
  final TextEditingController brokerage;
  final TextEditingController oneTime;
  final TextEditingController maintenance;
  final TextEditingController electricity;
  final TextEditingController water;
  final TextEditingController wifi;
  final TextEditingController other;
  final TextEditingController brokerageTerms;
  final bool showBroker;
  final bool hideRent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideRent)
          _money(
            context,
            key: 'listing-rent',
            anchor: 'rent',
            controller: rent,
            label: 'Monthly rent (₹)',
          ),
        _money(
          context,
          key: 'listing-deposit',
          anchor: 'deposit',
          controller: deposit,
          label: 'Security deposit (₹)',
        ),
        _money(
          context,
          key: 'listing-charges',
          anchor: 'brokerage',
          controller: brokerage,
          label: 'Brokerage (₹)',
        ),
        _money(
          context,
          key: 'listing-onetime',
          anchor: 'oneTime',
          controller: oneTime,
          label: 'One-time charges (₹)',
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Recurring monthly charges')),
        const SizedBox(height: 8),
        _money(
          context,
          key: 'listing-maintenance',
          anchor: 'maintenance',
          controller: maintenance,
          label: 'Maintenance (₹)',
        ),
        _money(
          context,
          key: 'listing-electricity',
          anchor: 'electricity',
          controller: electricity,
          label: 'Electricity (₹)',
        ),
        _money(
          context,
          key: 'listing-water-charge',
          anchor: 'waterCharge',
          controller: water,
          label: 'Water (₹)',
        ),
        _money(
          context,
          key: 'listing-wifi-charge',
          anchor: 'wifi',
          controller: wifi,
          label: 'Wi-Fi (₹)',
        ),
        _money(
          context,
          key: 'listing-other-monthly',
          controller: other,
          label: 'Other monthly (₹)',
        ),
        if (showBroker) ...[
          const SizedBox(height: 8),
          const BrokerChip(),
          const SizedBox(height: 8),
          TextField(
            key: const Key('listing-brokerage-terms'),
            controller: brokerageTerms,
            maxLength: 160,
            decoration: listingFieldDecoration(
              context,
              'Brokerage terms',
              Icons.handshake_outlined,
              hint: 'One month rent, paid when the agreement is signed',
            ),
          ),
        ],
        const SizedBox(height: 16),
        _LiveChargeSummary(
          rent: rent,
          deposit: deposit,
          brokerage: brokerage,
          oneTime: oneTime,
          maintenance: maintenance,
          electricity: electricity,
          water: water,
          wifi: wifi,
          other: other,
        ),
      ],
    );
  }

  Widget _money(
    BuildContext context, {
    required String key,
    required TextEditingController controller,
    required String label,
    String? anchor,
  }) {
    final field = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        focusNode: anchor == null ? null : wizardFocus(context, anchor),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [WholeAmountFormatter()],
        decoration: listingFieldDecoration(
          context,
          label,
          Icons.currency_rupee,
        ),
      ),
    );
    if (anchor == null) {
      return field;
    }
    return wizardAnchor(context, anchor, field);
  }
}

class _LiveChargeSummary extends StatefulWidget {
  const _LiveChargeSummary({
    required this.rent,
    required this.deposit,
    required this.brokerage,
    required this.oneTime,
    required this.maintenance,
    required this.electricity,
    required this.water,
    required this.wifi,
    required this.other,
  });

  final TextEditingController rent;
  final TextEditingController deposit;
  final TextEditingController brokerage;
  final TextEditingController oneTime;
  final TextEditingController maintenance;
  final TextEditingController electricity;
  final TextEditingController water;
  final TextEditingController wifi;
  final TextEditingController other;

  @override
  State<_LiveChargeSummary> createState() => _LiveChargeSummaryState();
}

class _LiveChargeSummaryState extends State<_LiveChargeSummary> {
  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  @override
  void didUpdateWidget(_LiveChargeSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = [
      oldWidget.rent,
      oldWidget.deposit,
      oldWidget.brokerage,
      oldWidget.oneTime,
      oldWidget.maintenance,
      oldWidget.electricity,
      oldWidget.water,
      oldWidget.wifi,
      oldWidget.other,
    ];
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] == _controllers[index]) {
        continue;
      }
      previous[index].removeListener(_refresh);
      _controllers[index].addListener(_refresh);
    }
  }

  List<TextEditingController> get _controllers => [
    widget.rent,
    widget.deposit,
    widget.brokerage,
    widget.oneTime,
    widget.maintenance,
    widget.electricity,
    widget.water,
    widget.wifi,
    widget.other,
  ];

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_refresh);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = RentingCost.fromTexts(
      rent: widget.rent.text,
      deposit: widget.deposit.text,
      brokerage: widget.brokerage.text,
      oneTime: widget.oneTime.text,
      maintenance: widget.maintenance.text,
      electricity: widget.electricity.text,
      water: widget.water.text,
      wifi: widget.wifi.text,
      otherMonthly: widget.other.text,
    );
    return RentCostBreakdown(cost: cost, detailed: true, live: true);
  }
}

class PhotosStep extends StatelessWidget {
  const PhotosStep({
    required this.draft,
    required this.onSamples,
    required this.onManage,
    super.key,
  });

  final ListingDraft draft;
  final VoidCallback onSamples;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final photo in draft.photos) photo.label];
    return wizardAnchor(
      context,
      'photos',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(
              context,
              'Minimum 3 photos. Follow the sequence. Balcony is optional.',
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < photoSequence.length; index++) ...[
            _PhotoLine(
              index: index + 1,
              label: photoSlotTitle(photoSequence[index]),
              done: labels.contains(photoSequence[index]),
              optional: photoSequence[index] == 'Balcony',
            ),
            if (index < photoSequence.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 18),
                child: Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: HomiziColors.muted,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Photo tips'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final tip in photoTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(homiziText(context, '• $tip')),
            ),
          for (final gap in photoQualityGaps(draft.photos))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                homiziText(context, gap),
                key: const Key('listing-photo-quality'),
                style: const TextStyle(color: HomiziColors.error),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('listing-photo-samples'),
            onPressed: onSamples,
            child: Text(homiziText(context, 'Use sample photos')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onManage,
            child: Text(homiziText(context, 'Manage photos')),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              draft.photos.isEmpty
                  ? 'No photos yet.'
                  : '${draft.photos.length} photos ready.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoLine extends StatelessWidget {
  const _PhotoLine({
    required this.index,
    required this.label,
    required this.done,
    required this.optional,
  });

  final int index;
  final String label;
  final bool done;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final text = optional ? '$label (optional)' : label;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: done ? HomiziColors.accent : HomiziColors.mist,
        foregroundColor: done ? HomiziColors.ink : HomiziColors.muted,
        child: Text('$index'),
      ),
      title: Text(homiziText(context, text)),
      trailing: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? HomiziColors.accent : HomiziColors.muted,
      ),
    );
  }
}

/// Keeps rupee and area fields as whole numbers and drops leading zeros.
class WholeAmountFormatter extends TextInputFormatter {
  const WholeAmountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
      if (digits.isEmpty) {
        digits = '0';
      }
    }
    if (digits == newValue.text) {
      return newValue;
    }
    final base = newValue.selection.baseOffset;
    final offset = base < 0 ? digits.length : base.clamp(0, digits.length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class _PrivateFlatNote extends StatelessWidget {
  const _PrivateFlatNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listing-flat-private'),
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
    );
  }
}

class _ListingMenu extends StatelessWidget {
  const _ListingMenu({
    required this.fieldKey,
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final IconData icon;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = options.any((option) => option.$1 == value);
    return KeyedSubtree(
      key: fieldKey,
      child: KitChoiceField<String>(
        label: label,
        icon: icon,
        dense: true,
        selected: known ? value : null,
        options: [
          for (final option in options)
            KitOption(value: option.$1, label: option.$2, icon: icon),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ChoiceLabel extends StatelessWidget {
  const _ChoiceLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: HomiziColors.logoOrange, size: 20),
          const SizedBox(width: 8),
          Text(
            homiziText(context, label),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _amenityIcon(String key) => switch (key) {
  'wifi' => Icons.wifi,
  'fridge' => Icons.kitchen_outlined,
  'ac' => Icons.ac_unit,
  'fans' => Icons.air,
  'washing_machine' => Icons.local_laundry_service_outlined,
  'tv' => Icons.tv_outlined,
  'gas_pipeline' => Icons.local_fire_department_outlined,
  _ => Icons.check_box_outline_blank,
};

String _amenityTitle(String key) => switch (key) {
  'wifi' => 'WiFi',
  'gas_pipeline' => 'Gas pipe connection',
  _ => listingAmenityLabel(key),
};

class WizardChoice extends StatelessWidget {
  const WizardChoice({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OptionTile(
      label: homiziText(context, title),
      subtitle: subtitle == null ? null : homiziText(context, subtitle!),
      icon: icon,
      selected: selected,
      onTap: onTap,
    );
  }
}

class YesNoField extends StatelessWidget {
  const YesNoField({
    required this.label,
    required this.value,
    required this.yesKey,
    required this.noKey,
    required this.onChanged,
    this.icon = Icons.tune_outlined,
    super.key,
  });

  final String label;
  final bool? value;
  final String yesKey;
  final String noKey;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: HomiziColors.logoOrange, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(homiziText(context, label))),
          IconChoiceChip(
            key: Key(yesKey),
            multi: false,
            label: Text(homiziText(context, 'Yes')),
            selected: value == true,
            onSelected: (_) => onChanged(true),
          ),
          const SizedBox(width: 8),
          IconChoiceChip(
            key: Key(noKey),
            multi: false,
            label: Text(homiziText(context, 'No')),
            selected: value == false,
            onSelected: (_) => onChanged(false),
          ),
        ],
      ),
    );
  }
}
