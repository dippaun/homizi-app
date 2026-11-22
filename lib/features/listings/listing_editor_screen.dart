import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart' as geo;
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/flow_accent.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/broker_flow/broker_listing_extras.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/host_flow/host_flow_chrome.dart';
import 'package:homizi/features/host_flow/listing_spec.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/features/listings/domain/room_share_plan.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_field_anchor.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/post_property/owner_extras.dart';
import 'package:homizi/features/post_property/pg_listing.dart';
import 'package:homizi/features/post_property/pg_owner_mode.dart';
import 'package:homizi/features/post_property/post_confirm_screen.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/post_property/poster_address_step.dart';
import 'package:homizi/features/publish/publish_gate.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Eight-section listing wizard. Drafts autosave once the server can store them.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({
    this.propertyId,
    this.fresh = false,
    this.brokerMode = false,
    this.spec = false,
    this.showMarketing = false,
    this.postFlow = false,
    this.pgMode = false,
    this.roomSharerMode = false,
    this.initialIntent = '',
    this.onLeaveIntro,
    super.key,
  });

  /// Owned listing to edit. Null resumes the latest draft.
  final String? propertyId;

  /// Start empty instead of resuming a draft.
  final bool fresh;

  /// Broker listing. Shows the brokerage fee, owner authorisation, and the
  /// Listed by Broker badge without changing the host wizard.
  final bool brokerMode;

  /// Spec layout used by `/list/start`, `/flow/listing`, and the host flow.
  final bool spec;

  /// Page 7, then the intro, then the eight steps. Edit of an existing
  /// listing skips this and opens the steps.
  final bool showMarketing;

  /// Groups the same eight sections into Basic Info, Property Details, and
  /// a skippable verification step. Publish still uses [InventoryGateway].
  final bool postFlow;

  /// Post as PG Owner. Starts the same stepper with paying-guest fields.
  final bool pgMode;

  /// Tenant room or full-house post. Address first, photos on the next page.
  final bool roomSharerMode;

  /// Intent chosen before the wizard, such as `shared_space` or `whole_flat`.
  final String initialIntent;

  bool get addressFirst => postFlow && (pgMode || brokerMode || roomSharerMode);

  /// Back from the first marketing page. The host flow returns to its confirmation.
  final VoidCallback? onLeaveIntro;

  @override
  ConsumerState<ListingEditorScreen> createState() =>
      _ListingEditorScreenState();
}

