import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker_flow/broker_listing_extras.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';

const brokerIntentChoices = <(String, String, String, IconData)>[
  (
    'room',
    'A Room / Shared Room',
    'Single room or double sharing',
    Icons.bed_outlined,
  ),
  (
    'whole_flat',
    'A Whole Flat / Apartment',
    '1BHK, 2BHK, and larger',
    Icons.apartment_outlined,
  ),
  (
    'pg',
    'A Paying Guest (PG)',
    'PG or hostel property',
    Icons.night_shelter_outlined,
  ),
  (
    'shared_space',
    'Shared Space (I am an existing tenant)',
    'Looking for a flatmate or roomie',
    Icons.groups_outlined,
  ),
];

class BrokerListingIntro extends StatelessWidget {
  const BrokerListingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                children: [
                  _Benefit(
                    icon: Icons.verified_user_outlined,
                    title: 'Build Trust',
                    detail: 'Verified listings get more enquiries.',
                  ),
                  _Benefit(
                    icon: Icons.groups_outlined,
                    title: 'Find the Right Tenants',
                    detail: 'Well-detailed listings get matched quickly.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/real/apartment.webp',
                width: 120,
                height: 168,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 168,
                  color: HomiziColors.mist,
                ),
              ),
            ),
          ],
        ),
        const _Benefit(
          icon: Icons.bolt_outlined,
          title: 'Faster Renting',
          detail: 'Clear details help you rent faster.',
        ),
        const _Benefit(
          icon: Icons.shield_outlined,
          title: 'Safe & Transparent',
          detail: 'Everyone knows what to expect.',
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: HomiziColors.accent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List with Confidence',
                      style: TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Rent Faster',
                      style: TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.home_outlined, color: HomiziColors.ink, size: 36),
            ],
          ),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HomiziColors.success, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  homiziText(context, detail),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrokerIntentPage extends StatelessWidget {
  const BrokerIntentPage({
    required this.intent,
    required this.onIntent,
    super.key,
  });

  final String intent;
  final ValueChanged<String> onIntent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'I want to list'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final option in brokerIntentChoices) ...[
          _ChoiceTile(
            tileKey: Key('broker-intent-${option.$1}'),
            icon: option.$4,
            title: option.$2,
            subtitle: option.$3,
            selected: intent == option.$1,
            onTap: () => onIntent(option.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class BrokerLocationPage extends StatelessWidget {
  const BrokerLocationPage({
    required this.draft,
    required this.locality,
    required this.building,
    required this.area,
    required this.floor,
    required this.totalFloors,
    required this.onCity,
    required this.onKind,
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
  final ValueChanged<String> onCity;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onConfiguration;
  final ValueChanged<String> onRentable;

  @override
  Widget build(BuildContext context) {
    final showFloors = floorApplies(draft.buildingKind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapSketch(
          locality: locality.text.trim().isEmpty
              ? draft.locality
              : locality.text,
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(context, 'City'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _chips(
          context,
          options: [for (final city in exploreCities) (city, city)],
          selected: draft.city,
          onTap: onCity,
          prefix: 'broker-city-pick',
        ),
        const SizedBox(height: 12),
        _money(
          context,
          keyName: 'broker-locality',
          controller: locality,
          label: 'Locality / Neighbourhood',
          icon: Icons.place_outlined,
          number: false,
        ),
        _money(
          context,
          keyName: 'broker-building',
          controller: building,
          label: 'Tower / Building Name',
          icon: Icons.apartment,
          number: false,
        ),
        Text(
          homiziText(context, 'Property Type'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _chips(
          context,
          options: buildingKindOptions,
          selected: draft.buildingKind,
          onTap: onKind,
          prefix: 'broker-kind',
        ),
        if (showFloors) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _money(
                  context,
                  keyName: 'broker-floor',
                  controller: floor,
                  label: 'Floor Number',
                  icon: Icons.stairs_outlined,
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _money(
                  context,
                  keyName: 'broker-total-floors',
                  controller: totalFloors,
                  label: 'Total floors',
                  icon: Icons.layers_outlined,
                  number: true,
                ),
              ),
            ],
          ),
        ],
        Text(
          homiziText(context, 'Property Configuration'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _chips(
          context,
          options: configurationOptions,
          selected: draft.configuration,
          onTap: onConfiguration,
          prefix: 'broker-config',
        ),
        const SizedBox(height: 12),
        _money(
          context,
          keyName: 'broker-area',
          controller: area,
          label: 'Total Area of Property (sq ft)',
          icon: Icons.square_foot,
          number: true,
        ),
        Text(
          homiziText(context, 'Area Available for Rent'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _chips(
          context,
          options: rentableAreaOptions,
          selected: draft.rentableArea,
          onTap: onRentable,
          prefix: 'broker-rentable',
        ),
      ],
    );
  }
}

class BrokerNearbyPage extends StatelessWidget {
  const BrokerNearbyPage({
    required this.places,
    required this.onMinutes,
    super.key,
  });

  final List<NearbyPlace> places;
  final void Function(int index, int minutes) onMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < places.length; index++)
          _NearbyTile(
            place: places[index],
            color: _nearbyInk(index),
            onMinutes: (minutes) => onMinutes(index, minutes),
          ),
      ],
    );
  }
}

class BrokerLivingPage extends StatelessWidget {
  const BrokerLivingPage({
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
        _label(context, 'Furnishing'),
        _chips(
          context,
          options: const [
            ('furnished', 'Furnished'),
            ('semi_furnished', 'Semi Furnished'),
            ('unfurnished', 'Unfurnished'),
          ],
          selected: draft.furnishing,
          onTap: onFurnishing,
          prefix: 'broker-furnishing',
        ),
        const SizedBox(height: 12),
        _label(context, 'Parking'),
        _chips(
          context,
          options: const [
            ('car', 'Car'),
            ('bike', 'Bike'),
            ('none', 'No parking'),
          ],
          selected: draft.parkingKind,
          onTap: onParking,
          prefix: 'broker-parking',
        ),
        const SizedBox(height: 12),
        _money(
          context,
          keyName: 'broker-age',
          controller: age,
          label: 'Age of property (years)',
          icon: Icons.calendar_today_outlined,
          number: true,
        ),
        _label(context, 'WC / Bathroom Type'),
        _chips(
          context,
          options: const [('separate', 'Separate'), ('shared', 'Shared')],
          selected: draft.wcType,
          onTap: onWc,
          prefix: 'broker-wc',
        ),
        const SizedBox(height: 12),
        _label(context, 'Water supply'),
        _chips(
          context,
          options: const [('municipal', 'Municipal'), ('tanker', 'Tanker')],
          selected: draft.waterSupply,
          onTap: onWater,
          prefix: 'broker-water',
        ),
        const SizedBox(height: 12),
        _money(
          context,
          keyName: 'broker-water-hours',
          controller: waterHours,
          label: 'Water supply hours',
          icon: Icons.water_drop_outlined,
          number: false,
        ),
        _label(context, 'In-flat amenities'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in inFlatAmenityKeys)
              FilterChip(
                key: Key('broker-amenity-$key'),
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

class BrokerRulesPage extends StatelessWidget {
  const BrokerRulesPage({
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
        _yesNo(
          context,
          'Pets allowed?',
          draft.petsChoice,
          'broker-pets',
          onPets,
        ),
        _yesNo(
          context,
          'Guests allowed?',
          draft.guestsAllowed,
          'broker-guests',
          onGuests,
        ),
        _yesNo(
          context,
          'Non-veg allowed?',
          draft.nonVegChoice,
          'broker-nonveg',
          onNonVeg,
        ),
        _yesNo(
          context,
          'Drinking allowed?',
          draft.drinkingAllowed,
          'broker-drinking',
          onDrinking,
        ),
        _yesNo(
          context,
          'Partying allowed?',
          draft.partyingAllowed,
          'broker-partying',
          onPartying,
        ),
        const SizedBox(height: 8),
        _label(context, 'Suitable for'),
        _chips(
          context,
          options: const [
            ('bachelors', 'Bachelors'),
            ('couple', 'Couple'),
            ('married', 'Married'),
          ],
          selected: draft.suitableFor.isEmpty ? '' : draft.suitableFor.first,
          onTap: onSuitable,
          prefix: 'broker-suitable',
        ),
        const SizedBox(height: 12),
        _label(context, 'Open for'),
        _chips(
          context,
          options: const [
            ('male', 'Male'),
            ('female', 'Female'),
            ('any', 'Any'),
          ],
          selected: draft.genderPreference,
          onTap: onGender,
          prefix: 'broker-gender',
        ),
        const SizedBox(height: 12),
        _label(context, 'Preferred occupation'),
        _chips(
          context,
          options: const [
            ('working_professional', 'Working Professional'),
            ('student', 'Student'),
            ('actor', 'Actor / Actress'),
            ('others', 'Others'),
          ],
          selected: draft.preferredOccupation,
          onTap: onOccupation,
          prefix: 'broker-occupation',
        ),
      ],
    );
  }
}

class BrokerServicesPage extends StatelessWidget {
  const BrokerServicesPage({
    required this.draft,
    required this.flatmates,
    required this.possession,
    required this.highlights,
    required this.onCook,
    required this.onMaid,
    super.key,
  });

  final ListingDraft draft;
  final TextEditingController flatmates;
  final TextEditingController possession;
  final TextEditingController highlights;
  final ValueChanged<bool> onCook;
  final ValueChanged<bool> onMaid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _yesNo(
          context,
          'Cook service available?',
          draft.cookService,
          'broker-cook',
          onCook,
          yes: 'Available',
          no: 'Not available',
        ),
        _yesNo(
          context,
          'Maid service available?',
          draft.maidService,
          'broker-maid',
          onMaid,
          yes: 'Available',
          no: 'Not available',
        ),
        if (showsFlatmates(draft))
          _money(
            context,
            keyName: 'broker-flatmates',
            controller: flatmates,
            label: 'Existing flatmates',
            icon: Icons.people_outline,
            number: false,
          ),
        _money(
          context,
          keyName: 'broker-possession',
          controller: possession,
          label: 'Possession date',
          icon: Icons.event_outlined,
          number: false,
        ),
        _money(
          context,
          keyName: 'broker-highlights',
          controller: highlights,
          label: 'Other highlights',
          icon: Icons.wb_sunny_outlined,
          number: false,
        ),
      ],
    );
  }
}

class BrokerRentPage extends StatelessWidget {
  const BrokerRentPage({
    required this.rent,
    required this.deposit,
    required this.brokerage,
    required this.oneTime,
    required this.maintenance,
    required this.electricity,
    required this.water,
    required this.wifi,
    required this.other,
    super.key,
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _money(
          context,
          keyName: 'broker-rent',
          controller: rent,
          label: 'Monthly rent (₹)',
          icon: Icons.payments_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-deposit',
          controller: deposit,
          label: 'Security deposit (₹)',
          icon: Icons.account_balance_wallet_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-brokerage',
          controller: brokerage,
          label: 'Brokerage fee (₹)',
          icon: Icons.badge_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-onetime',
          controller: oneTime,
          label: 'Other one-time charges (₹)',
          icon: Icons.receipt_long_outlined,
          number: true,
        ),
        const SizedBox(height: 4),
        _label(context, 'Recurring monthly charges'),
        const SizedBox(height: 8),
        _money(
          context,
          keyName: 'broker-maintenance',
          controller: maintenance,
          label: 'Maintenance (₹)',
          icon: Icons.handyman_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-electricity',
          controller: electricity,
          label: 'Electricity (₹)',
          icon: Icons.bolt_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-water-charge',
          controller: water,
          label: 'Water (₹)',
          icon: Icons.water_drop_outlined,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-wifi-charge',
          controller: wifi,
          label: 'Wi-Fi (₹)',
          icon: Icons.wifi,
          number: true,
        ),
        _money(
          context,
          keyName: 'broker-other-monthly',
          controller: other,
          label: 'Other monthly (₹)',
          icon: Icons.more_horiz,
          number: true,
        ),
        const SizedBox(height: 8),
        const BrokerOwnerAuthorisation(),
      ],
    );
  }
}

class BrokerPhotosPage extends StatelessWidget {
  const BrokerPhotosPage({
    required this.draft,
    required this.onSamples,
    super.key,
  });

  final ListingDraft draft;
  final VoidCallback onSamples;

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
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            for (var index = 0; index < photoSequence.length; index++)
              _PhotoTile(
                index: index + 1,
                label: photoSequence[index],
                done: labels.contains(photoSequence[index]),
                asset: _assetFor(draft, photoSequence[index]),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _label(context, 'Photo tips'),
        for (final tip in const [
          'Show the exact space from door to opposite wall.',
          'Use bright and clear photos.',
          'No blurry or dark photos.',
          'Follow the exact sequence.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 16, color: HomiziColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    homiziText(context, tip),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('broker-photo-samples'),
          onPressed: onSamples,
          child: Text(homiziText(context, 'Use sample photos')),
        ),
      ],
    );
  }

  String? _assetFor(ListingDraft draft, String label) {
    for (final photo in draft.photos) {
      if (photo.label == label) {
        return assetForPhoto(photo);
      }
    }
    return null;
  }
}

class BrokerReviewPage extends StatelessWidget {
  const BrokerReviewPage({
    required this.draft,
    required this.ownerAuthorised,
    required this.authorisationName,
    super.key,
  });

  final ListingDraft draft;
  final bool ownerAuthorised;
  final String authorisationName;

  @override
  Widget build(BuildContext context) {
    final rent = draft.rentInr ?? 0;
    final photo = draft.photos.isEmpty
        ? null
        : assetForPhoto(draft.photos.first);
    final config = _configLabel(draft.configuration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          key: const Key('broker-review-card'),
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomiziColors.white,
              border: Border.all(color: HomiziColors.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: photo == null
                          ? const ColoredBox(color: HomiziColors.mist)
                          : Image.asset(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(color: HomiziColors.mist),
                            ),
                    ),
                    const Positioned(
                      left: 12,
                      top: 12,
                      child: ListedByBrokerBadge(),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, '${formatInr(rent)} / month'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(
                          context,
                          draft.title.trim().isEmpty
                              ? 'Untitled home'
                              : draft.title.trim(),
                        ),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          [
                            if (config.isNotEmpty) config,
                            if (draft.locality.trim().isNotEmpty)
                              draft.locality.trim(),
                            if (draft.city.trim().isNotEmpty) draft.city.trim(),
                          ].join(' · '),
                        ),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homiziText(
                          context,
                          'Brokerage fee ${formatInr(draft.brokerageInr ?? 0)}',
                        ),
                        style: const TextStyle(color: HomiziColors.ink),
                      ),
                      Text(
                        homiziText(
                          context,
                          ownerAuthorised
                              ? 'Owner authorisation attached${authorisationName.isEmpty ? '' : ' · $authorisationName'}'
                              : 'Owner authorisation not attached yet',
                        ),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BrokerPublishedPage extends StatelessWidget {
  const BrokerPublishedPage({
    required this.draft,
    required this.serverPublished,
    super.key,
  });

  final ListingDraft draft;
  final bool serverPublished;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('broker-published-confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 48),
        const SizedBox(height: 12),
        const ListedByBrokerBadge(),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            serverPublished
                ? 'Your listing is live and appears in search.'
                : 'This home is saved on this device. The server did not publish it.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            draft.title.trim().isEmpty ? 'Untitled home' : draft.title.trim(),
          ),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        Text(
          homiziText(context, '${formatInr(draft.rentInr ?? 0)} / month'),
          style: const TextStyle(color: HomiziColors.ink),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.accentWash : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? HomiziColors.accent : HomiziColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: HomiziColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      homiziText(context, subtitle),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? HomiziColors.accent : HomiziColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSketch extends StatelessWidget {
  const _MapSketch({required this.locality});

  final String locality;

  @override
  Widget build(BuildContext context) {
    final label = locality.trim().isEmpty ? 'Locality' : locality.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _RoadPainter()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: HomiziColors.brandDeepRed,
                    size: 36,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: HomiziColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      homiziText(context, label),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = HomiziColors.mist);
    final road = Paint()
      ..color = HomiziColors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.55, size.height),
      road,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.62, size.height * 0.12, 48, 36),
      Paint()..color = HomiziColors.successWash,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NearbyTile extends StatefulWidget {
  const _NearbyTile({
    required this.place,
    required this.color,
    required this.onMinutes,
  });

  final NearbyPlace place;
  final Color color;
  final ValueChanged<int> onMinutes;

  @override
  State<_NearbyTile> createState() => _NearbyTileState();
}

class _NearbyTileState extends State<_NearbyTile> {
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = TextEditingController(
      text: widget.place.minutes == null ? '' : '${widget.place.minutes}',
    );
  }

  @override
  void didUpdateWidget(covariant _NearbyTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.minutes != widget.place.minutes &&
        _minutes.text != '${widget.place.minutes}') {
      _minutes.text = widget.place.minutes == null
          ? ''
          : '${widget.place.minutes}';
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final km = widget.place.hasDistance
        ? widget.place.km!.toStringAsFixed(1)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(_nearbyIcon(widget.place.kind), color: widget.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, widget.place.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  homiziText(
                    context,
                    km == null ? 'Distance unavailable' : '$km km',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              key: Key('broker-nearby-${widget.place.kind}'),
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: const [WholeAmountFormatter()],
              decoration: InputDecoration(
                isDense: true,
                labelText: homiziText(context, 'min'),
              ),
              onChanged: (value) => widget.onMinutes(int.tryParse(value) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.label,
    required this.done,
    required this.asset,
  });

  final int index;
  final String label;
  final bool done;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (asset == null)
            const ColoredBox(color: HomiziColors.mist)
          else
            Image.asset(
              asset!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: HomiziColors.mist),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  homiziText(context, '$index. $label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (done)
            const Positioned(
              right: 6,
              top: 6,
              child: Icon(
                Icons.check_circle,
                color: HomiziColors.success,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

Widget _label(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      homiziText(context, text),
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _chips(
  BuildContext context, {
  required List<(String, String)> options,
  required String selected,
  required ValueChanged<String> onTap,
  required String prefix,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        ChoiceChip(
          key: Key('$prefix-${option.$1}'),
          label: Text(homiziText(context, option.$2)),
          selected: selected == option.$1,
          onSelected: (_) => onTap(option.$1),
        ),
    ],
  );
}

Widget _money(
  BuildContext context, {
  required String keyName,
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required bool number,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key(keyName),
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? const [WholeAmountFormatter()] : null,
      decoration: InputDecoration(
        labelText: homiziText(context, label),
        prefixIcon: Icon(icon, color: HomiziColors.ink),
      ),
    ),
  );
}

Widget _yesNo(
  BuildContext context,
  String label,
  bool? value,
  String prefix,
  ValueChanged<bool> onChanged, {
  String yes = 'Yes',
  String no = 'No',
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, label),
          style: const TextStyle(color: HomiziColors.ink),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              key: Key('$prefix-yes'),
              label: Text(homiziText(context, yes)),
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              key: Key('$prefix-no'),
              label: Text(homiziText(context, no)),
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    ),
  );
}

IconData _nearbyIcon(String kind) {
  return switch (kind) {
    'metro' => Icons.subway_outlined,
    'train' => Icons.train_outlined,
    'bus' => Icons.directions_bus_outlined,
    'airport' => Icons.flight_outlined,
    'hospital' => Icons.local_hospital_outlined,
    'supermarket' => Icons.local_grocery_store_outlined,
    'mall' => Icons.shopping_bag_outlined,
    'movie' => Icons.movie_outlined,
    'gym' => Icons.fitness_center,
    _ => Icons.place_outlined,
  };
}

Color _nearbyInk(int index) {
  const colors = <Color>[
    HomiziColors.brandDeepRed,
    HomiziColors.ink,
    HomiziColors.brandDarkRed,
    HomiziColors.brandVermilion,
    HomiziColors.brandRedOrange,
    HomiziColors.accent,
    HomiziColors.brandDeepOrange,
    HomiziColors.ink,
    HomiziColors.brandDarkRed,
  ];
  return colors[index % colors.length];
}

String _configLabel(String configuration) {
  for (final option in configurationOptions) {
    if (option.$1 == configuration) {
      return option.$2;
    }
  }
  return configuration;
}
