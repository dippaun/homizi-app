import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker/broker_profile.dart';
import 'package:homizi/features/broker/broker_providers.dart';
import 'package:homizi/features/broker_flow/broker_flow_chrome.dart';
import 'package:homizi/features/broker_flow/broker_listing_extras.dart';
import 'package:homizi/features/broker_flow/broker_listing_pages.dart';
import 'package:homizi/features/broker_flow/broker_onboarding_pages.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

enum BrokerFlowPage {
  profile,
  verify,
  badge,
  onboardDone,
  intro,
  intent,
  location,
  nearby,
  living,
  rules,
  services,
  rent,
  photos,
  review,
  published,
  desk,
  done,
}

/// Broker onboarding, the 8-step listing, and the broker desk.
class BrokerFlowScreen extends ConsumerStatefulWidget {
  const BrokerFlowScreen({super.key});

  @override
  ConsumerState<BrokerFlowScreen> createState() => _BrokerFlowScreenState();
}

class _BrokerFlowScreenState extends ConsumerState<BrokerFlowScreen> {
  final _name = TextEditingController(text: 'Meenal Deshpande');
  final _agency = TextEditingController(text: 'Deshpande Realty');
  final _rera = TextEditingController(
    text: 'PRM/KA/RERA/1251/446/AG/171018/000441',
  );
  final _phone = TextEditingController(text: '9876543210');
  final _email = TextEditingController(
    text: 'meenal.deshpande@deshpanderealty.in',
  );
  final _profileLocality = TextEditingController();
  final _mobileOtp = TextEditingController();
  final _emailOtp = TextEditingController();
  final _locality = TextEditingController(text: 'Bandra West');
  final _building = TextEditingController(text: 'Sea View Residency');
  final _area = TextEditingController(text: '950');
  final _floor = TextEditingController(text: '4');
  final _totalFloors = TextEditingController(text: '12');
  final _age = TextEditingController(text: '5');
  final _waterHours = TextEditingController(text: '24/7');
  final _flatmates = TextEditingController(
    text: 'One working flatmate, male, in Bandra.',
  );
  final _possession = TextEditingController(text: '1 December 2026');
  final _highlights = TextEditingController(
    text: 'Well-lit room, close to the station, good natural light.',
  );
  final _rent = TextEditingController(text: '25000');
  final _deposit = TextEditingController(text: '75000');
  final _brokerage = TextEditingController(text: '25000');
  final _oneTime = TextEditingController(text: '5000');
  final _maintenance = TextEditingController(text: '1500');
  final _electricity = TextEditingController();
  final _water = TextEditingController(text: '500');
  final _wifi = TextEditingController();
  final _other = TextEditingController();

  var _index = 0;
  var _years = 8;
  var _cities = <String>{'Mumbai'};
  var _localities = <String>['Bandra West'];
  var _mobileSent = false;
  var _emailSent = false;
  var _mobileVerified = false;
  var _emailVerified = false;
  var _digioBusy = false;
  var _busy = false;
  var _draftSaved = false;
  var _previewing = false;
  var _serverPublished = false;
  var _deskLoading = false;
  var _kyc = KycSnapshot.notStarted;
  String? _error;
  String? _deskError;
  String? _basis;
  List<OwnerListing> _listings = const [];
  List<SeekerMatch> _seekers = const [];
  late ListingDraft _draft = _seedDraft();

