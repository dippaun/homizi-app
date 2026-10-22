import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/rent_cost_breakdown.dart';

class IntentStep extends StatelessWidget {
  const IntentStep({
    required this.draft,
    required this.title,
    required this.onIntent,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController title;
  final ValueChanged<String> onIntent;

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
        const SizedBox(height: 16),
        TextField(
          key: const Key('listing-title'),
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Listing title'),
            hintText: homiziText(
              context,
              'Private room in a 2BHK, Bandra West',
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final option in listingIntentOptions) ...[
          WizardChoice(
            key: Key('listing-intent-${option.$1}'),
            title: option.$2,
            subtitle: option.$3,
            selected: draft.listingIntent == option.$1,
            onTap: () => onIntent(option.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
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
    required this.address,
    required this.landmark,
    required this.onCity,
    required this.onLocality,
    required this.onBuildingKind,
    required this.onConfiguration,
    required this.onRentable,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController locality;
  final TextEditingController building;
  final TextEditingController area;
  final TextEditingController floor;
  final TextEditingController totalFloors;
  final TextEditingController address;
  final TextEditingController landmark;
  final ValueChanged<String> onCity;
  final ValueChanged<String> onLocality;
  final ValueChanged<String> onBuildingKind;
  final ValueChanged<String> onConfiguration;
  final ValueChanged<String> onRentable;

  @override
  Widget build(BuildContext context) {
    final cities = [
      ...exploreCities,
      if (draft.city.isNotEmpty && !exploreCities.contains(draft.city))
        draft.city,
    ];
    final places = [
      for (final place in localitySeed)
        if (place.city == (draft.city.isEmpty ? 'Mumbai' : draft.city))
          place.name,
    ];
    final showFloors = floorApplies(draft.buildingKind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('listing-city'),
          initialValue: draft.city.isEmpty ? null : draft.city,
          decoration: InputDecoration(labelText: homiziText(context, 'City')),
          items: [
            for (final city in cities)
              DropdownMenuItem(
                value: city,
                child: Text(homiziText(context, city)),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              onCity(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-locality'),
          controller: locality,
          textCapitalization: TextCapitalization.words,
          onChanged: onLocality,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Locality / neighbourhood'),
          ),
        ),
        if (places.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in places)
                FilterChip(
                  label: Text(homiziText(context, name)),
                  selected: draft.locality == name,
                  onSelected: (_) => onLocality(name),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-building'),
          controller: building,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Tower / building name'),
            hintText: homiziText(context, 'Sea View Residency'),
          ),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Property type')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in buildingKindOptions)
              FilterChip(
                key: Key('listing-kind-${option.$1}'),
                label: Text(homiziText(context, option.$2)),
                selected: draft.buildingKind == option.$1,
                onSelected: (_) => onBuildingKind(option.$1),
              ),
          ],
        ),
        if (showFloors) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('listing-floor'),
            controller: floor,
            keyboardType: TextInputType.number,
            inputFormatters: const [WholeAmountFormatter()],
            decoration: InputDecoration(
              labelText: homiziText(context, 'Floor number'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('listing-total-floors'),
            controller: totalFloors,
            keyboardType: TextInputType.number,
            inputFormatters: const [WholeAmountFormatter()],
            decoration: InputDecoration(
              labelText: homiziText(context, 'Total floors'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(homiziText(context, 'Configuration')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in configurationOptions)
              FilterChip(
                key: Key('listing-config-${option.$1}'),
                label: Text(option.$2),
                selected: draft.configuration == option.$1,
                onSelected: (_) => onConfiguration(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-area'),
          controller: area,
          keyboardType: TextInputType.number,
          inputFormatters: const [WholeAmountFormatter()],
          decoration: InputDecoration(
            labelText: homiziText(context, 'Total area (sq ft)'),
          ),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Area available for rent')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in rentableAreaOptions)
              FilterChip(
                key: Key('listing-rentable-${option.$1}'),
                label: Text(homiziText(context, option.$2)),
                selected: draft.rentableArea == option.$1,
                onSelected: (_) => onRentable(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-address'),
          controller: address,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Street address'),
            helperText: homiziText(
              context,
              'Saved privately. Shown only after a visit is agreed.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-landmark'),
          controller: landmark,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Landmark'),
          ),
        ),
      ],
    );
  }
}

class NearbyStep extends StatelessWidget {
  const NearbyStep({required this.draft, required this.onChanged, super.key});

  final ListingDraft draft;
  final void Function(int index, NearbyPlace place) onChanged;

  @override
  Widget build(BuildContext context) {
    if (draft.nearby.isEmpty) {
      return Text(
        homiziText(
          context,
          'Add a locality first. Nearby places are estimated from it, with travel time.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            'Estimated from the locality. Edit a name, the distance, or the minutes.',
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < draft.nearby.length; index++)
          _NearbyRow(
            place: draft.nearby[index],
            onChanged: (place) => onChanged(index, place),
          ),
      ],
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
    _minutes = TextEditingController(text: '${widget.place.minutes}');
  }

  @override
  void didUpdateWidget(_NearbyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.kind != widget.place.kind ||
        oldWidget.place.name != widget.place.name) {
      _name.text = widget.place.name;
      _km.text = _kmText(widget.place.km);
      _minutes.text = '${widget.place.minutes}';
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
    final km = double.tryParse(_km.text.trim());
    final minutes = int.tryParse(_minutes.text.trim());
    widget.onChanged(
      widget.place.copyWith(
        name: _name.text.trim().isEmpty ? widget.place.name : _name.text.trim(),
        km: km == null || km < 0 ? widget.place.km : km,
        minutes: minutes == null || minutes < 0
            ? widget.place.minutes
            : minutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, nearbyKindLabel(place.kind)),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          TextField(
            key: Key('listing-nearby-${place.kind}-name'),
            controller: _name,
            onChanged: (_) => _emit(),
            decoration: InputDecoration(
              labelText: homiziText(context, 'Place'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('listing-nearby-${place.kind}-km'),
                  controller: _km,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _emit(),
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'km'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: Key('listing-nearby-${place.kind}-minutes'),
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _emit(),
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'minutes'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            key: Key('listing-nearby-${place.kind}-time'),
            homiziText(
              context,
              '${_kmText(place.km)} km · ${place.minutes} min',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _kmText(double km) {
  final text = km.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(homiziText(context, 'Furnishing')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('unfurnished', 'Unfurnished'),
              ('semi_furnished', 'Semi-furnished'),
              ('furnished', 'Furnished'),
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
        Text(homiziText(context, 'Parking')),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-age'),
          controller: age,
          keyboardType: TextInputType.number,
          inputFormatters: const [WholeAmountFormatter()],
          decoration: InputDecoration(
            labelText: homiziText(context, 'Age of property (years)'),
          ),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'WC / bathroom')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [
              ('separate', 'Separate'),
              ('shared', 'Shared'),
            ])
              FilterChip(
                key: Key('listing-wc-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.wcType == item.$1,
                onSelected: (_) => onWc(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Water supply')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final item in const [
              ('municipal', 'Municipal'),
              ('tanker', 'Tanker'),
            ])
              FilterChip(
                key: Key('listing-water-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.waterSupply == item.$1,
                onSelected: (_) => onWater(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-water-hours'),
          controller: waterHours,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Water hours'),
            hintText: homiziText(context, '24/7'),
          ),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'In-flat amenities')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in inFlatAmenityKeys)
              FilterChip(
                key: Key('listing-amenity-$key'),
                label: Text(
                  homiziText(
                    context,
                    key == 'wifi' ? 'Wi-Fi' : listingAmenityLabel(key),
                  ),
                ),
                selected: draft.inFlatAmenities.contains(key),
                onSelected: (selected) => onAmenity(key, selected),
              ),
          ],
        ),
      ],
    );
  }
}

class RulesStep extends StatelessWidget {
  const RulesStep({
    required this.draft,
    required this.onPets,
    required this.onGuests,
    required this.onNonVeg,
    required this.onDrinking,
    required this.onPartying,
    required this.onSuitable,
    required this.onGender,
    required this.onOccupation,
    super.key,
  });

  final ListingDraft draft;
  final ValueChanged<bool> onPets;
  final ValueChanged<bool> onGuests;
  final ValueChanged<bool> onNonVeg;
  final ValueChanged<bool> onDrinking;
  final ValueChanged<bool> onPartying;
  final ValueChanged<String> onSuitable;
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
        YesNoField(
          label: 'Pets allowed',
          value: draft.petsChoice,
          yesKey: 'listing-pets-yes',
          noKey: 'listing-pets-no',
          onChanged: onPets,
        ),
        YesNoField(
          label: 'Guests allowed',
          value: draft.guestsAllowed,
          yesKey: 'listing-guests-yes',
          noKey: 'listing-guests-no',
          onChanged: onGuests,
        ),
        YesNoField(
          label: 'Non-veg allowed',
          value: draft.nonVegChoice,
          yesKey: 'listing-nonveg-yes',
          noKey: 'listing-nonveg-no',
          onChanged: onNonVeg,
        ),
        YesNoField(
          label: 'Drinking allowed',
          value: draft.drinkingAllowed,
          yesKey: 'listing-drinking-yes',
          noKey: 'listing-drinking-no',
          onChanged: onDrinking,
        ),
        YesNoField(
          label: 'Partying allowed',
          value: draft.partyingAllowed,
          yesKey: 'listing-partying-yes',
          noKey: 'listing-partying-no',
          onChanged: onPartying,
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Suitable for')),
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
        Text(homiziText(context, 'Open for')),
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
        Text(homiziText(context, 'Preferred occupation')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('working_professional', 'Working professional'),
              ('student', 'Student'),
              ('actor', 'Actor / actress'),
              ('others', 'Others'),
            ])
              FilterChip(
                key: Key('listing-occupation-${item.$1}'),
                label: Text(homiziText(context, item.$2)),
                selected: draft.preferredOccupation == item.$1,
                onSelected: (_) => onOccupation(item.$1),
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
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController flatmates;
  final TextEditingController possession;
  final TextEditingController highlights;
  final ValueChanged<bool> onCook;
  final ValueChanged<bool> onMaid;
  final ValueChanged<bool> onConsent;

  @override
  Widget build(BuildContext context) {
    final shared = showsFlatmates(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YesNoField(
          label: 'Cook service',
          value: draft.cookService,
          yesKey: 'listing-cook-yes',
          noKey: 'listing-cook-no',
          onChanged: onCook,
        ),
        YesNoField(
          label: 'Maid service',
          value: draft.maidService,
          yesKey: 'listing-maid-yes',
          noKey: 'listing-maid-no',
          onChanged: onMaid,
        ),
        if (shared) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('listing-flatmates'),
            controller: flatmates,
            maxLength: 240,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Existing flatmates (brief)'),
              hintText: homiziText(
                context,
                '2 working professionals, 1 male and 1 female, IT sector',
              ),
            ),
          ),
          SwitchListTile(
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
        ],
        const SizedBox(height: 8),
        TextField(
          key: const Key('listing-possession'),
          controller: possession,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Possession date'),
            hintText: homiziText(context, '2026-12-01'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-highlights'),
          controller: highlights,
          maxLength: 280,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Other highlights'),
            hintText: homiziText(
              context,
              'Well-lit, close to the metro, good natural light',
            ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _money(
          context,
          key: 'listing-rent',
          controller: rent,
          label: 'Monthly rent (₹)',
        ),
        _money(
          context,
          key: 'listing-deposit',
          controller: deposit,
          label: 'Security deposit (₹)',
        ),
        _money(
          context,
          key: 'listing-charges',
          controller: brokerage,
          label: 'Brokerage (₹)',
        ),
        _money(
          context,
          key: 'listing-onetime',
          controller: oneTime,
          label: 'One-time charges (₹)',
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Recurring monthly charges')),
        const SizedBox(height: 8),
        _money(
          context,
          key: 'listing-maintenance',
          controller: maintenance,
          label: 'Maintenance (₹)',
        ),
        _money(
          context,
          key: 'listing-electricity',
          controller: electricity,
          label: 'Electricity (₹)',
        ),
        _money(
          context,
          key: 'listing-water-charge',
          controller: water,
          label: 'Water (₹)',
        ),
        _money(
          context,
          key: 'listing-wifi-charge',
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
            decoration: InputDecoration(
              labelText: homiziText(context, 'Brokerage terms'),
              hintText: homiziText(
                context,
                'One month rent, paid when the agreement is signed',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        RentCostBreakdown(cost: RentingCost.fromDraft(draft), detailed: true),
      ],
    );
  }

  Widget _money(
    BuildContext context, {
    required String key,
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [WholeAmountFormatter()],
        decoration: InputDecoration(labelText: homiziText(context, label)),
      ),
    );
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
    return Column(
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
            label: photoSequence[index],
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

class WizardChoice extends StatelessWidget {
  const WizardChoice({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A141414),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: selected ? HomiziColors.accentWash : HomiziColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? HomiziColors.accent : HomiziColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, title),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          homiziText(context, subtitle!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: HomiziColors.muted),
                        ),
                    ],
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

class YesNoField extends StatelessWidget {
  const YesNoField({
    required this.label,
    required this.value,
    required this.yesKey,
    required this.noKey,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool? value;
  final String yesKey;
  final String noKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(homiziText(context, label))),
          FilterChip(
            key: Key(yesKey),
            label: Text(homiziText(context, 'Yes')),
            selected: value == true,
            onSelected: (_) => onChanged(true),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: Key(noKey),
            label: Text(homiziText(context, 'No')),
            selected: value == false,
            onSelected: (_) => onChanged(false),
          ),
        ],
      ),
    );
  }
}