class _ListingEditorScreenState extends ConsumerState<ListingEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _locality;
  late final TextEditingController _building;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _maintenance;
  late final TextEditingController _brokerage;
  late final TextEditingController _brokerageTerms;
  late final TextEditingController _address;
  late final TextEditingController _landmark;
  late final TextEditingController _area;
  late final TextEditingController _floor;
  late final TextEditingController _totalFloors;
  late final TextEditingController _age;
  late final TextEditingController _waterHours;
  late final TextEditingController _oneTime;
  late final TextEditingController _electricity;
  late final TextEditingController _waterCharge;
  late final TextEditingController _wifiCharge;
  late final TextEditingController _otherMonthly;
  late final TextEditingController _flatmates;
  late final TextEditingController _possession;
  late final TextEditingController _highlights;
  var _loading = true;
  var _busy = false;
  var _step = 0;
  var _stage = 0;
  var _verifyLater = true;
  var _overview = false;
  var _intro = false;
  var _review = false;
  String? _note;
  var _titleTouched = false;
  final _targets = WizardTargets();
  final _formScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _overview = widget.spec && widget.showMarketing;
    _title = TextEditingController();
    _locality = TextEditingController();
    _building = TextEditingController();
    _rent = TextEditingController();
    _deposit = TextEditingController();
    _maintenance = TextEditingController();
    _brokerage = TextEditingController();
    _brokerageTerms = TextEditingController();
    _address = TextEditingController();
    _landmark = TextEditingController();
    _area = TextEditingController();
    _floor = TextEditingController();
    _totalFloors = TextEditingController();
    _age = TextEditingController();
    _waterHours = TextEditingController();
    _oneTime = TextEditingController();
    _electricity = TextEditingController();
    _waterCharge = TextEditingController();
    _wifiCharge = TextEditingController();
    _otherMonthly = TextEditingController();
    _flatmates = TextEditingController();
    _possession = TextEditingController();
    _highlights = TextEditingController();
    if (widget.pgMode) {
      unawaited(ref.read(pgOwnerModeProvider.notifier).enable());
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.fresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final poster = widget.pgMode
            ? posterPg
            : widget.brokerMode
            ? posterBroker
            : widget.roomSharerMode
            ? posterRoomSharer
            : '';
        final intent = widget.pgMode
            ? 'pg'
            : widget.initialIntent.trim().isNotEmpty
            ? widget.initialIntent.trim()
            : '';
        ref
            .read(listingDraftProvider.notifier)
            .update(
              ListingDraft(
                listedBy: widget.brokerMode ? 'broker' : 'host',
                city:
                    widget.spec &&
                        !widget.postFlow &&
                        !widget.pgMode &&
                        !widget.brokerMode &&
                        !widget.roomSharerMode
                    ? 'Ahmedabad'
                    : '',
                listingIntent: intent,
                propertyType: widget.pgMode
                    ? 'pg'
                    : intent == 'shared_space'
                    ? 'shared_room'
                    : 'apartment',
                posterKind: poster,
                rentableArea: widget.pgMode ? '' : '',
              ),
            );
        _ensureDemoPhotos();
        _ensureSuggestedTitle();
        setState(() => _loading = false);
      });
      return;
    }
    final current = ref.read(listingDraftProvider);
    final wanted = widget.propertyId;
    if (wanted == null &&
        (current.id != null || current.title.trim().isNotEmpty)) {
      _applyControllers(current);
      _loading = false;
      return;
    }
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadListingDraft(id: wanted);
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        ref.read(listingDraftProvider.notifier).update(loaded);
        _ensureDemoPhotos();
        _applyControllers(ref.read(listingDraftProvider));
      }
    } on InventoryFailure catch (error) {
      _note = error.message;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _ensureDemoPhotos() {
    if (!demoModeOn(ref)) {
      return;
    }
    final current = ref.read(listingDraftProvider);
    if (current.photos.length >= 3) {
      return;
    }
    ref
        .read(listingDraftProvider.notifier)
        .update(current.copyWith(photos: demoSampleListingPhotos));
  }

  void _applyControllers(ListingDraft draft) {
    if (draft.title.trim().isNotEmpty) {
      _titleTouched = true;
    }
    _assign(_title, draft.title);
    _assign(_locality, draft.locality);
    _assign(_building, draft.buildingName);
    _assign(_rent, draft.rentText);
    _assign(_deposit, draft.depositText);
    _assign(_maintenance, draft.maintenanceText);
    _assign(_brokerage, draft.brokerageText);
    _assign(_brokerageTerms, draft.brokerageTerms);
    _assign(_address, draft.addressLine);
    _assign(_landmark, draft.landmark);
    _assign(_area, draft.areaText);
    _assign(_floor, draft.floorText);
    _assign(_totalFloors, draft.totalFloorsText);
    _assign(_age, draft.propertyAgeText);
    _assign(_waterHours, draft.waterHours);
    _assign(_oneTime, draft.oneTimeChargesText);
    _assign(_electricity, draft.electricityText);
    _assign(_waterCharge, draft.waterChargeText);
    _assign(_wifiCharge, draft.wifiChargeText);
    _assign(_otherMonthly, draft.otherMonthlyText);
    _assign(_flatmates, draft.flatmatesBrief);
    _assign(_possession, draft.possessionDate);
    _assign(_highlights, draft.highlights);
  }

  /// A late draft load must not replace characters the person already typed.
  void _assign(TextEditingController controller, String value) {
    if (controller.text.isNotEmpty) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _locality.dispose();
    _building.dispose();
    _rent.dispose();
    _deposit.dispose();
    _maintenance.dispose();
    _brokerage.dispose();
    _brokerageTerms.dispose();
    _address.dispose();
    _landmark.dispose();
    _area.dispose();
    _floor.dispose();
    _totalFloors.dispose();
    _age.dispose();
    _waterHours.dispose();
    _oneTime.dispose();
    _electricity.dispose();
    _waterCharge.dispose();
    _wifiCharge.dispose();
    _otherMonthly.dispose();
    _flatmates.dispose();
    _possession.dispose();
    _highlights.dispose();
    _formScroll.dispose();
    _targets.dispose();
    super.dispose();
  }

  void _onTitleEdited(String value) {
    final draft = ref.read(listingDraftProvider);
    final suggested = suggestedListingTitle(
      intent: draft.listingIntent,
      city: draft.city,
      locality: draft.locality,
    );
    _titleTouched = suggested == null || value.trim() != suggested;
  }

  /// Fills an untouched title from the type and place so Basic Info does
  /// not wait on a field the person never saw.
  void _ensureSuggestedTitle() {
    if (_titleTouched) {
      return;
    }
    final draft = ref.read(listingDraftProvider);
    final next = suggestedListingTitle(
      intent: draft.listingIntent,
      city: draft.city,
      locality: draft.locality.trim().isNotEmpty
          ? draft.locality
          : _locality.text.trim(),
    );
    if (next == null) {
      return;
    }
    _assignIfDifferent(_title, next);
    if (draft.title != next) {
      ref
          .read(listingDraftProvider.notifier)
          .update(draft.copyWith(title: next));
    }
    if (_note != null &&
        _note!.toLowerCase().contains('title') &&
        next.length >= 3) {
      _note = null;
    }
  }

  ListingDraft _draftForGaps(ListingDraft draft) {
    if (_titleTouched || draft.title.trim().length >= 3) {
      return draft;
    }
    final suggested = suggestedListingTitle(
      intent: draft.listingIntent,
      city: draft.city,
      locality: draft.locality,
    );
    if (suggested == null) {
      return draft;
    }
    return draft.copyWith(title: suggested);
  }

  /// Basic Info only waits for a property type. Later stages name the
  /// first missing answer.
  String? _postReadyBlocker(ListingDraft draft) {
    if (widget.addressFirst) {
      if (_stage == 0) {
        return posterAddressGap(draft, rooms: widget.pgMode);
      }
      if (_stage == 1) {
        for (final gap in wizardGaps(_draftForGaps(draft))) {
          if (!gap.toLowerCase().contains('photo')) {
            return gap;
          }
        }
        return null;
      }
      if (_stage == 2) {
        final photos = photoQualityGaps(draft.photos);
        return photos.isEmpty ? null : photos.first;
      }
      return null;
    }
    if (_stage == 0) {
      if (draft.listingIntent.isEmpty) {
        return 'Choose what you want to list.';
      }
      return null;
    }
    if (_stage != 1) {
      return null;
    }
    final gaps = wizardGaps(_draftForGaps(draft));
    if (gaps.isEmpty) {
      return null;
    }
    return gaps.first;
  }

  bool _pointsAtField(String note) {
    final id = wizardAnchorId(note);
    if (id != 'intent') {
      return true;
    }
    return note.toLowerCase().contains('what you want to list');
  }

  void _persist() {
    final current = ref.read(listingDraftProvider);
    final broker =
        widget.brokerMode || ref.read(currentRoleProvider) == HomiziRole.broker;
    final pg = widget.pgMode || isPgDraft(current);
    final sharing = pg ? lowestPgSharingRent(current.pgJson) : null;
    final amenities = [
      for (final key in current.amenities)
        if (!inFlatAmenityKeys.contains(key)) key,
      ...current.inFlatAmenities,
    ];
    ref
        .read(listingDraftProvider.notifier)
        .update(
          current.copyWith(
            title: _title.text,
            locality: _locality.text,
            buildingName: shortBuildingName(_building.text),
            rentText: sharing == null ? _rent.text : '$sharing',
            depositText: _deposit.text,
            maintenanceText: _maintenance.text,
            brokerageText: _brokerage.text,
            addressLine: _address.text.trim().length <= 160
                ? _address.text.trim()
                : _address.text.trim().substring(0, 160).trimRight(),
            landmark: _landmark.text,
            areaText: _area.text,
            floorText: floorApplies(current.buildingKind) ? _floor.text : '',
            totalFloorsText: floorApplies(current.buildingKind)
                ? _totalFloors.text
                : '',
            listedBy: broker ? 'broker' : current.listedBy,
            posterKind: current.posterKind.trim().isNotEmpty
                ? current.posterKind
                : widget.pgMode
                ? posterPg
                : broker
                ? posterBroker
                : widget.roomSharerMode
                ? posterRoomSharer
                : current.posterKind,
            brokerageTerms: _brokerageTerms.text,
            propertyAgeText: _age.text,
            waterHours: _waterHours.text,
            oneTimeChargesText: _oneTime.text,
            electricityText: _electricity.text,
            waterChargeText: _waterCharge.text,
            wifiChargeText: _wifiCharge.text,
            otherMonthlyText: _otherMonthly.text,
            flatmatesBrief: showsFlatmates(current) ? _flatmates.text : '',
            possessionDate: _possession.text,
            highlights: _highlights.text,
            amenities: amenities,
          ),
        );
  }

  void _set(ListingDraft Function(ListingDraft current) change) {
    _persist();
    final current = ref.read(listingDraftProvider);
    ref.read(listingDraftProvider.notifier).update(change(current));
  }

  void _refreshNearby(String locality, String city) {
    final places = nearbyPlacesFor(city: city, locality: locality);
    _set(
      (current) => current.copyWith(
        locality: locality,
        city: city,
        nearby: places,
        nearbyEdited: false,
      ),
    );
    _assignIfDifferent(_locality, locality);
    _ensureSuggestedTitle();
    unawaited(_measureNearbyIfMapped());
  }

  /// Replaces estimates when a maps key and a point are both present.
  Future<void> _measureNearbyIfMapped() async {
    final service = ref.read(locationServiceProvider);
    if (!service.mapsEnabled) {
      return;
    }
    final current = ref.read(listingDraftProvider);
    if (current.nearbyEdited || current.locality.trim().isEmpty) {
      return;
    }
    final origin = _draftPoint(current);
    if (origin == null) {
      return;
    }
    final rows = await measureNearbyCommute(
      service: service,
      origin: origin,
      city: current.city,
      locality: current.locality,
      mapsApiKey: ref.read(appConfigProvider).mapsApiKey,
    );
    if (!mounted || rows.isEmpty) {
      return;
    }
    final latest = ref.read(listingDraftProvider);
    if (latest.nearbyEdited ||
        latest.locality.trim() != current.locality.trim()) {
      return;
    }
    ref
        .read(listingDraftProvider.notifier)
        .update(latest.copyWith(nearby: rows));
  }

  geo.GeoFix? _draftPoint(ListingDraft current) {
    final latitude = current.latitude;
    final longitude = current.longitude;
    if (latitude != null && longitude != null) {
      return geo.GeoFix(latitude: latitude, longitude: longitude);
    }
    final approx = approxPointFor(current.city, current.locality);
    if (approx == null) {
      return null;
    }
    return geo.GeoFix(latitude: approx.$1, longitude: approx.$2);
  }

  void _assignIfDifferent(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  List<String> _stepIssues() {
    _ensureSuggestedTitle();
    _persist();
    final blockers = ref.read(listingDraftProvider).persistBlockers();
    return switch (_step) {
      0 => [
        for (final issue in blockers)
          if (issue.contains('title')) issue,
      ],
      1 => [
        for (final issue in blockers)
          if (issue.contains('locality') ||
              issue.contains('city') ||
              issue.contains('street') ||
              issue.contains('area') ||
              issue.toLowerCase().contains('floor') ||
              issue.contains('building'))
            issue,
      ],
      6 => [
        for (final issue in blockers)
          if (issue.contains('rent') ||
              issue.contains('deposit') ||
              issue.contains('maintenance') ||
              issue.contains('charges') ||
              issue.contains('electricity') ||
              issue.contains('Wi-Fi') ||
              issue.contains('water charges') ||
              issue.contains('one-time'))
            issue,
      ],
      _ => const <String>[],
    };
  }

  Future<bool> _autosave() async {
    _persist();
    final draft = ref.read(listingDraftProvider);
    if (draft.persistBlockers().isNotEmpty) {
      return true;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .saveListing(draft);
      if (!mounted) {
        return false;
      }
      ref
          .read(listingDraftProvider.notifier)
          .update(
            ref
                .read(listingDraftProvider)
                .copyWith(id: result.draft.id, photos: result.draft.photos),
          );
      setState(() {
        _note = result.message;
        _busy = false;
      });
      return true;
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
      return false;
    }
  }

  Future<void> _continue() async {
    final demo = demoModeOn(ref);
    final issues = _stepIssues();
    if (issues.isNotEmpty && !demo) {
      _pointAt(issues.first);
      return;
    }
    if (_step == 1) {
      await _measureNearbyIfMapped();
      _ensureNearbyRows();
    }
    if (_step >= 1) {
      final saved = await _autosave();
      if (!mounted || (!saved && !demo)) {
        return;
      }
    }
    setState(() {
      _note = null;
      if (widget.spec && _step >= listingWizardSteps.length - 1) {
        _review = true;
      } else {
        _step = (_step + 1).clamp(0, listingWizardSteps.length - 1);
      }
    });
  }

  NearbyPlace _nearbyRow(
    String kind,
    Map<String, NearbyPlace> known,
    Map<String, NearbyPlace> estimates,
  ) {
    final existing = known[kind];
    if (existing != null && existing.name.trim().isNotEmpty) {
      return existing;
    }
    return estimates[kind] ?? existing ?? NearbyPlace(kind: kind, name: '');
  }

  void _ensureNearbyRows() {
    final current = ref.read(listingDraftProvider);
    if (current.nearby.length >= nearbyKinds.length) {
      return;
    }
    final known = {for (final place in current.nearby) place.kind: place};
    final estimates = {
      for (final place in realisticNearbyPlaces(
        city: current.city,
        locality: current.locality,
      ))
        place.kind: place,
    };
    ref
        .read(listingDraftProvider.notifier)
        .update(
          current.copyWith(
            nearby: [
              for (final kind in nearbyKinds)
                _nearbyRow(kind, known, estimates),
            ],
          ),
        );
  }

  int get _lastPostStage => widget.addressFirst ? 3 : 2;

  bool _visibleStep(int step) {
    if (!widget.postFlow) {
      return _step == step;
    }
    if (widget.addressFirst) {
      if (_stage == 1) {
        if (step == 0) {
          return !widget.pgMode;
        }
        return step >= 1 && step <= 6;
      }
      if (_stage == 2) {
        return step == 7;
      }
      return false;
    }
    if (_stage == 0) {
      return step <= 1;
    }
    if (_stage == 1) {
      return step >= 2;
    }
    return false;
  }

  void _postAdvance() {
    _persist();
    if (_stage == 0) {
      _ensureNearbyRows();
    }
    setState(() {
      _note = null;
      _stage = (_stage + 1).clamp(0, _lastPostStage);
    });
  }

  void _listingBack() {
    if (widget.postFlow) {
      if (_stage > 0) {
        setState(() => _stage -= 1);
        return;
      }
      HomiziBackButton.leave(context);
      return;
    }
    if (_review) {
      setState(() => _review = false);
      return;
    }
    if (!_overview && !_intro && _step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (widget.showMarketing && !_overview && !_intro) {
      setState(() => _intro = true);
      return;
    }
    if (widget.showMarketing && _intro) {
      setState(() {
        _intro = false;
        _overview = true;
      });
      return;
    }
    final leave = widget.onLeaveIntro;
    if (leave != null) {
      leave();
      return;
    }
    HomiziBackButton.leave(context);
  }

  void _applyPlace(geo.PlaceSuggestion place, {required String kind}) {
    final label = place.label.trim();
    if (kind == 'address') {
      _assignIfDifferent(_address, label);
    } else if (kind == 'landmark') {
      _assignIfDifferent(_landmark, label);
    } else if (kind == 'building') {
      _assignIfDifferent(_building, shortBuildingName(label));
    }
    final locality = (place.locality ?? '').trim();
    final cityName = (place.city ?? '').trim();
    if (locality.isNotEmpty) {
      _assignIfDifferent(_locality, locality);
    }
    if (place.hasCoordinates) {
      _set(
        (draft) => draft.copyWith(
          latitude: place.latitude,
          longitude: place.longitude,
          locality: locality.isNotEmpty ? locality : draft.locality,
          city: cityName.isNotEmpty ? cityName : draft.city,
        ),
      );
    }
    if (locality.isNotEmpty) {
      _refreshNearby(
        locality,
        cityName.isNotEmpty ? cityName : ref.read(listingDraftProvider).city,
      );
    } else {
      unawaited(_measureNearbyIfMapped());
    }
    if (label.isEmpty) {
      return;
    }
    setState(() => _note = '$label set from maps. Nearby places updated.');
  }

  void _pointAt(String note) {
    final id = wizardAnchorId(note);
    final node = _targets.focus(id);
    setState(() {
      _note = note;
      if (widget.postFlow) {
        _stage = postStageForGap(note);
      } else {
        _step = wizardStepForGap(note);
        _intro = false;
        _overview = false;
        _review = false;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = _targets.key(id).currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.12,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      if (node.context != null) {
        node.requestFocus();
      }
    });
  }

  /// A Places pick in the locality box: locality is the first part of the
  /// suggestion, the city follows when it is one we list, and the
  /// coordinates are kept.
  void _onLocalityPlace(geo.PlaceSuggestion place) {
    final parts = [
      for (final part in place.label.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (parts.isEmpty) {
      return;
    }
    final locality = parts.first;
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
    final current = ref.read(listingDraftProvider);
    _refreshNearby(locality, city ?? current.city);
    if (place.hasCoordinates) {
      _set(
        (draft) => draft.copyWith(
          latitude: place.latitude,
          longitude: place.longitude,
          addressLine: (place.address ?? place.label).trim().isEmpty
              ? draft.addressLine
              : (place.address ?? place.label).trim(),
        ),
      );
    } else {
      final line = (place.address ?? place.label).trim();
      if (line.isNotEmpty) {
        _assignIfDifferent(_address, line);
      }
    }
  }

  Future<void> _save() async {
    final saved = await _autosave();
    if (!saved || !mounted) {
      return;
    }
    final issues = ref.read(listingDraftProvider).persistBlockers();
    if (issues.isNotEmpty) {
      _pointAt(issues.first);
      return;
    }
    if (demoModeOn(ref)) {
      setState(
        () => _note = 'Draft kept on this device. Nothing was published.',
      );
    }
  }

  /// Sharing a room is a roommate-finder post. No second prompt.
  Future<void> _publishSharedRoom() async {
    final ask = ref
        .read(finderProvider)
        .ask
        .copyWith(profilePosted: true, postAsked: true);
    ref.read(finderProvider.notifier).saveAsk(ask);
    await writeDeviceString('roommate_finder_post', 'allow');
    await LiveAccountSync.roommateBrief(ask.toJson());
  }

  Future<void> _publish() async {
    if (!await requireSignedInToPublish(context, ref)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final demo = demoModeOn(ref);
    _ensureSuggestedTitle();
    _persist();
    if (demo) {
      _ensureDemoPhotos();
    }
    final draft = ref.read(listingDraftProvider);
    final issues = releaseGaps(draft);
    if (issues.isNotEmpty) {
      _pointAt(issues.first);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .publishListing(draft);
      if (!mounted) {
        return;
      }
      ref.read(listingDraftProvider.notifier).update(result.draft);
      if (widget.roomSharerMode ||
          result.draft.listingIntent == 'shared_space') {
        await _publishSharedRoom();
      }
      if (!mounted) {
        return;
      }
      if (widget.postFlow) {
        rememberPublishedHome(
          ref,
          result.draft,
          onServer: result.publishedByServer,
        );
        ref
            .read(ownerPostOutcomeProvider.notifier)
            .set(
              OwnerPostOutcome(
                draft: result.draft,
                verifyLater: _verifyLater,
                serverPublished: result.publishedByServer,
              ),
            );
        if (!mounted) {
          return;
        }
        setState(() => _busy = false);
        if (GoRouter.maybeOf(context) != null) {
          final pgOwner =
              widget.pgMode ||
              result.draft.listingIntent == 'pg' ||
              result.draft.posterKind == posterPg;
          if (pgOwner) {
            await ref.read(pgOwnerModeProvider.notifier).enable();
            if (!mounted) {
              return;
            }
            context.go(RoutePaths.home);
          } else {
            context.go(RoutePaths.postOwnerDone);
          }
        }
        return;
      }
      final shown = await finishListingPublish(context, ref, result: result);
      if (!mounted) {
        return;
      }
      if (shown) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _note = result.message;
        _busy = false;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  void _toggleAmenity(String key, bool selected) {
    _set((current) {
      final next = [
        for (final item in current.inFlatAmenities)
          if (item != key) item,
        if (selected) key,
      ];
      return current.copyWith(inFlatAmenities: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(listingDraftProvider);
    final role = ref.watch(currentRoleProvider);
    if (widget.spec && _overview) {
      return ListingTransparencyPage(
        onBack: _listingBack,
        onContinue: () => setState(() {
          _overview = false;
          _intro = true;
        }),
      );
    }
    if (widget.spec && _intro) {
      return ListingIntroPage(
        onBack: _listingBack,
        onContinue: () => setState(() => _intro = false),
      );
    }
    final last = _step == listingWizardSteps.length - 1;
    final gaps = releaseGaps(draft);
    final broker =
        widget.brokerMode ||
        role == HomiziRole.broker ||
        draft.listedBy == 'broker';
    if (widget.spec && _review && !_loading) {
      return ListingReviewPage(
        draft: draft,
        gaps: gaps,
        busy: _busy,
        note: _note,
        onBack: _listingBack,
        onDraft: () => unawaited(_save()),
        onPreview: () {
          _persist();
          context.push(RoutePaths.listingPreview);
        },
        onPublish: () => unawaited(_publish()),
      );
    }
    final postBlocker = widget.postFlow ? _postReadyBlocker(draft) : null;
    final shownNote = postBlocker ?? _note;
    final scaffold = Scaffold(
      key: widget.postFlow ? const Key('post-owner-flow') : null,
      backgroundColor: widget.postFlow
          ? HomiziColors.white
          : widget.spec
          ? HomiziColors.soft
          : HomiziColors.white,
      appBar: widget.postFlow
          ? PostPropertyBar(onBack: _listingBack)
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: widget.spec ? 72 : null,
              backgroundColor: widget.spec ? HomiziColors.soft : null,
              leading: HomiziBackButton(
                key: const Key('listing-flow-back'),
                onPressed: _listingBack,
              ),
              title: widget.spec
                  ? const SizedBox(width: 190, child: FlowWordmark())
                  : Text(homiziText(context, 'List your property')),
            ),
      body: ListingWizardScope(
        targets: _targets,
        child: PageBackground(
          variant: pageVariantFor(
            widget.postFlow ? 'post-owner-listing' : 'listing-wizard',
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(key: Key('listing-loading')),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: widget.postFlow
                          ? PostStepper(
                              labels: widget.addressFirst
                                  ? const [
                                      'Address',
                                      'Details',
                                      'Photos',
                                      'Verification',
                                    ]
                                  : const [
                                      'Basic Info',
                                      'Property Details',
                                      'Verification',
                                    ],
                              index: _stage,
                            )
                          : StepHeader(
                              step: _step + 1,
                              total: listingWizardSteps.length,
                              title: widget.spec
                                  ? listingFlowTitles[_step]
                                  : listingWizardSteps[_step],
                              subtitle: widget.spec
                                  ? listingFlowSubtitles[_step]
                                  : null,
                              progressColor: widget.spec
                                  ? HomiziColors.logoOrange
                                  : HomiziColors.accent,
                              fractionKey: const Key('flow-step-pill'),
                            ),
                    ),
                    if (widget.spec && !widget.postFlow)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          homiziText(context, listingFlowSection[_step]),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        controller: _formScroll,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          widget.postFlow ? 140 : 24,
                        ),
                        children: [
                          if (widget.postFlow &&
                              widget.addressFirst &&
                              _stage == 0)
                            PosterAddressStep(
                              draft: draft,
                              rooms: widget.pgMode,
                              onChanged: (next) {
                                _assignIfDifferent(
                                  _building,
                                  next.buildingName,
                                );
                                _assignIfDifferent(_address, next.addressLine);
                                _assignIfDifferent(_locality, next.locality);
                                ref
                                    .read(listingDraftProvider.notifier)
                                    .update(next);
                                _ensureSuggestedTitle();
                              },
                            ),
                          if (widget.postFlow &&
                              !widget.addressFirst &&
                              _stage == 0)
                            const OwnerContactFields(),
                          if (widget.postFlow &&
                              widget.addressFirst &&
                              _stage == 2) ...[
                            Text(
                              homiziText(context, 'Photos'),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PropertyPhotoUploadCard(
                              onTap: () async {
                                _persist();
                                await context.push(RoutePaths.photoManager);
                                if (mounted) {
                                  await _autosave();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (widget.postFlow && _stage == 1) ...[
                            Text(
                              homiziText(context, 'Property Details'),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListingTitleField(
                              controller: _title,
                              onChanged: _onTitleEdited,
                            ),
                            const SizedBox(height: 12),
                            if (!widget.addressFirst)
                              PropertyPhotoUploadCard(
                                onTap: () async {
                                  _persist();
                                  await context.push(RoutePaths.photoManager);
                                  if (mounted) {
                                    await _autosave();
                                  }
                                },
                              ),
                            if (!widget.addressFirst)
                              const SizedBox(height: 12),
                          ],
                          if (widget.postFlow &&
                              _stage == (widget.addressFirst ? 3 : 2))
                            OwnerVerifyPanel(
                              onVerifyLater: () {
                                setState(() => _verifyLater = true);
                                unawaited(_publish());
                              },
                            ),
                          if (_visibleStep(0) &&
                              !(widget.addressFirst &&
                                  draft.listingIntent.isNotEmpty))
                            IntentStep(
                              draft: draft,
                              title: _title,
                              hostPair:
                                  widget.spec &&
                                  !widget.postFlow &&
                                  !widget.pgMode &&
                                  !widget.brokerMode &&
                                  !widget.roomSharerMode,
                              showTitle: !widget.postFlow,
                              onTitleChanged: _onTitleEdited,
                              onIntent: (value) {
                                _set(
                                  (current) => current.copyWith(
                                    listingIntent: value,
                                    rentableArea: rentableForIntent(value),
                                  ),
                                );
                                _ensureSuggestedTitle();
                              },
                            ),
                          if (_visibleStep(1))
                            LocationStep(
                              draft: draft,
                              locality: _locality,
                              building: _building,
                              area: _area,
                              floor: _floor,
                              totalFloors: _totalFloors,
                              landmark: _landmark,
                              hidePlace: widget.addressFirst,
                              hideArea: widget.pgMode || isPgDraft(draft),
                              onCity: (city) =>
                                  _refreshNearby(_locality.text, city),
                              onLocality: (value) {
                                _assignIfDifferent(_locality, value);
                                _refreshNearby(value, draft.city);
                              },
                              onPlace: _onLocalityPlace,
                              onLandmarkPlace: (place) =>
                                  _applyPlace(place, kind: 'landmark'),
                              onFlat: (value) => _set(
                                (current) => current.copyWith(flatNo: value),
                              ),
                              onShare: (value) {
                                final plan = RoomSharePlan.decode(value);
                                final shared = plan.occupancy.any(
                                  (seats) => seats >= 2,
                                );
                                _set(
                                  (current) => current.copyWith(
                                    shareJson: value,
                                    rentableArea: shared ? 'double' : 'single',
                                  ),
                                );
                              },
                              onBuildingKind: (value) {
                                if (!floorApplies(value)) {
                                  _floor.clear();
                                  _totalFloors.clear();
                                }
                                _set(
                                  (current) => current.copyWith(
                                    buildingKind: value,
                                    floorText: floorApplies(value)
                                        ? current.floorText
                                        : '',
                                    totalFloorsText: floorApplies(value)
                                        ? current.totalFloorsText
                                        : '',
                                  ),
                                );
                              },
                              onConfiguration: (value) => _set(
                                (current) =>
                                    current.copyWith(configuration: value),
                              ),
                            ),
                          if (_visibleStep(2))
                            NearbyStep(
                              draft: draft,
                              latitude:
                                  draft.latitude ??
                                  approxPointFor(
                                    draft.city,
                                    draft.locality,
                                  )?.$1,
                              longitude:
                                  draft.longitude ??
                                  approxPointFor(
                                    draft.city,
                                    draft.locality,
                                  )?.$2,
                              mapsEnabled: ref
                                  .watch(appConfigProvider)
                                  .mapsEnabled,
                              apiKey: ref.watch(appConfigProvider).mapsApiKey,
                              mapLabel: draft.locality.trim().isEmpty
                                  ? 'Your home'
                                  : draft.locality.trim(),
                              onChanged: (index, place) {
                                final next = [...draft.nearby];
                                if (index < 0 || index >= next.length) {
                                  return;
                                }
                                next[index] = place;
                                _set(
                                  (current) => current.copyWith(
                                    nearby: next,
                                    nearbyEdited: true,
                                  ),
                                );
                              },
                            ),
                          if (_visibleStep(3) && draft.listingIntent == 'pg')
                            PgListingFields(
                              details: PgListingDetails.decode(draft.pgJson),
                              amenities: draft.inFlatAmenities,
                              onChanged: (details) {
                                final encoded = details.encode();
                                final lowest = lowestPgSharingRent(encoded);
                                if (lowest != null) {
                                  _assign(_rent, '$lowest');
                                }
                                _set(
                                  (current) => current.copyWith(
                                    pgJson: encoded,
                                    rentText: lowest == null
                                        ? current.rentText
                                        : '$lowest',
                                  ),
                                );
                              },
                              onAmenity: _toggleAmenity,
                            ),
                          if (_visibleStep(3))
                            LivingStep(
                              draft: draft,
                              age: _age,
                              waterHours: _waterHours,
                              onFurnishing: (value) => _set(
                                (current) =>
                                    current.copyWith(furnishing: value),
                              ),
                              onParking: (value) => _set(
                                (current) => current.copyWith(
                                  parkingKind: value,
                                  parking: value == 'car' || value == 'bike',
                                ),
                              ),
                              onWc: (value) => _set(
                                (current) => current.copyWith(wcType: value),
                              ),
                              onWater: (value) => _set(
                                (current) =>
                                    current.copyWith(waterSupply: value),
                              ),
                              onAmenity: _toggleAmenity,
                              showAmenities: draft.listingIntent != 'pg',
                            ),
                          if (_visibleStep(4))
                            RulesStep(
                              draft: draft,
                              onPets: (value) => _set(
                                (current) => current.copyWith(
                                  petsChoice: value,
                                  petsAllowed: value,
                                ),
                              ),
                              onSmoking: (value) => _set(
                                (current) =>
                                    current.copyWith(smokingChoice: value),
                              ),
                              onSchedule: (value) => _set(
                                (current) =>
                                    current.copyWith(occupantSchedule: value),
                              ),
                              onGuests: (value) => _set(
                                (current) =>
                                    current.copyWith(guestsAllowed: value),
                              ),
                              onNonVeg: (value) => _set(
                                (current) => current.copyWith(
                                  nonVegChoice: value,
                                  nonVegAllowed: value,
                                ),
                              ),
                              onDrinking: (value) => _set(
                                (current) =>
                                    current.copyWith(drinkingAllowed: value),
                              ),
                              onPartying: (value) => _set(
                                (current) =>
                                    current.copyWith(partyingAllowed: value),
                              ),
                              onSuitable: (value) => _set((current) {
                                final selected = current.suitableFor.contains(
                                  value,
                                );
                                return current.copyWith(
                                  suitableFor: [
                                    for (final item in current.suitableFor)
                                      if (item != value) item,
                                    if (!selected) value,
                                  ],
                                );
                              }),
                              onFriendlyTag: (value) => _set((current) {
                                final selected = current.friendlyTags.contains(
                                  value,
                                );
                                return current.copyWith(
                                  friendlyTags: [
                                    for (final item in current.friendlyTags)
                                      if (item != value) item,
                                    if (!selected) value,
                                  ],
                                );
                              }),
                              onGender: (value) => _set(
                                (current) =>
                                    current.copyWith(genderPreference: value),
                              ),
                              onOccupation: (value) => _set(
                                (current) => current.copyWith(
                                  preferredOccupation: value,
                                ),
                              ),
                            ),
                          if (_visibleStep(5))
                            ServicesStep(
                              draft: draft,
                              flatmates: _flatmates,
                              possession: _possession,
                              highlights: _highlights,
                              onCook: (value) => _set(
                                (current) =>
                                    current.copyWith(cookService: value),
                              ),
                              onMaid: (value) => _set(
                                (current) =>
                                    current.copyWith(maidService: value),
                              ),
                              onConsent: (value) => _set(
                                (current) => current.copyWith(
                                  linkFlatmateProfiles: value,
                                ),
                              ),
                              hidePossession: widget.pgMode || isPgDraft(draft),
                            ),
                          if (_visibleStep(6)) ...[
                            ChargesStep(
                              draft: draft,
                              rent: _rent,
                              deposit: _deposit,
                              brokerage: _brokerage,
                              oneTime: _oneTime,
                              maintenance: _maintenance,
                              electricity: _electricity,
                              water: _waterCharge,
                              wifi: _wifiCharge,
                              other: _otherMonthly,
                              brokerageTerms: _brokerageTerms,
                              showBroker: broker,
                              hideRent: widget.pgMode || isPgDraft(draft),
                            ),
                            if (broker) ...[
                              const SizedBox(height: 8),
                              const BrokerOwnerAuthorisation(),
                            ],
                          ],
                          if ((widget.spec && _step == 7) ||
                              (widget.postFlow && _visibleStep(7))) ...[
                            ListingPhotoBoard(draft: draft),
                            const SizedBox(height: 12),
                          ],
                          if (_visibleStep(7))
                            PhotosStep(
                              draft: draft,
                              onSamples: () => _set(
                                (current) => current.copyWith(
                                  photos: demoSampleListingPhotos,
                                ),
                              ),
                              onManage: () async {
                                _persist();
                                await context.push(RoutePaths.photoManager);
                                if (mounted) {
                                  await _autosave();
                                }
                              },
                            ),
                          if (last && broker) ...[
                            const SizedBox(height: 12),
                            const ListedByBrokerBadge(),
                          ],
                          if (last && !widget.spec) ...[
                            const SizedBox(height: 16),
                            if (gaps.isEmpty)
                              Text(
                                homiziText(
                                  context,
                                  'Ready to publish. The server still checks the listing.',
                                ),
                              )
                            else ...[
                              Text(
                                key: const Key('listing-missing'),
                                homiziText(
                                  context,
                                  'Publish stays off until these are filled:',
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final gap in gaps)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(homiziText(context, '• $gap')),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: _loading
          ? null
          : Material(
              color: HomiziColors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (shownNote != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('listing-save-note'),
                            style: TextButton.styleFrom(
                              foregroundColor: postBlocker != null
                                  ? HomiziColors.error
                                  : HomiziColors.ink,
                              disabledForegroundColor: postBlocker != null
                                  ? HomiziColors.error
                                  : HomiziColors.ink,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _pointsAtField(shownNote)
                                ? () => _pointAt(shownNote)
                                : null,
                            child: Text(
                              homiziText(context, shownNote),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (widget.postFlow)
                        PostGradientButton(
                          buttonKey: const Key('post-owner-continue'),
                          label: _stage == _lastPostStage
                              ? 'Publish listing'
                              : 'Continue',
                          busy: _busy,
                          ready: postBlocker == null && !_busy,
                          onPressed: _busy
                              ? null
                              : () {
                                  _ensureSuggestedTitle();
                                  _persist();
                                  final block = _postReadyBlocker(
                                    ref.read(listingDraftProvider),
                                  );
                                  if (block != null) {
                                    _pointAt(block);
                                    return;
                                  }
                                  if (_stage < _lastPostStage) {
                                    _postAdvance();
                                    return;
                                  }
                                  final docs = ref.read(ownerDocsProvider);
                                  setState(() => _verifyLater = !docs.any);
                                  unawaited(_publish());
                                },
                        )
                      else if (widget.spec)
                        FlowContinueButton(
                          buttonKey: const Key('listing-continue'),
                          label: 'Continue',
                          busy: _busy,
                          gradient: true,
                          onPressed: _busy
                              ? null
                              : () => unawaited(_continue()),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              key: Key(
                                last ? 'save-listing' : 'listing-save-anytime',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_save()),
                              child: Text(
                                homiziText(
                                  context,
                                  _busy ? 'Saving…' : 'Save draft',
                                ),
                              ),
                            ),
                            if (!last)
                              FilledButton(
                                key: const Key('listing-continue'),
                                onPressed: _busy
                                    ? null
                                    : () => unawaited(_continue()),
                                child: Text(homiziText(context, 'Continue')),
                              ),
                            if (last) ...[
                              OutlinedButton(
                                onPressed: () {
                                  _persist();
                                  context.push(RoutePaths.listingPreview);
                                },
                                child: Text(
                                  homiziText(context, 'Preview listing'),
                                ),
                              ),
                              FilledButton(
                                key: const Key('listing-review-publish'),
                                onPressed: _busy || gaps.isNotEmpty
                                    ? null
                                    : () => unawaited(_publish()),
                                child: Text(homiziText(context, 'Publish')),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
    if (!widget.postFlow) {
      return scaffold;
    }
    final theme = Theme.of(context);
    return FlowAccentScope(
      child: Theme(
        data: theme.copyWith(
          chipTheme: theme.chipTheme.copyWith(
            backgroundColor: HomiziColors.white,
            selectedColor: HomiziColors.homiziLavender,
            checkmarkColor: HomiziColors.homiziPurple,
            labelStyle: const TextStyle(color: HomiziColors.ink),
            secondaryLabelStyle: const TextStyle(color: HomiziColors.ink),
            side: const BorderSide(color: HomiziColors.line),
          ),
        ),
        child: scaffold,
      ),
    );
  }
}

const demoSampleListingPhotos = wizardSamplePhotos;
