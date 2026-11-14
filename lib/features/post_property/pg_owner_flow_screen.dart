import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart' hide NearbyPlace;
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/post_property/owner_extras.dart';
import 'package:homizi/features/post_property/post_confirm_screen.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/publish/publish_gate.dart';

const pgOwnerSteps = ['Basic Info', 'PG Details', 'Verification'];

const pgAmenityChoices = <(String, String)>[
  ('wifi', 'Wi-Fi'),
  ('washing_machine', 'Laundry'),
  ('ac', 'AC'),
  ('power_backup', 'Power backup'),
  ('security', 'CCTV'),
  ('fridge', 'Fridge'),
  ('tv', 'TV'),
];

class PgPostOutcomeController extends Notifier<OwnerPostOutcome?> {
  @override
  OwnerPostOutcome? build() => null;

  void set(OwnerPostOutcome? next) => state = next;
}

final pgPostOutcomeProvider =
    NotifierProvider<PgPostOutcomeController, OwnerPostOutcome?>(
      PgPostOutcomeController.new,
    );

class PgOwnerFlowScreen extends ConsumerStatefulWidget {
  const PgOwnerFlowScreen({super.key});

  @override
  ConsumerState<PgOwnerFlowScreen> createState() => _PgOwnerFlowScreenState();
}

class _PgOwnerFlowScreenState extends ConsumerState<PgOwnerFlowScreen> {
  var _page = 0;
  var _busy = false;
  String? _note;
  String _city = 'Bengaluru';
  String _gender = 'boys';
  String _food = 'veg';
  var _meals = true;
  var _single = true;
  var _double = true;
  var _triple = false;
  TimeOfDay _gate = const TimeOfDay(hour: 22, minute: 0);
  final _amenities = <String>{'wifi', 'power_backup', 'security'};
  final _name = TextEditingController(text: 'Sunrise PG, Koramangala');
  final _locality = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _singlePrice = TextEditingController(text: '14000');
  final _doublePrice = TextEditingController(text: '9000');
  final _triplePrice = TextEditingController(text: '7000');
  final _rules = TextEditingController(
    text: 'No smoking in rooms. Visitors until 8 PM. Quiet hours after 10 PM.',
  );
  double? _lat;
  double? _lng;
  List<NearbyPlace> _nearby = const [];
  List<PhotoSlot> _photos = const [];

