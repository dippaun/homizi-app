import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_posted_screen.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/roles/role_provider.dart';

/// Eight-section listing wizard. Drafts autosave once the server can store them.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({this.propertyId, this.fresh = false, super.key});

  /// Owned listing to edit. Null resumes the latest draft.
  final String? propertyId;

  /// Start empty instead of resuming a draft.
  final bool fresh;

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
  String? _note;

  @override
  void initState() {
    super.initState();
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
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.fresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(listingDraftProvider.notifier).update(const ListingDraft());
        _ensureDemoPhotos();
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
    super.dispose();
  }

  void _persist() {
    final current = ref.read(listingDraftProvider);
    final broker = ref.read(currentRoleProvider) == HomiziRole.broker;
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
            buildingName: _building.text,
            rentText: _rent.text,
            depositText: _deposit.text,
            maintenanceText: _maintenance.text,
            brokerageText: _brokerage.text,
            addressLine: _address.text,
            landmark: _landmark.text,
            areaText: _area.text,
            floorText: floorApplies(current.buildingKind) ? _floor.text : '',
            totalFloorsText: floorApplies(current.buildingKind)
                ? _totalFloors.text
                : '',
            listedBy: broker ? 'broker' : current.listedBy,
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
      setState(() => _note = issues.first);
      return;
    }
    if (_step == 0) {
      final current = ref.read(listingDraftProvider);
      if (current.city.trim().isEmpty) {
        _set((draft) => draft.copyWith(city: 'Mumbai'));
      }
    }
    if (_step >= 1) {
      final saved = await _autosave();
      if (!mounted || (!saved && !demo)) {
        return;
      }
    }
    setState(() {
      _note = null;
      _step = (_step + 1).clamp(0, listingWizardSteps.length - 1);
    });
  }

  Future<void> _save() async {
    final saved = await _autosave();
    if (!saved || !mounted) {
      return;
    }
    final issues = ref.read(listingDraftProvider).persistBlockers();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
      return;
    }
    if (demoModeOn(ref)) {
      setState(
        () => _note = 'Draft kept on this device. Nothing was published.',
      );
    }
  }

  Future<void> _publish() async {
    if (!ref.read(ownVerificationProvider).isVerified) {
      await guardVerifiedAction(context, ref, action: _publish);
      return;
    }
    final demo = demoModeOn(ref);
    _persist();
    if (demo) {
      _ensureDemoPhotos();
    }
    final draft = ref.read(listingDraftProvider);
    final issues = releaseGaps(draft);
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
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
      if (releaseGaps(result.draft).isEmpty) {
        ref.read(publishedSearchProvider.notifier).remember(result.draft);
      }
      final server = result.publishedByServer;
      if (demo || server) {
        setState(() => _busy = false);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ListingPostedScreen(
              draft: result.draft,
              serverPublished: server,
            ),
          ),
        );
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
    final last = _step == listingWizardSteps.length - 1;
    final gaps = releaseGaps(draft);
    final broker =
        ref.watch(currentRoleProvider) == HomiziRole.broker ||
        draft.listedBy == 'broker';
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: HomiziBackButton(
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
              return;
            }
            HomiziBackButton.leave(context);
          },
        ),
        title: Text(homiziText(context, 'List your property')),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(key: Key('listing-loading')),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(
                          context,
                          '${_step + 1}/${listingWizardSteps.length}',
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_step + 1) / listingWizardSteps.length,
                        color: HomiziColors.accent,
                        backgroundColor: HomiziColors.mist,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        homiziText(context, listingWizardSteps[_step]),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (_step == 0)
                        IntentStep(
                          draft: draft,
                          title: _title,
                          onIntent: (value) => _set(
                            (current) => current.copyWith(listingIntent: value),
                          ),
                        ),
                      if (_step == 1)
                        LocationStep(
                          draft: draft,
                          locality: _locality,
                          building: _building,
                          area: _area,
                          floor: _floor,
                          totalFloors: _totalFloors,
                          address: _address,
                          landmark: _landmark,
                          onCity: (city) =>
                              _refreshNearby(_locality.text, city),
                          onLocality: (value) {
                            _assignIfDifferent(_locality, value);
                            _refreshNearby(value, draft.city);
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
                            (current) => current.copyWith(configuration: value),
                          ),
                          onRentable: (value) => _set((current) {
                            final occupancy = switch (value) {
                              'single' => 1,
                              'double' => 2,
                              _ =>
                                current.occupancy < 1 ? 1 : current.occupancy,
                            };
                            return current.copyWith(
                              rentableArea: value,
                              occupancy: occupancy,
                            );
                          }),
                        ),
                      if (_step == 2)
                        NearbyStep(
                          draft: draft,
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
                      if (_step == 3)
                        LivingStep(
                          draft: draft,
                          age: _age,
                          waterHours: _waterHours,
                          onFurnishing: (value) => _set(
                            (current) => current.copyWith(furnishing: value),
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
                            (current) => current.copyWith(waterSupply: value),
                          ),
                          onAmenity: _toggleAmenity,
                        ),
                      if (_step == 4)
                        RulesStep(
                          draft: draft,
                          onPets: (value) => _set(
                            (current) => current.copyWith(
                              petsChoice: value,
                              petsAllowed: value,
                            ),
                          ),
                          onGuests: (value) => _set(
                            (current) => current.copyWith(guestsAllowed: value),
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
                          onGender: (value) => _set(
                            (current) =>
                                current.copyWith(genderPreference: value),
                          ),
                          onOccupation: (value) => _set(
                            (current) =>
                                current.copyWith(preferredOccupation: value),
                          ),
                        ),
                      if (_step == 5)
                        ServicesStep(
                          draft: draft,
                          flatmates: _flatmates,
                          possession: _possession,
                          highlights: _highlights,
                          onCook: (value) => _set(
                            (current) => current.copyWith(cookService: value),
                          ),
                          onMaid: (value) => _set(
                            (current) => current.copyWith(maidService: value),
                          ),
                          onConsent: (value) => _set(
                            (current) =>
                                current.copyWith(linkFlatmateProfiles: value),
                          ),
                        ),
                      if (_step == 6)
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
                        ),
                      if (_step == 7)
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
                      if (last) ...[
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
                      if (_note != null)
                        Text(
                          homiziText(context, _note!),
                          key: const Key('listing-save-note'),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: Key(
                              last ? 'save-listing' : 'listing-save-anytime',
                            ),
                            onPressed: _busy ? null : () => unawaited(_save()),
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
  }
}

const demoSampleListingPhotos = wizardSamplePhotos;