  BrokerFlowPage get _page => BrokerFlowPage.values[_index];

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final loaded = await ref.read(brokerGatewayProvider).load();
      if (loaded != null && mounted) {
        setState(() => _applyLoaded(loaded));
      }
    } on Object {
      // A missing profile still uses the fields on this screen.
    }
    try {
      final snapshot = await ref.read(kycGatewayProvider).current();
      if (mounted) {
        setState(() => _kyc = snapshot);
      }
    } on Object {
      // Aadhaar stays unverified when Digio cannot be read.
    }
  }

  void _applyLoaded(BrokerProfileDraft loaded) {
    if (loaded.fullName.trim().isNotEmpty) {
      _name.text = loaded.fullName;
    }
    if (loaded.agencyName.trim().isNotEmpty) {
      _agency.text = loaded.agencyName;
    }
    if (loaded.reraNumber.trim().isNotEmpty) {
      _rera.text = loaded.reraNumber;
    }
    if (loaded.phone.trim().isNotEmpty) {
      _phone.text = loaded.phone;
    }
    if (loaded.cities.isNotEmpty) {
      _cities = {...loaded.cities};
    }
    if (loaded.localities.isNotEmpty) {
      _localities = [...loaded.localities];
    }
    _years = loaded.yearsExperience;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _agency,
      _rera,
      _phone,
      _email,
      _profileLocality,
      _mobileOtp,
      _emailOtp,
      _locality,
      _building,
      _area,
      _floor,
      _totalFloors,
      _age,
      _waterHours,
      _flatmates,
      _possession,
      _highlights,
      _rent,
      _deposit,
      _brokerage,
      _oneTime,
      _maintenance,
      _electricity,
      _water,
      _wifi,
      _other,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (_index == 0) {
      HomiziBackButton.leave(context);
      return;
    }
    setState(() {
      _index -= 1;
      _error = null;
    });
  }

  Future<void> _continue() async {
    if (_busy) {
      return;
    }
    final issue = await _gate();
    if (!mounted) {
      return;
    }
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    if (_page == BrokerFlowPage.done) {
      HomiziBackButton.leave(context);
      return;
    }
    setState(() {
      _error = null;
      _index += 1;
    });
    if (_page == BrokerFlowPage.desk) {
      unawaited(_loadDesk());
    }
  }

  Future<String?> _gate() async {
    if (_page.index >= BrokerFlowPage.intent.index &&
        _page.index <= BrokerFlowPage.photos.index) {
      _draft = _synced();
    }
    return switch (_page) {
      BrokerFlowPage.profile => _saveProfile(),
      BrokerFlowPage.verify => _verifyGate(),
      BrokerFlowPage.intent =>
        _draft.listingIntent.isEmpty ? 'Choose what you want to list.' : null,
      BrokerFlowPage.location => _locationIssue(),
      BrokerFlowPage.nearby => _nearbyIssue(),
      BrokerFlowPage.living => _livingIssue(),
      BrokerFlowPage.rules => _rulesIssue(),
      BrokerFlowPage.services => _servicesIssue(),
      BrokerFlowPage.rent => _rentIssue(),
      BrokerFlowPage.photos => _photoIssue(),
      _ => null,
    };
  }

  Future<String?> _saveProfile() async {
    final pending = _profileLocality.text.trim();
    if (pending.isNotEmpty && !_localities.contains(pending)) {
      _localities.add(pending);
      _profileLocality.clear();
    }
    final draft = brokerProfileDraft(
      name: _name.text,
      agency: _agency.text,
      rera: _rera.text,
      phone: _phone.text,
      cities: _cities,
      localities: _localities,
      pendingLocality: _profileLocality.text,
      years: _years,
    );
    final issue = brokerProfileIssue(draft: draft, email: _email.text);
    if (issue != null) {
      return issue;
    }
    try {
      await ref.read(brokerGatewayProvider).save(draft);
    } on BrokerFailure catch (error) {
      return error.message;
    }
    try {
      await ref.read(sessionProvider.notifier).selectPrimaryRole('broker');
    } on Object {
      // The profile is saved even when the role write is offline.
    }
    return null;
  }

  String? _verifyGate() {
    if (!ref.read(appConfigProvider).allowsDevOtp) {
      return null;
    }
    if (!_mobileVerified) {
      return 'Verify your mobile number.';
    }
    if (!_emailVerified) {
      return 'Verify your email address.';
    }
    return null;
  }

  String? _locationIssue() {
    if (_draft.city.trim().isEmpty) {
      return 'Choose a city.';
    }
    if (_draft.locality.trim().isEmpty) {
      return 'Add a locality.';
    }
    if (_draft.buildingName.trim().isEmpty) {
      return 'Add the tower or building name.';
    }
    if (_draft.buildingKind.isEmpty) {
      return 'Choose a property type.';
    }
    if (_draft.configuration.isEmpty) {
      return 'Choose a configuration.';
    }
    if (_draft.areaSqft == null) {
      return 'Enter the total area in sq ft.';
    }
    if (_draft.rentableArea.isEmpty) {
      return 'Choose the area available for rent.';
    }
    if (floorApplies(_draft.buildingKind) &&
        (_draft.floorNo == null || _draft.totalFloors == null)) {
      return 'Enter the floor number and the total floors.';
    }
    return null;
  }

  String? _nearbyIssue() {
    if (_draft.nearby.length < nearbyKinds.length ||
        _draft.nearby.any((place) => place.name.trim().isEmpty)) {
      return 'Add a name for each nearby place. Leave distance blank if maps cannot measure it.';
    }
    return null;
  }

  String? _livingIssue() {
    if (_draft.parkingKind.isEmpty) {
      return 'Choose parking for a car, a bike, or none.';
    }
    if (_draft.propertyAgeText.trim().isEmpty) {
      return 'Enter the age of the property.';
    }
    if (_draft.wcType.isEmpty) {
      return 'Choose a separate or shared WC.';
    }
    if (_draft.waterSupply.isEmpty || _draft.waterHours.trim().isEmpty) {
      return 'Choose the water supply and the hours.';
    }
    return null;
  }

  String? _rulesIssue() {
    if (_draft.petsChoice == null ||
        _draft.guestsAllowed == null ||
        _draft.nonVegChoice == null ||
        _draft.drinkingAllowed == null ||
        _draft.partyingAllowed == null) {
      return 'Answer every house rule.';
    }
    if (_draft.suitableFor.isEmpty) {
      return 'Choose who the home suits.';
    }
    if (_draft.genderPreference.isEmpty) {
      return 'Choose who the home is open for.';
    }
    if (_draft.preferredOccupation.isEmpty) {
      return 'Choose a preferred occupation.';
    }
    return null;
  }

  String? _servicesIssue() {
    if (_draft.cookService == null) {
      return 'Say whether cook service is available.';
    }
    if (_draft.maidService == null) {
      return 'Say whether maid service is available.';
    }
    if (_draft.possessionDate.trim().isEmpty) {
      return 'Add a possession date.';
    }
    return null;
  }

  String? _rentIssue() {
    final rent = _draft.rentInr;
    if (rent == null || rent <= 0) {
      return 'Enter a monthly rent in rupees.';
    }
    final blockers = _draft.persistBlockers();
    for (final issue in blockers) {
      if (issue.contains('rent') ||
          issue.contains('deposit') ||
          issue.contains('maintenance') ||
          issue.contains('charges') ||
          issue.contains('Brokerage') ||
          issue.contains('other')) {
        return issue;
      }
    }
    return null;
  }

  String? _photoIssue() {
    if (_draft.photos.length < 3) {
      return 'Add at least 3 photos.';
    }
    final gaps = photoSequenceGaps(_draft.photos);
    return gaps.isEmpty ? null : gaps.first;
  }

  void _sendMobile() {
    final issue = validateIndianMobile(_phone.text);
    setState(() {
      _error = issue;
      if (issue == null) {
        _mobileSent = true;
      }
    });
  }

  void _sendEmail() {
    final issue = validateEmailAddress(_email.text);
    setState(() {
      _error = issue;
      if (issue == null) {
        _emailSent = true;
      }
    });
  }

  void _checkMobile() {
    if (!ref.read(appConfigProvider).allowsDevOtp) {
      setState(
        () => _error =
            'Mobile verification stays with the server. This screen does not mark it done.',
      );
      return;
    }
    final ok = profileOtpMatches(_mobileOtp.text);
    setState(() {
      _mobileVerified = ok;
      _error = ok ? null : 'That code does not match. The demo code is 000000.';
    });
  }

  void _checkEmail() {
    if (!ref.read(appConfigProvider).allowsDevOtp) {
      setState(
        () => _error =
            'Email verification stays with the server. This screen does not mark it done.',
      );
      return;
    }
    final ok = profileOtpMatches(_emailOtp.text);
    setState(() {
      _emailVerified = ok;
      _error = ok ? null : 'That code does not match. The demo code is 000000.';
    });
  }

  Future<void> _openDigio() async {
    setState(() {
      _digioBusy = true;
      _error = null;
    });
    try {
      final gateway = ref.read(kycGatewayProvider);
      if (_kyc.status == 'not_started') {
        await gateway.giveConsent(KycDocumentKind.digilocker);
      }
      final next = await gateway.start(KycDocumentKind.digilocker);
      if (!mounted) {
        return;
      }
      setState(() {
        _kyc = next;
        _digioBusy = false;
      });
      final url = next.gatewayUrl;
      if (url == null) {
        return;
      }
      final uri = kycGatewayUri(url, returnUrl: kycReturnUrl());
      if (uri != null) {
        await ref.read(kycLauncherProvider).open(uri);
      }
    } on KycFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _digioBusy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _saveDraft() async {
    final draft = _synced();
    setState(() {
      _draft = draft;
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .saveListing(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _draft = result.draft;
        _busy = false;
        _draftSaved = true;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _publish() async {
    final draft = _synced();
    final gaps = releaseGaps(draft);
    if (gaps.isNotEmpty) {
      setState(() {
        _draft = draft;
        _error = gaps.first;
      });
      return;
    }
    setState(() {
      _draft = draft;
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .publishListing(draft);
      if (!mounted) {
        return;
      }
      ref.read(listingDraftProvider.notifier).update(result.draft);
      if (releaseGaps(result.draft).isEmpty) {
        ref.read(publishedSearchProvider.notifier).remember(result.draft);
      }
      setState(() {
        _draft = result.draft;
        _serverPublished = result.publishedByServer;
        _busy = false;
        _index = BrokerFlowPage.published.index;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _loadDesk() async {
    setState(() {
      _deskLoading = true;
      _deskError = null;
    });
    try {
      final listings = await ref.read(ownerGatewayProvider).myListings();
      final page = await ref.read(seekerMatchGatewayProvider).load();
      if (!mounted) {
        return;
      }
      final ranked = [...page.seekers]
        ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      setState(() {
        _listings = listings;
        _seekers = ranked;
        _basis = page.basis;
        _deskLoading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _deskLoading = false;
        _deskError = 'The desk could not be loaded.';
      });
    }
  }

  ListingDraft _synced() {
    final city = _draft.city.trim().isEmpty ? 'Mumbai' : _draft.city.trim();
    final locality = _locality.text.trim();
    var nearby = _draft.nearby;
    if (!_draft.nearbyEdited &&
        locality.isNotEmpty &&
        (nearby.isEmpty ||
            _draft.locality.trim() != locality ||
            _draft.city.trim() != city)) {
      nearby = nearbyPlacesFor(city: city, locality: locality);
    }
    final kind = _draft.buildingKind;
    final intent = _draft.listingIntent.isEmpty ? 'room' : _draft.listingIntent;
    return _draft.copyWith(
      listingIntent: intent,
      title: _titleFor(intent, locality, _draft.configuration),
      city: city,
      locality: locality,
      buildingName: _building.text.trim(),
      areaText: _area.text.trim(),
      floorText: floorApplies(kind) ? _floor.text.trim() : '',
      totalFloorsText: floorApplies(kind) ? _totalFloors.text.trim() : '',
      propertyAgeText: _age.text.trim(),
      waterHours: _waterHours.text.trim(),
      flatmatesBrief: showsFlatmates(_draft) ? _flatmates.text.trim() : '',
      possessionDate: _possession.text.trim(),
      highlights: _highlights.text.trim(),
      rentText: _rent.text.trim(),
      depositText: _deposit.text.trim(),
      brokerageText: _brokerage.text.trim(),
      brokerageTerms: 'One month rent, paid when the agreement is signed',
      oneTimeChargesText: _oneTime.text.trim(),
      maintenanceText: _maintenance.text.trim(),
      electricityText: _electricity.text.trim(),
      waterChargeText: _water.text.trim(),
      wifiChargeText: _wifi.text.trim(),
      otherMonthlyText: _other.text.trim(),
      nearby: nearby,
      listedBy: 'broker',
      photos: _draft.photos.length >= 3 ? _draft.photos : wizardSamplePhotos,
      parking: _draft.parkingKind == 'car' || _draft.parkingKind == 'bike',
      petsAllowed: _draft.petsChoice ?? false,
      nonVegAllowed: _draft.nonVegChoice ?? false,
    );
  }

  void _set(ListingDraft next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final extras = ref.watch(brokerListingExtrasProvider);
    return BrokerFlowChrome(
      pageKey: Key('broker-flow-${_page.name}'),
      onBack: _back,
      step: _stepLabel(),
      headline: _headline(),
      headlineWidget: _page == BrokerFlowPage.intro
          ? _introTitle(context)
          : null,
      subtitle: _subtitle(),
      error: _error,
      footer: _footer(context),
      children: _body(extras),
    );
  }

  List<Widget> _body(BrokerListingExtras extras) {
    return switch (_page) {
      BrokerFlowPage.profile => [
        BrokerProfileFields(
          name: _name,
          agency: _agency,
          rera: _rera,
          phone: _phone,
          email: _email,
          locality: _profileLocality,
          cities: _cities,
          localities: _localities,
          years: _years,
          onCity: (city, selected) => setState(() {
            if (selected) {
              _cities.add(city);
            } else {
              _cities.remove(city);
            }
          }),
          onAddLocality: () {
            final next = _profileLocality.text.trim();
            if (next.isEmpty || _localities.contains(next)) {
              return;
            }
            setState(() {
              _localities.add(next);
              _profileLocality.clear();
            });
          },
          onRemoveLocality: (place) =>
              setState(() => _localities.remove(place)),
          onYears: (value) => setState(() => _years = value),
        ),
      ],
      BrokerFlowPage.verify => [
        BrokerVerifyFields(
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          mobileOtp: _mobileOtp,
          emailOtp: _emailOtp,
          mobileSent: _mobileSent,
          emailSent: _emailSent,
          mobileVerified: _mobileVerified,
          emailVerified: _emailVerified,
          demoCode: ref.watch(appConfigProvider).allowsDevOtp,
          kyc: _kyc,
          onSendMobile: _sendMobile,
          onSendEmail: _sendEmail,
          onVerifyMobile: _checkMobile,
          onVerifyEmail: _checkEmail,
          onDigio: () => unawaited(_openDigio()),
          digioBusy: _digioBusy,
        ),
      ],
      BrokerFlowPage.badge => [
        BrokerTrustBadgePage(
          agency: _agency.text.trim(),
          rera: _rera.text,
          years: _years,
          areas: [..._cities, ..._localities].join(', '),
          mobileVerified: _mobileVerified,
          emailVerified: _emailVerified,
          kyc: _kyc,
        ),
      ],
      BrokerFlowPage.onboardDone => [
        BrokerOnboardDone(
          agency: _agency.text.trim(),
          areas: [..._cities, ..._localities].join(', '),
          years: _years,
        ),
      ],
      BrokerFlowPage.intro => [const BrokerListingIntro()],
      BrokerFlowPage.intent => [
        BrokerIntentPage(
          intent: _draft.listingIntent,
          onIntent: (value) {
            final rentable = switch (value) {
              'whole_flat' => 'entire',
              'shared_space' => 'double',
              _ => 'single',
            };
            _set(
              _draft.copyWith(
                listingIntent: value,
                rentableArea: rentable,
                occupancy: rentable == 'double' ? 2 : 1,
              ),
            );
          },
        ),
      ],
      BrokerFlowPage.location => [
        BrokerLocationPage(
          draft: _draft,
          locality: _locality,
          building: _building,
          area: _area,
          floor: _floor,
          totalFloors: _totalFloors,
          onCity: (city) => _set(
            _draft.copyWith(
              city: city,
              nearby: _draft.nearbyEdited
                  ? _draft.nearby
                  : nearbyPlacesFor(city: city, locality: _locality.text),
            ),
          ),
          onKind: (kind) {
            if (!floorApplies(kind)) {
              _floor.clear();
              _totalFloors.clear();
            }
            _set(_draft.copyWith(buildingKind: kind));
          },
          onConfiguration: (value) =>
              _set(_draft.copyWith(configuration: value)),
          onRentable: (value) => _set(
            _draft.copyWith(
              rentableArea: value,
              occupancy: value == 'double' ? 2 : 1,
            ),
          ),
        ),
      ],
      BrokerFlowPage.nearby => [
        BrokerNearbyPage(places: _draft.nearby, onMinutes: _minutes),
      ],
      BrokerFlowPage.living => [
        BrokerLivingPage(
          draft: _draft,
          age: _age,
          waterHours: _waterHours,
          onFurnishing: (value) => _set(_draft.copyWith(furnishing: value)),
          onParking: (value) => _set(
            _draft.copyWith(
              parkingKind: value,
              parking: value == 'car' || value == 'bike',
            ),
          ),
          onWc: (value) => _set(_draft.copyWith(wcType: value)),
          onWater: (value) => _set(_draft.copyWith(waterSupply: value)),
          onAmenity: (key, selected) {
            final next = [
              for (final item in _draft.inFlatAmenities)
                if (item != key) item,
              if (selected) key,
            ];
            _set(_draft.copyWith(inFlatAmenities: next, amenities: next));
          },
        ),
      ],
      BrokerFlowPage.rules => [
        BrokerRulesPage(
          draft: _draft,
          onPets: (value) =>
              _set(_draft.copyWith(petsChoice: value, petsAllowed: value)),
          onGuests: (value) => _set(_draft.copyWith(guestsAllowed: value)),
          onNonVeg: (value) =>
              _set(_draft.copyWith(nonVegChoice: value, nonVegAllowed: value)),
          onDrinking: (value) => _set(_draft.copyWith(drinkingAllowed: value)),
          onPartying: (value) => _set(_draft.copyWith(partyingAllowed: value)),
          onSuitable: (value) => _set(_draft.copyWith(suitableFor: [value])),
          onGender: (value) => _set(_draft.copyWith(genderPreference: value)),
          onOccupation: (value) =>
              _set(_draft.copyWith(preferredOccupation: value)),
        ),
      ],
      BrokerFlowPage.services => [
        BrokerServicesPage(
          draft: _draft,
          flatmates: _flatmates,
          possession: _possession,
          highlights: _highlights,
          onCook: (value) => _set(_draft.copyWith(cookService: value)),
          onMaid: (value) => _set(_draft.copyWith(maidService: value)),
        ),
      ],
      BrokerFlowPage.rent => [
        BrokerRentPage(
          rent: _rent,
          deposit: _deposit,
          brokerage: _brokerage,
          oneTime: _oneTime,
          maintenance: _maintenance,
          electricity: _electricity,
          water: _water,
          wifi: _wifi,
          other: _other,
        ),
      ],
      BrokerFlowPage.photos => [
        BrokerPhotosPage(
          draft: _draft,
          onSamples: () => _set(_draft.copyWith(photos: wizardSamplePhotos)),
        ),
      ],
      BrokerFlowPage.review => [
        if (_draftSaved)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Draft saved on this device.',
              key: Key('broker-draft-saved'),
              style: TextStyle(color: HomiziColors.success),
            ),
          ),
        if (_previewing)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Preview of the published card.',
              key: Key('broker-preview-note'),
              style: TextStyle(color: HomiziColors.ink),
            ),
          ),
        BrokerReviewPage(
          draft: _synced(),
          ownerAuthorised: extras.ownerAuthorised,
          authorisationName: extras.authorisationName,
        ),
      ],
      BrokerFlowPage.published => [
        BrokerPublishedPage(draft: _draft, serverPublished: _serverPublished),
      ],
      BrokerFlowPage.desk => [_desk()],
      BrokerFlowPage.done => [_done()],
    };
  }

  Widget _desk() {
    if (_deskLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_deskError != null) {
      return Text(
        homiziText(context, _deskError!),
        key: const Key('broker-desk-error'),
      );
    }
    return Column(
      key: const Key('broker-desk'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Seekers matched to your listings'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            _basis ?? 'Scores use your listings. Phone numbers stay hidden.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (_seekers.isEmpty)
          Text(homiziText(context, 'No matching seekers yet.'))
        else
          for (final seeker in _seekers) _SeekerRow(seeker: seeker),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Your listings'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        if (_listings.isEmpty)
          Text(homiziText(context, 'No listings yet.'))
        else
          for (final listing in _listings)
            _ListingRow(
              listing: listing,
              brokerListed: listing.id == _draft.id,
            ),
      ],
    );
  }

  Widget _done() {
    final top = _seekers.isEmpty ? null : _seekers.first;
    return Column(
      key: const Key('broker-flow-confirmation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 48),
        const SizedBox(height: 12),
        const ListedByBrokerBadge(),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            top == null
                ? 'Your listings are on the desk. Seeker scores use the existing match.'
                : '${_listings.length} listings on the desk. Top seeker match is ${top.matchPercent}%.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
        ),
      ],
    );
  }

  Widget? _footer(BuildContext context) {
    if (_page == BrokerFlowPage.review) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('broker-flow-draft'),
              onPressed: _busy ? null : () => unawaited(_saveDraft()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
              ),
              child: Text(homiziText(context, 'Draft')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('broker-flow-preview'),
              onPressed: () => setState(() => _previewing = true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
              ),
              child: Text(homiziText(context, 'Preview')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              key: const Key('broker-flow-publish'),
              onPressed: _busy ? null : () => unawaited(_publish()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                homiziText(context, _busy ? 'Publishing…' : 'Publish'),
              ),
            ),
          ),
        ],
      );
    }
    if (_page == BrokerFlowPage.done) {
      return FilledButton(
        key: const Key('broker-flow-home'),
        onPressed: () => HomiziBackButton.leave(context),
        child: Text(homiziText(context, 'Go to home')),
      );
    }
    final label = switch (_page) {
      BrokerFlowPage.onboardDone => 'List your property',
      BrokerFlowPage.intro => 'Start listing',
      BrokerFlowPage.published => 'Open your desk',
      BrokerFlowPage.desk => 'Finish',
      _ => 'Continue',
    };
    return BrokerContinueButton(
      label: label,
      busy: _busy,
      onPressed: () => unawaited(_continue()),
    );
  }

  String? _stepLabel() {
    return switch (_page) {
      BrokerFlowPage.intent => '1/8',
      BrokerFlowPage.location => '2/8',
      BrokerFlowPage.nearby => '3/8',
      BrokerFlowPage.living => '4/8',
      BrokerFlowPage.rules => '5/8',
      BrokerFlowPage.services => '6/8',
      BrokerFlowPage.rent => '7/8',
      BrokerFlowPage.photos => '8/8',
      _ => null,
    };
  }

  String? _headline() {
    return switch (_page) {
      BrokerFlowPage.profile => 'Broker profile',
      BrokerFlowPage.verify => 'Verify your contact',
      BrokerFlowPage.badge => 'Broker trust badge',
      BrokerFlowPage.onboardDone => 'You\'re registered',
      BrokerFlowPage.intro => null,
      BrokerFlowPage.intent => 'Start Listing Your Property',
      BrokerFlowPage.location => 'Add Property Location',
      BrokerFlowPage.nearby => 'Nearby Places (Auto-detected)',
      BrokerFlowPage.living => 'Property & Living Details',
      BrokerFlowPage.rules => 'House Rules & Tenant Preference',
      BrokerFlowPage.services => 'Services, Flatmates & Availability',
      BrokerFlowPage.rent => 'Rent & Charges',
      BrokerFlowPage.photos => 'Upload Property Photos',
      BrokerFlowPage.review => 'Review & Publish',
      BrokerFlowPage.published => 'Listing saved',
      BrokerFlowPage.desk => 'Your broker desk',
      BrokerFlowPage.done => 'You\'re all set',
    };
  }

  String? _subtitle() {
    return switch (_page) {
      BrokerFlowPage.profile =>
        'Agency, RERA if you have one, areas, experience, and contact details.',
      BrokerFlowPage.verify =>
        'Mobile and email use a code. Aadhaar stays on Digio.',
      BrokerFlowPage.badge => 'Seekers see these checks on your profile.',
      BrokerFlowPage.onboardDone => 'Your broker profile is saved.',
      BrokerFlowPage.intro =>
        'Add complete details and photos to attract the right tenants.',
      BrokerFlowPage.intent => 'Choose what you want to list.',
      BrokerFlowPage.location =>
        'Enter the exact location. Nearby places can be filled in from it.',
      BrokerFlowPage.nearby =>
        'Approximate distance and time. You can edit the minutes.',
      BrokerFlowPage.living => 'Add important details about your property.',
      BrokerFlowPage.rules => 'Set your preferences to find the right tenants.',
      BrokerFlowPage.services =>
        'Add services, availability, and other details.',
      BrokerFlowPage.rent => 'Be transparent about all costs.',
      BrokerFlowPage.photos => 'Minimum 3 photos, in this sequence.',
      BrokerFlowPage.review => 'Check all details before publishing.',
      BrokerFlowPage.published => 'Listed by a broker.',
      BrokerFlowPage.desk => 'Your listings, and the seekers matched to them.',
      BrokerFlowPage.done => 'The broker flow is complete.',
    };
  }

  void _minutes(int index, int minutes) {
    if (index < 0 || index >= _draft.nearby.length) {
      return;
    }
    final next = [..._draft.nearby];
    next[index] = next[index].copyWith(minutes: minutes);
    _set(_draft.copyWith(nearby: next, nearbyEdited: true));
  }
}

Widget _introTitle(BuildContext context) {
  final style = Theme.of(
    context,
  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        homiziText(context, 'List Your Property'),
        style: style?.copyWith(color: HomiziColors.ink),
      ),
      Text(
        homiziText(context, 'in Just a Few Steps'),
        style: style?.copyWith(color: HomiziColors.accent),
      ),
    ],
  );
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.brokerListed});

  final OwnerListing listing;
  final bool brokerListed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: HomiziColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, listing.title),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                homiziText(
                  context,
                  '${listing.place} · ${formatInr(listing.rentInr)}',
                ),
                style: const TextStyle(color: HomiziColors.inkSoft),
              ),
              if (brokerListed) ...[
                const SizedBox(height: 6),
                const ListedByBrokerBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekerRow extends StatelessWidget {
  const _SeekerRow({required this.seeker});

  final SeekerMatch seeker;

  @override
  Widget build(BuildContext context) {
    final place = seeker.localities.isEmpty
        ? seeker.city
        : '${seeker.localities.first}, ${seeker.city}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: HomiziColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: HomiziColors.accentWash,
                foregroundColor: HomiziColors.ink,
                child: Text(
                  seeker.displayName.isEmpty
                      ? '?'
                      : seeker.displayName.substring(0, 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, seeker.displayName),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      homiziText(
                        context,
                        '$place · ${formatInr(seeker.budgetMinInr)}–${formatInr(seeker.budgetMaxInr)}',
                      ),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                    if (seeker.listingTitle.isNotEmpty)
                      Text(
                        homiziText(context, seeker.listingTitle),
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                homiziText(context, '${seeker.matchPercent}% match'),
                key: Key('broker-match-${seeker.requirementId}'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ListingDraft _seedDraft() {
  const city = 'Mumbai';
  const locality = 'Bandra West';
  return ListingDraft(
    title: 'Private room in a 2 BHK, Bandra West',
    city: city,
    locality: locality,
    listingIntent: 'room',
    buildingName: 'Sea View Residency',
    buildingKind: 'apartment',
    floorText: '4',
    totalFloorsText: '12',
    configuration: '2bhk',
    areaText: '950',
    rentableArea: 'single',
    nearby: declaredNearbyPlaces(),
    furnishing: 'furnished',
    parkingKind: 'bike',
    parking: true,
    propertyAgeText: '5',
    wcType: 'shared',
    waterSupply: 'municipal',
    waterHours: '24/7',
    inFlatAmenities: const [
      'wifi',
      'fridge',
      'ac',
      'washing_machine',
      'tv',
      'gas_pipeline',
    ],
    amenities: const [
      'wifi',
      'fridge',
      'ac',
      'washing_machine',
      'tv',
      'gas_pipeline',
    ],
    petsChoice: false,
    guestsAllowed: true,
    nonVegChoice: false,
    drinkingAllowed: false,
    partyingAllowed: false,
    suitableFor: const ['bachelors'],
    genderPreference: 'male',
    preferredOccupation: 'working_professional',
    cookService: true,
    maidService: true,
    flatmatesBrief: 'One working flatmate, male, in Bandra.',
    possessionDate: '1 December 2026',
    highlights: 'Well-lit room, close to the station, good natural light.',
    rentText: '25000',
    depositText: '75000',
    brokerageText: '25000',
    brokerageTerms: 'One month rent, paid when the agreement is signed',
    oneTimeChargesText: '5000',
    maintenanceText: '1500',
    waterChargeText: '500',
    photos: wizardSamplePhotos,
    listedBy: 'broker',
  );
}

String _titleFor(String intent, String locality, String configuration) {
  final place = locality.trim().isEmpty ? 'the city' : locality.trim();
  final config = _config(configuration);
  final title = switch (intent) {
    'whole_flat' => 'Whole flat${config.isEmpty ? '' : ' · $config'} in $place',
    'pg' => 'PG in $place',
    'shared_space' => 'Shared room in $place',
    _ => 'Private room in a ${config.isEmpty ? 'home' : config}, $place',
  };
  if (title.length <= 120) {
    return title;
  }
  return title.substring(0, 120);
}

String _config(String configuration) {
  for (final option in configurationOptions) {
    if (option.$1 == configuration) {
      return option.$2;
    }
  }
  return '';
}