  @override
  void dispose() {
    _name.dispose();
    _locality.dispose();
    _address.dispose();
    _landmark.dispose();
    _singlePrice.dispose();
    _doublePrice.dispose();
    _triplePrice.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _back() {
    if (_page > 0) {
      setState(() {
        _page -= 1;
        _note = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.postProperty);
  }

  String? _detailsError() {
    if (_name.text.trim().length < 3) {
      return 'Add the PG name.';
    }
    if (_locality.text.trim().length < 2) {
      return 'Add the locality.';
    }
    if (_city.trim().isEmpty) {
      return 'Choose a city.';
    }
    final prices = _prices();
    if (prices.isEmpty) {
      return 'Choose a sharing type and a price per bed.';
    }
    if (_photos.length < 3) {
      return 'Add at least 3 photos, or use the sample set.';
    }
    return null;
  }

  List<int> _prices() {
    int? read(bool on, TextEditingController controller) {
      if (!on) {
        return null;
      }
      final value = int.tryParse(controller.text.trim());
      if (value == null || value <= 0) {
        return null;
      }
      return value;
    }

    return [
      if (read(_single, _singlePrice) != null) read(_single, _singlePrice)!,
      if (read(_double, _doublePrice) != null) read(_double, _doublePrice)!,
      if (read(_triple, _triplePrice) != null) read(_triple, _triplePrice)!,
    ];
  }

  void _continue() {
    if (_page == 0) {
      setState(() {
        _page = 1;
        _note = null;
      });
      return;
    }
    final error = _detailsError();
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    setState(() {
      _page = 2;
      _note = null;
    });
  }

  Future<void> _pickPlace(PlaceSuggestion place) async {
    final parts = [
      for (final part in place.label.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final known = {...exploreCities, ...personalCities};
    String? city;
    for (final part in parts.skip(1)) {
      for (final name in known) {
        if (name.toLowerCase() == part.toLowerCase()) {
          city = name;
          break;
        }
      }
      if (city != null) {
        break;
      }
    }
    final locality = (place.locality ?? '').trim().isNotEmpty
        ? place.locality!.trim()
        : (parts.isEmpty ? place.label : parts.first);
    final nextCity = city ?? _city;
    setState(() {
      _locality.text = locality;
      _city = nextCity;
      _lat = place.latitude ?? _lat;
      _lng = place.longitude ?? _lng;
      _nearby = nearbyPlacesFor(city: nextCity, locality: locality);
      _note = null;
    });
    if (!place.hasCoordinates) {
      return;
    }
    final service = ref.read(locationServiceProvider);
    final rows = await measureNearbyCommute(
      service: service,
      origin: GeoFix(latitude: place.latitude!, longitude: place.longitude!),
      city: nextCity,
      locality: locality,
      mapsApiKey: ref.read(appConfigProvider).mapsApiKey,
    );
    if (!mounted || rows.isEmpty) {
      return;
    }
    setState(() => _nearby = rows);
  }

  Future<void> _pickGate() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _gate,
      helpText: homiziText(context, 'Gate closes'),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: HomiziColors.logoOrange,
              onPrimary: HomiziColors.ink,
              surface: HomiziColors.white,
              onSurface: HomiziColors.ink,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _gate = picked);
    }
  }

  Future<void> _addPhoto() async {
    try {
      final picked = await ref.read(photoFilePickerProvider).pick();
      if (picked == null || !mounted) {
        return;
      }
      final slot =
          photoSequence[_photos.length.clamp(0, photoSequence.length - 1)];
      setState(() {
        _photos = [
          ..._photos,
          PhotoSlot(
            label: slot,
            isPrimary: _photos.isEmpty,
            bytes: picked.bytes,
            contentType: picked.contentType,
          ),
        ];
        _note = null;
      });
    } on PhotoPickUnavailable catch (error) {
      if (mounted) {
        setState(() => _note = error.toString());
      }
    }
  }

  String _summary() {
    final beds = <String>[
      if (_single) 'Single ₹${_singlePrice.text.trim()}',
      if (_double) 'Double ₹${_doublePrice.text.trim()}',
      if (_triple) 'Triple ₹${_triplePrice.text.trim()}',
    ].join(', ');
    final food = switch (_food) {
      'nonveg' => 'Non-veg kitchen',
      'none' => 'No food',
      _ => 'Veg kitchen',
    };
    final meals = _meals && _food != 'none' ? 'Meals included' : 'Meals extra';
    final who = switch (_gender) {
      'girls' => 'Girls',
      'coliving' => 'Co-living',
      _ => 'Boys',
    };
    final gate = _gate.format(context);
    final rules = _rules.text.trim();
    final text =
        '$who PG. $beds per bed. $food. $meals. Gate closes $gate. $rules';
    return text.length <= 280 ? text : text.substring(0, 280);
  }

  Future<void> _publish({required bool verifyLater}) async {
    final error = _detailsError();
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    if (!await requireSignedInToPublish(context, ref)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final prices = _prices();
    final rent = prices.reduce((a, b) => a < b ? a : b);
    final draft = ListingDraft(
      title: _name.text.trim(),
      city: _city,
      locality: _locality.text.trim(),
      addressLine: _address.text.trim(),
      landmark: _landmark.text.trim(),
      propertyType: 'pg',
      buildingKind: 'pg',
      rentText: '$rent',
      genderPreference: switch (_gender) {
        'girls' => 'female',
        'coliving' => 'any',
        _ => 'male',
      },
      amenities: _amenities.toList(),
      highlights: _summary(),
      latitude: _lat,
      longitude: _lng,
      photos: _photos,
      nearby: _nearby,
      nonVegChoice: switch (_food) {
        'nonveg' => true,
        'veg' => false,
        _ => null,
      },
      restrictions: const ['no_smoking'],
    );
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .publishListing(draft);
      if (!mounted) {
        return;
      }
      rememberPublishedHome(
        ref,
        result.draft,
        onServer: result.publishedByServer,
      );
      ref
          .read(pgPostOutcomeProvider.notifier)
          .set(
            OwnerPostOutcome(
              draft: result.draft,
              verifyLater: verifyLater,
              serverPublished: result.publishedByServer,
            ),
          );
      setState(() => _busy = false);
      context.go(RoutePaths.postPgDone);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _note = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PostPropertyPage(
      pageKey: const Key('post-pg-flow'),
      onBack: _back,
      footer: PostGradientButton(
        buttonKey: const Key('post-pg-continue'),
        label: _page == 2 ? 'Publish listing' : 'Continue',
        busy: _busy,
        onPressed: _busy
            ? null
            : () {
                if (_page < 2) {
                  _continue();
                  return;
                }
                final docs = ref.read(ownerDocsProvider);
                unawaited(_publish(verifyLater: !docs.any));
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          PostStepper(labels: pgOwnerSteps, index: _page),
          const SizedBox(height: 16),
          if (_page == 0) const OwnerContactFields(),
          if (_page == 1) _details(),
          if (_page == 2)
            OwnerVerifyPanel(
              onVerifyLater: () => unawaited(_publish(verifyLater: true)),
            ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note!),
              key: const Key('post-pg-note'),
              style: const TextStyle(color: HomiziColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _details() {
    final cities = [
      ...exploreCities,
      if (!exploreCities.contains(_city)) _city,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'PG Details'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-pg-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'PG name',
            Icons.holiday_village_outlined,
            hint: 'Sunrise PG, Koramangala',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('post-pg-city'),
          initialValue: cities.contains(_city) ? _city : null,
          isExpanded: true,
          decoration: postFieldDecoration(
            context,
            'City',
            Icons.location_city_outlined,
          ),
          items: [
            for (final city in cities)
              DropdownMenuItem(value: city, child: Text(city)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _city = value);
            }
          },
        ),
        const SizedBox(height: 12),
        PlaceAutocompleteField(
          fieldKey: const Key('post-pg-locality'),
          controller: _locality,
          textCapitalization: TextCapitalization.words,
          biasPoint: cityCentreFor(_city),
          decoration: postFieldDecoration(
            context,
            'Locality and area',
            Icons.place_outlined,
            hint: 'Koramangala 5th Block',
          ),
          onSelected: (place) => unawaited(_pickPlace(place)),
        ),
        const SizedBox(height: 12),
        PlaceAutocompleteField(
          fieldKey: const Key('post-pg-address'),
          controller: _address,
          textCapitalization: TextCapitalization.words,
          biasPoint: cityCentreFor(_city),
          decoration: postFieldDecoration(
            context,
            'Street address',
            Icons.signpost_outlined,
            hint: '18, 4th Cross, Koramangala',
          ),
          onSelected: (place) => unawaited(_pickPlace(place)),
        ),
        const SizedBox(height: 12),
        PlaceAutocompleteField(
          fieldKey: const Key('post-pg-landmark'),
          controller: _landmark,
          textCapitalization: TextCapitalization.words,
          biasPoint: cityCentreFor(_city),
          decoration: postFieldDecoration(
            context,
            'Landmark',
            Icons.flag_outlined,
            hint: 'Near Forum Mall',
          ),
          onSelected: (place) => unawaited(_pickPlace(place)),
        ),
        if (_nearby.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Nearby places'),
            key: const Key('post-pg-nearby'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final place in _nearby)
                if (place.name.trim().isNotEmpty) PostChip(label: place.name),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Who is it for?'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [
              ('boys', 'Boys'),
              ('girls', 'Girls'),
              ('coliving', 'Co-living'),
            ])
              ChoiceChip(
                key: Key('post-pg-gender-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: _gender == item.$1,
                onSelected: (_) => setState(() => _gender = item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Beds and sharing'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _bed(
          'single',
          'Single',
          _single,
          (value) => _single = value,
          _singlePrice,
        ),
        _bed(
          'double',
          'Double',
          _double,
          (value) => _double = value,
          _doublePrice,
        ),
        _bed(
          'triple',
          'Triple',
          _triple,
          (value) => _triple = value,
          _triplePrice,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Food'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [
              ('veg', 'Veg'),
              ('nonveg', 'Non-veg'),
              ('none', 'None'),
            ])
              ChoiceChip(
                key: Key('post-pg-food-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: _food == item.$1,
                onSelected: (_) => setState(() => _food = item.$1),
              ),
          ],
        ),
        SwitchListTile(
          key: const Key('post-pg-meals'),
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Meals included')),
          value: _meals,
          onChanged: _food == 'none'
              ? null
              : (value) => setState(() => _meals = value),
        ),
        Text(
          homiziText(context, 'Amenities'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in pgAmenityChoices)
              FilterChip(
                key: Key('post-pg-amenity-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: _amenities.contains(item.$1),
                onSelected: (on) => setState(() {
                  if (on) {
                    _amenities.add(item.$1);
                  } else {
                    _amenities.remove(item.$1);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('post-pg-rules'),
          controller: _rules,
          maxLines: 3,
          maxLength: 280,
          decoration: postFieldDecoration(
            context,
            'House rules',
            Icons.rule_outlined,
            hint: 'No smoking in rooms. Visitors until 8 PM.',
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('post-pg-gate'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, color: HomiziColors.logoOrange),
          title: Text(homiziText(context, 'Gate timing')),
          subtitle: Text(
            '${homiziText(context, 'Closes')} ${_gate.format(context)}',
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => unawaited(_pickGate()),
        ),
        const SizedBox(height: 8),
        PropertyPhotoUploadCard(onTap: () => unawaited(_addPhoto())),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('post-pg-samples'),
          onPressed: () => setState(() {
            _photos = wizardSamplePhotos;
            _note = null;
          }),
          child: Text(homiziText(context, 'Use sample photos')),
        ),
        if (_photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              homiziText(context, '${_photos.length} photos added'),
              key: const Key('post-pg-photo-count'),
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
          ),
      ],
    );
  }

  Widget _bed(
    String id,
    String label,
    bool on,
    ValueChanged<bool> toggle,
    TextEditingController price,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          FilterChip(
            key: Key('post-pg-share-$id'),
            label: Text(homiziText(context, label)),
            selected: on,
            onSelected: (value) => setState(() => toggle(value)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('post-pg-price-$id'),
              controller: price,
              enabled: on,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: postFieldDecoration(
                context,
                'Price per bed',
                Icons.currency_rupee,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PgPostedScreen extends ConsumerWidget {
  const PgPostedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(pgPostOutcomeProvider);
    final draft = outcome?.draft;
    final title = draft == null || draft.title.trim().isEmpty
        ? 'Your PG'
        : draft.title.trim();
    final place = [
      if (draft != null && draft.locality.trim().isNotEmpty)
        draft.locality.trim(),
      if (draft != null && draft.city.trim().isNotEmpty) draft.city.trim(),
    ].join(', ');
    return PostPropertyPage(
      pageKey: const Key('post-pg-done'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Icon(Icons.check_circle, size: 64, color: HomiziColors.success),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'PG listing published'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (place.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                place,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HomiziColors.inkSoft),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              outcome?.serverPublished == true
                  ? 'Your PG is live and appears in search.'
                  : 'This PG is on this device and shows in search here.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 16),
          const PostTrustPill(
            text: 'Beds, meals, and house rules are on the listing.',
          ),
          const SizedBox(height: 20),
          PostGradientButton(
            buttonKey: const Key('post-pg-home'),
            label: 'Back to Home',
            showArrow: false,
            onPressed: () => context.go(RoutePaths.home),
          ),
        ],
      ),
    );
  }
}
