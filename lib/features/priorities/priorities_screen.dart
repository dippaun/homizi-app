import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/priorities/host_priority_providers.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/priorities/priority_widgets.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/seeker_board.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

bool prioritiesAreHost(HomiziRole? role) {
  return role == HomiziRole.host || role == HomiziRole.broker;
}

/// Set Your Priorities. Tenants and flatmates rank what they need in a
/// home; hosts rank their preferred tenant profile. Saved priorities feed
/// the shared scorers, so every card and the screen it opens agree.
class PrioritiesScreen extends ConsumerWidget {
  const PrioritiesScreen({
    this.side,
    this.focus,
    this.editing = false,
    super.key,
  });

  /// `host` or `tenant`. Null follows the current role.
  final String? side;

  /// Priority field to open, such as `location` or `budget`.
  final String? focus;

  /// True when the person tapped Edit. A saved list stays a summary.
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = switch (side) {
      'host' => true,
      'tenant' => false,
      _ => prioritiesAreHost(ref.watch(currentRoleProvider)),
    };
    final state = ref.watch(priorityStateProvider);
    return RepaintBoundary(
      key: const Key('priority-shot'),
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          leading: HomiziBackButton(
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go(RoutePaths.home);
              }
            },
          ),
          title: Text(homiziText(context, 'Set My Priorities')),
        ),
        body: PageBackground(
          variant: pageVariantFor('priorities'),
          child: switch (state.phase) {
            PriorityPhase.loading => const LoadingState(
              message: 'Loading your priorities',
            ),
            PriorityPhase.empty => EmptyState(
              title: 'No priorities yet',
              message: 'The starting order is ready when you want it.',
              actionLabel: 'Use the starting order',
              onAction: () => ref
                  .read(priorityStateProvider.notifier)
                  .useStartingOrder(host: host),
            ),
            PriorityPhase.error => _PriorityError(
              message: state.message,
              onRetry: () =>
                  ref.read(priorityStateProvider.notifier).save(host: host),
            ),
            PriorityPhase.ready => _PriorityGate(
              host: host,
              focus: focus,
              editing: editing,
            ),
          },
        ),
      ),
    );
  }
}

class _SavedChangePrompt extends StatelessWidget {
  const _SavedChangePrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        homiziText(context, 'Priorities saved. Want to change them?'),
        key: const Key('priority-saved-prompt'),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CityQuestion extends StatefulWidget {
  const _CityQuestion({required this.city, required this.onCity});

  final String city;
  final ValueChanged<String> onCity;

  @override
  State<_CityQuestion> createState() => _CityQuestionState();
}

class _CityQuestionState extends State<_CityQuestion> {
  late final TextEditingController _city = TextEditingController(
    text: widget.city,
  );

  @override
  void didUpdateWidget(covariant _CityQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city && _city.text != widget.city) {
      _city.text = widget.city;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = cityCentreFor(widget.city);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'City'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              'Ahmedabad is selected. Change it, then pick localities inside that city.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 8),
          PlaceAutocompleteField(
            controller: _city,
            fieldKey: const Key('priority-city'),
            labelText: 'City',
            hintText: 'Search a city',
            stackedLabel: true,
            pickOnly: true,
            includedPrimaryTypes: const ['locality'],
            nearbyLocalities: catalogCitySuggestions(),
            biasPoint: point,
            prefixIcon: const Icon(
              Icons.location_city_outlined,
              color: HomiziColors.logoOrange,
            ),
            onSelected: (place) {
              final name = pickedCityName(place);
              if (name.isEmpty) {
                return;
              }
              widget.onCity(name);
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.roleLine});

  final String title;
  final String roleLine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const HomiziMark(size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, title),
                  key: const Key('priority-title'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                Text(
                  homiziText(context, roleLine),
                  key: const Key('priority-role'),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontWeight: FontWeight.w600,
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

class _DragHint extends StatelessWidget {
  const _DragHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('priority-drag-hint'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, color: HomiziColors.logoOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(
                context,
                'Drag and drop ≡ to set the priority order (P1 = highest). Tap a row to change it, tap the chip to make it a must-have.',
              ),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _tenantSteps = <(IconData, String)>[
  (Icons.assignment_outlined, 'Create Your Profile'),
  (Icons.swap_vert, 'Set & rank your priorities (must have & flexible)'),
  (Icons.groups_outlined, 'Get personalised matches'),
  (Icons.home_outlined, 'Explore properties or roomies'),
  (Icons.event_available_outlined, 'Shortlist, connect & move in'),
];

const _hostSteps = <(IconData, String)>[
  (Icons.home_outlined, 'Post your property'),
  (Icons.low_priority, 'Set your priorities'),
  (Icons.groups_outlined, 'Get top match profiles'),
  (Icons.event_available_outlined, 'Shortlist, connect & rent'),
];

/// Loads the device copy, then Supabase, before any priority form is built.
class _PriorityGate extends ConsumerStatefulWidget {
  const _PriorityGate({required this.host, required this.editing, this.focus});

  final bool host;
  final bool editing;
  final String? focus;

  @override
  ConsumerState<_PriorityGate> createState() => _PriorityGateState();
}

class _PriorityGateState extends ConsumerState<_PriorityGate> {
  var _ready = false;
  var _editing = false;
  SearchPriorities? _tenant;
  HostTenantPriorities? _hostSaved;

  @override
  void initState() {
    super.initState();
    final focus = widget.focus;
    _editing = widget.editing || (focus != null && focus.isNotEmpty);
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = ref.read(priorityRepositoryProvider);
    final tenant = widget.host ? null : await repo.readTenant();
    final host = widget.host ? await repo.readHost() : null;
    if (!mounted) {
      return;
    }
    setState(() {
      _tenant = tenant;
      _hostSaved = host;
      _ready = true;
    });
  }

  List<SavedField> _fields() {
    final tenant = _tenant;
    if (!widget.host && tenant != null) {
      return [
        for (final criterion in tenant.activeOrdered)
          SavedField(
            label: criterionTitle(criterion),
            icon: savedFieldIcon(criterionTitle(criterion)),
            value: criterionValue(tenant, criterion),
            onAdd: () => setState(() => _editing = true),
          ),
      ];
    }
    final host = _hostSaved;
    if (host == null) {
      return const [];
    }
    return [
      if (host.propertyLabel.trim().isNotEmpty)
        SavedField(
          label: 'Property',
          icon: Icons.home_outlined,
          value: host.propertyLabel,
        ),
      SavedField(
        label: 'Preferred gender',
        icon: Icons.wc_outlined,
        value: host.gender,
        onAdd: () => setState(() => _editing = true),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    reloadWhenUserChanges(ref, () {
      setState(() => _ready = false);
      unawaited(_load());
    });
    if (!_ready) {
      return const PrefsSkeleton();
    }
    final saved = widget.host
        ? (_hostSaved?.saved ?? false)
        : (_tenant?.saved ?? false);
    if (saved && !_editing) {
      return SavedSummaryCard(
        title: 'Preferences saved',
        fill: true,
        fields: _fields(),
        onEdit: () => setState(() => _editing = true),
      );
    }
    return widget.host
        ? const _HostPriorities()
        : _TenantPriorities(focus: widget.focus);
  }
}

// ---------------------------------------------------------------------------
// Tenant / flatmate
// ---------------------------------------------------------------------------

class _TenantPriorities extends ConsumerStatefulWidget {
  const _TenantPriorities({this.focus});

  final String? focus;

  @override
  ConsumerState<_TenantPriorities> createState() => _TenantPrioritiesState();
}

class _TenantPrioritiesState extends ConsumerState<_TenantPriorities> {
  SearchPriorities? _draft;
  var _edited = false;
  var _tab = 0;
  var _busy = false;
  var _openedFocus = false;
  String? _lifeFocus;

  void _openFocus(SearchPriorities draft) {
    final raw = widget.focus;
    if (_openedFocus || raw == null || raw.isEmpty) {
      return;
    }
    const habits = {
      'smoking',
      'food',
      'pets',
      'schedule',
      'work',
      'tidy',
      'drinking',
      'lifestyle',
    };
    final criterion = criterionForFocus(raw);
    if (criterion == null && !habits.contains(raw)) {
      return;
    }
    _openedFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (habits.contains(raw) || criterion == PriorityCriterion.lifestyle) {
        setState(() {
          _tab = 1;
          _lifeFocus = raw == 'lifestyle' ? 'smoking' : raw;
        });
        return;
      }
      unawaited(_edit(draft, criterion!));
    });
  }

  void _update(SearchPriorities next) {
    setState(() {
      _draft = next;
      _edited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchPrioritiesProvider, (previous, next) {
      if (next.saved && !_edited) {
        setState(() => _draft = next);
      }
    });
    final saved = ref.watch(searchPrioritiesProvider);
    final search = ref.watch(savedPropertySearchProvider).asData?.value;
    if (_draft == null) {
      final seeded = saved.saved
          ? saved
          : seedTenantPriorities(
              requirement: ref.read(activeRequirementProvider),
              search: search,
            );
      _draft = seeded.city.trim().isEmpty
          ? seeded.copyWith(city: 'Ahmedabad')
          : seeded;
    }
    final draft = _draft!;
    _openFocus(draft);
    final ranked = draft.activeOrdered;
    final hidden = [
      for (final c in draft.ordered)
        if (!draft.isActive(c)) c,
    ];
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(
          title: 'Set your priorities',
          roleLine: 'Tenant / Flatmate',
        ),
        _CityQuestion(
          city: draft.city.trim().isEmpty ? 'Ahmedabad' : draft.city,
          onCity: (city) {
            final same = samePlaceName(city, draft.city);
            _update(
              draft.copyWith(
                city: city,
                locations: same ? draft.locations : const [],
              ),
            );
          },
        ),
        if (saved.saved) const _SavedChangePrompt(),
        PriorityTabs(
          index: _tab,
          labels: const [
            ('Priorities & preferences', Icons.gps_fixed, 'priority-tab-ranks'),
            (
              'Lifestyle & habits',
              Icons.eco_outlined,
              'priority-tab-lifestyle',
            ),
          ],
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 12),
        if (search != null && searchDiffers(draft, search))
          _SearchBanner(onUse: () => _update(applySearch(draft, search))),
        if (_tab == 0) const _DragHint(),
      ],
    );
    return Column(
      children: [
        Expanded(
          child: _tab == 0
              ? ReorderableListView(
                  key: const Key('priority-list-tenant'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  buildDefaultDragHandles: false,
                  header: header,
                  onReorderItem: (oldIndex, newIndex) =>
                      _update(reorderActive(draft, oldIndex, newIndex)),
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hidden.isNotEmpty)
                        OutlinedButton.icon(
                          key: const Key('priority-add-more'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HomiziColors.brandDeepRed,
                            side: const BorderSide(
                              color: HomiziColors.brandRedOrange,
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () => unawaited(_addMore(draft, hidden)),
                          icon: const Icon(Icons.add),
                          label: Text(
                            homiziText(context, 'Add more preferences'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const PriorityTypeExplainer(),
                      const SizedBox(height: 16),
                      const PriorityHowItWorks(steps: _tenantSteps),
                    ],
                  ),
                  children: [
                    for (var i = 0; i < ranked.length; i++)
                      PriorityRankRow(
                        key: ValueKey(ranked[i]),
                        wire: criterionWire(ranked[i]),
                        index: i,
                        icon: _tenantIcon(ranked[i]),
                        title: criterionTitle(ranked[i]),
                        value: criterionValue(draft, ranked[i]),
                        mustHave: draft.isMustHave(ranked[i]),
                        onToggleType: () =>
                            _update(toggleMustHave(draft, ranked[i])),
                        onEdit: () => unawaited(_edit(draft, ranked[i])),
                      ),
                  ],
                )
              : ListView(
                  key: const Key('priority-lifestyle-tab'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: [
                    header,
                    _LifestyleForm(
                      value: draft,
                      focus: _lifeFocus,
                      onChanged: _update,
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ShGradientButton(
            buttonKey: const Key('priority-save'),
            label: 'Save My Priorities',
            busy: _busy,
            onPressed: () => unawaited(_save(draft)),
          ),
        ),
      ],
    );
  }

  Future<void> _save(SearchPriorities draft) async {
    setState(() => _busy = true);
    final next = draft.copyWith(saved: true);
    // The shared listing scorer (#75) reads this right away.
    ref.read(searchPrioritiesProvider.notifier).replace(next);
    unawaited(
      ref
          .read(priorityStateProvider.notifier)
          .saveOrder(host: false, order: legacyTenantOrder(next)),
    );
    // The device copy and account sync finish in the background; the
    // summary's "where" line updates when they do.
    final syncs = ref.read(prioritySyncProvider.notifier)..set(null);
    unawaited(
      ref.read(priorityRepositoryProvider).saveTenant(next).then(syncs.set),
    );
    _mirrorHabits(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _edited = false;
    });
    unawaited(context.push(RoutePaths.prioritiesSaved));
  }

  void _mirrorHabits(SearchPriorities p) {
    final ask = ref.read(finderProvider).ask;
    int? tidy;
    switch (p.tidy) {
      case 'relaxed':
        tidy = 2;
      case 'average':
        tidy = 3;
      case 'tidy':
        tidy = 5;
    }
    ref
        .read(finderProvider.notifier)
        .saveAsk(
          ask.copyWith(
            smoking: switch (p.smoking) {
              'no' => 'never',
              'yes' => 'regularly',
              'occasional' => 'sometimes',
              _ => '',
            },
            drinking: switch (p.drinking) {
              'no' => 'no',
              'yes' => 'yes',
              _ => '',
            },
            food: switch (p.food) {
              'vegetarian' => 'veg',
              'non_vegetarian' => 'non_veg',
              'both' => 'any',
              _ => '',
            },
            pets: switch (p.pets) {
              'avoid' => 'none',
              'required' => 'has',
              'ok' => 'ok',
              _ => '',
            },
            sleep: switch (p.schedule) {
              'early' || 'flexible' || 'night' => p.schedule,
              _ => '',
            },
            schedule: switch (p.workStyle) {
              'office' || 'hybrid' || 'home' => p.workStyle,
              _ => '',
            },
            guests: switch (p.guests) {
              'rarely' => 'rare',
              'occasionally' => 'sometimes',
              'frequently' => 'often',
              _ => ask.guests,
            },
            cleanliness: tidy ?? ask.cleanliness,
          ),
        );
  }

  Future<void> _addMore(
    SearchPriorities draft,
    List<PriorityCriterion> hidden,
  ) async {
    final picked = await showModalBottomSheet<PriorityCriterion>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('priority-add-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              homiziText(context, 'Add a preference'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final c in hidden)
              ListTile(
                key: Key('priority-add-${criterionWire(c)}'),
                leading: Icon(_tenantIcon(c), color: HomiziColors.logoOrange),
                title: Text(homiziText(context, criterionTitle(c))),
                subtitle: Text(homiziText(context, criterionValue(draft, c))),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      _update(addCriterion(draft, picked));
    }
  }

  Future<void> _edit(SearchPriorities draft, PriorityCriterion c) async {
    if (c == PriorityCriterion.lifestyle) {
      setState(() => _tab = 1);
      return;
    }
    final next = await showModalBottomSheet<SearchPriorities>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => _TenantEditSheet(
        value: draft,
        criterion: c,
        canRemove: draft.activeOrdered.length > 3,
      ),
    );
    if (next != null && mounted) {
      _update(next);
    }
  }
}

IconData _tenantIcon(PriorityCriterion c) => switch (c) {
  PriorityCriterion.budget => Icons.currency_rupee,
  PriorityCriterion.location => Icons.location_on_outlined,
  PriorityCriterion.occupancy => Icons.bed_outlined,
  PriorityCriterion.propertyType => Icons.home_outlined,
  PriorityCriterion.moveIn => Icons.calendar_month_outlined,
  PriorityCriterion.gender => Icons.wc_outlined,
  PriorityCriterion.lifestyle => Icons.spa_outlined,
  PriorityCriterion.furnishing => Icons.chair_outlined,
};

class _SearchBanner extends StatelessWidget {
  const _SearchBanner({required this.onUse});

  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('priority-search-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: HomiziColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(
                context,
                'Your last search asked for a different budget or place.',
              ),
              style: const TextStyle(color: HomiziColors.ink, fontSize: 13),
            ),
          ),
          TextButton(
            key: const Key('priority-use-search'),
            onPressed: onUse,
            child: Text(homiziText(context, 'Use it')),
          ),
        ],
      ),
    );
  }
}

class _TenantEditSheet extends StatefulWidget {
  const _TenantEditSheet({
    required this.value,
    required this.criterion,
    required this.canRemove,
  });

  final SearchPriorities value;
  final PriorityCriterion criterion;
  final bool canRemove;

  @override
  State<_TenantEditSheet> createState() => _TenantEditSheetState();
}

class _TenantEditSheetState extends State<_TenantEditSheet> {
  late SearchPriorities _value = widget.value;
  late final _min = TextEditingController(text: '${widget.value.budgetMinInr}');
  late final _max = TextEditingController(text: '${widget.value.budgetMaxInr}');
  String? _problem;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _done() {
    var next = _value;
    if (widget.criterion == PriorityCriterion.budget) {
      final low = int.tryParse(_min.text.trim());
      final high = int.tryParse(_max.text.trim());
      if (low == null || high == null || low < 1000 || high < low) {
        setState(
          () => _problem =
              'Enter a monthly budget from ₹1,000, with the top at least the bottom.',
        );
        return;
      }
      next = next.copyWith(budgetMinInr: low, budgetMaxInr: high);
    }
    if (widget.criterion == PriorityCriterion.location) {
      final city = _value.city.trim().isEmpty ? 'Ahmedabad' : _value.city;
      next = _value.copyWith(city: city);
    }
    if (widget.criterion == PriorityCriterion.propertyType &&
        next.propertyTypes.isEmpty) {
      setState(() => _problem = 'Pick at least one property type.');
      return;
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criterion;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('priority-edit-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homiziText(context, criterionTitle(c)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._fields(c),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, _problem!),
                  key: const Key('priority-edit-problem'),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 16),
              ShGradientButton(
                buttonKey: const Key('priority-edit-done'),
                label: 'Done',
                onPressed: _done,
              ),
              if (widget.canRemove)
                TextButton(
                  key: const Key('priority-remove'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(removeCriterion(widget.value, c)),
                  child: Text(
                    homiziText(context, 'Remove from my priorities'),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(PriorityCriterion c) {
    Widget radios(
      String current,
      Map<String, String> options,
      void Function(String) set,
    ) {
      return OptionGrid(
        children: [
          for (final entry in options.entries)
            OptionTile(
              key: Key('priority-option-${entry.key}'),
              label: homiziText(context, entry.value),
              icon: iconForChoice(entry.value),
              selected: current == entry.key,
              onTap: () => setState(() => set(entry.key)),
            ),
        ],
      );
    }

    return switch (c) {
      PriorityCriterion.budget => [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('priority-budget-min'),
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'From (₹ / month)',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('priority-budget-max'),
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'To (₹ / month)'),
              ),
            ),
          ],
        ),
      ],
      PriorityCriterion.location => [
        CityLocalityField(
          localitiesOnly: true,
          localityKey: const Key('priority-places'),
          addKey: const Key('priority-add-locality'),
          city: _value.city.trim().isEmpty ? 'Ahmedabad' : _value.city,
          localities: [
            for (final name in _value.locations) PickedPlace(label: name),
          ],
          onChanged: (selection) => setState(() {
            _value = _value.copyWith(
              city: selection.city.trim().isEmpty
                  ? 'Ahmedabad'
                  : selection.city,
              locations: [
                for (final place in selection.localities) place.label,
              ],
            );
            _problem = null;
          }),
        ),
      ],
      PriorityCriterion.occupancy => [
        radios(_value.occupancy, const {
          'single': 'Single occupancy',
          'shared': 'Shared occupancy',
          'any': 'Either works',
        }, (v) => _value = _value.copyWith(occupancy: v)),
      ],
      PriorityCriterion.gender => [
        radios(_value.gender, const {
          'any': 'Any',
          'women': 'Women',
          'men': 'Men',
          'same': 'Same as me',
        }, (v) => _value = _value.copyWith(gender: v)),
      ],
      PriorityCriterion.furnishing => [
        radios(_value.furnishing, const {
          'furnished': 'Furnished',
          'semi_furnished': 'Semi-furnished',
          'unfurnished': 'Unfurnished',
        }, (v) => _value = _value.copyWith(furnishing: v)),
      ],
      PriorityCriterion.propertyType => [
        Wrap(
          spacing: 8,
          children: [
            for (final type in const ['flat', 'pg', 'shared_room'])
              IconChoiceChip(
                key: Key('priority-type-option-$type'),
                label: Text(homiziText(context, propertyTypeLabel(type))),
                selected: _value.propertyTypes.contains(type),
                onSelected: (on) => setState(() {
                  final next = [..._value.propertyTypes];
                  on ? next.add(type) : next.remove(type);
                  _value = _value.copyWith(propertyTypes: next);
                }),
              ),
          ],
        ),
      ],
      PriorityCriterion.moveIn => [
        ListTile(
          key: const Key('priority-move-in'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.calendar_month_outlined,
            color: HomiziColors.logoOrange,
          ),
          title: Text(homiziText(context, 'Move in from')),
          subtitle: Text(dayLabel(_value.moveIn)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final now = DateTime.now();
            final first = DateTime(now.year, now.month, now.day);
            final current = _value.moveIn.isBefore(first)
                ? first
                : _value.moveIn;
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(current.year, current.month, current.day),
              firstDate: first,
              lastDate: first.add(const Duration(days: 365)),
            );
            if (picked != null && mounted) {
              setState(
                () => _value = _value.copyWith(
                  moveInYear: picked.year,
                  moveInMonth: picked.month,
                  moveInDay: picked.day,
                ),
              );
            }
          },
        ),
      ],
      PriorityCriterion.lifestyle => const [],
    };
  }
}

class _LifestyleForm extends StatefulWidget {
  const _LifestyleForm({
    required this.value,
    required this.onChanged,
    this.focus,
  });

  final SearchPriorities value;
  final ValueChanged<SearchPriorities> onChanged;
  final String? focus;

  @override
  State<_LifestyleForm> createState() => _LifestyleFormState();
}

class _LifestyleFormState extends State<_LifestyleForm> {
  final _anchors = <String, GlobalKey>{
    for (final id in const [
      'smoking',
      'food',
      'pets',
      'schedule',
      'work',
      'tidy',
      'drinking',
    ])
      id: GlobalKey(),
  };
  String? _shown;

  @override
  void initState() {
    super.initState();
    _reveal(widget.focus);
  }

  @override
  void didUpdateWidget(_LifestyleForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) {
      _reveal(widget.focus);
    }
  }

  void _reveal(String? focus) {
    final id = focus ?? '';
    if (id.isEmpty || id == _shown || _anchors[id] == null) {
      return;
    }
    _shown = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _anchors[id]?.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        alignment: 0.2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    Widget pick(
      String key,
      String label,
      String current,
      Map<String, String> options,
      SearchPriorities Function(String) apply,
    ) {
      return KeyedSubtree(
        key: _anchors[key],
        child: KitChoiceField<String>(
          key: Key('life-$key'),
          label: label,
          icon: iconForChoice(label),
          dense: true,
          selected: options.containsKey(current) ? current : null,
          options: [
            for (final entry in options.entries)
              KitOption(
                value: entry.key,
                label: entry.value,
                icon: iconForChoice(entry.value),
              ),
          ],
          onChanged: (next) => widget.onChanged(apply(next)),
        ),
      );
    }

    const yesNo = {
      'no': 'No',
      'yes': 'Yes',
      'undisclosed': 'Prefer not to say',
    };
    return ShSection(
      key: const Key('priority-lifestyle'),
      title: 'Lifestyle & habits',
      icon: Icons.eco_outlined,
      child: Column(
        children: [
          pick(
            'smoking',
            'Do you smoke?',
            value.smoking,
            yesNo,
            (v) => value.copyWith(smoking: v),
          ),
          pick('food', 'Food', value.food, const {
            'vegetarian': 'Vegetarian',
            'non_vegetarian': 'Non-vegetarian',
            'both': 'Both',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(food: v)),
          pick('pets', 'Pets', value.pets, const {
            'avoid': 'No pets',
            'ok': 'Pets are fine',
            'required': 'I have pets',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(pets: v)),
          pick('schedule', 'Sleep schedule', value.schedule, const {
            'early': 'Early',
            'flexible': 'Flexible',
            'night': 'Night',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(schedule: v)),
          pick('work', 'Work style', value.workStyle, const {
            'office': 'Office',
            'hybrid': 'Hybrid',
            'home': 'Work from home',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(workStyle: v)),
          pick('tidy', 'How tidy are you?', value.tidy, const {
            'relaxed': 'Relaxed',
            'average': 'Average',
            'tidy': 'Tidy',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(tidy: v)),
          pick(
            'drinking',
            'Do you drink?',
            value.drinking,
            yesNo,
            (v) => value.copyWith(drinking: v),
          ),
          pick('guests', 'Guests', value.guests, const {
            'rarely': 'Rarely',
            'occasionally': 'Occasionally',
            'frequently': 'Frequently',
          }, (v) => value.copyWith(guests: v)),
          pick('cooking', 'Cooking', value.cooking, const {
            'cook_myself': 'I cook myself',
            'shared': 'Shared cooking',
            'prefer_not': 'Prefer not to cook',
          }, (v) => value.copyWith(cooking: v)),
          Text(
            homiziText(
              context,
              'These answers are compared with the home\'s rules and with a roommate\'s habits. Prefer not to say leaves that icon unset.',
            ),
            style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Host / owner / broker: preferred tenant profile
// ---------------------------------------------------------------------------

class _HostPriorities extends ConsumerStatefulWidget {
  const _HostPriorities();

  @override
  ConsumerState<_HostPriorities> createState() => _HostPrioritiesState();
}

class _HostPrioritiesState extends ConsumerState<_HostPriorities> {
  HostTenantPriorities? _draft;
  var _edited = false;
  var _busy = false;

  void _update(HostTenantPriorities next) {
    setState(() {
      _draft = next;
      _edited = true;
    });
  }

  HostTenantPriorities _forProperty(
    HostTenantPriorities base,
    HostProperty property,
  ) {
    return base.forProperty(
      id: property.id,
      label: property.label,
      rentInr: property.rentInr,
      availableFrom: property.availableFrom,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(hostTenantPrioritiesProvider, (previous, next) {
      if (next.saved && !_edited) {
        setState(() => _draft = next);
      }
    });
    final saved = ref.watch(hostTenantPrioritiesProvider);
    final properties = ref.watch(hostPropertiesProvider);
    HostProperty? property;
    for (final item in properties) {
      if (item.id == (_draft ?? saved).propertyId) {
        property = item;
      }
    }
    if (property == null && properties.isNotEmpty) {
      // The user's own home first, then the one Interested Seekers opens.
      final preferred = preferredPropertyId(properties);
      property = properties.firstWhere(
        (item) => !isSampleHostHome(item),
        orElse: () => properties.firstWhere(
          (item) => item.id == preferred,
          orElse: () => properties.first,
        ),
      );
    }
    var draft = _draft ?? saved;
    if (property != null && draft.propertyId != property.id) {
      draft = _forProperty(draft, property);
    }
    _draft = draft;
    final ranked = draft.activeOrdered;
    final hidden = [
      for (final c in draft.order)
        if (!draft.active.contains(c)) c,
    ];
    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            key: const Key('priority-list-host'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            buildDefaultDragHandles: false,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(
                  title: 'Set your priorities',
                  roleLine: 'Preferred tenant profile',
                ),
                if (saved.saved) const _SavedChangePrompt(),
                if (property != null)
                  _PropertyPicker(
                    properties: properties,
                    selected: property,
                    onPick: (next) => _update(_forProperty(draft, next)),
                  ),
                const SizedBox(height: 12),
                const _DragHint(),
              ],
            ),
            onReorderItem: (oldIndex, newIndex) =>
                _update(draft.reorder(oldIndex, newIndex)),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hidden.isNotEmpty)
                  OutlinedButton.icon(
                    key: const Key('priority-add-more'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomiziColors.brandDeepRed,
                      side: const BorderSide(
                        color: HomiziColors.brandRedOrange,
                      ),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => unawaited(_addMore(draft, hidden)),
                    icon: const Icon(Icons.add),
                    label: Text(homiziText(context, 'Add more preferences')),
                  ),
                const SizedBox(height: 16),
                const PriorityTypeExplainer(),
                const SizedBox(height: 16),
                const PriorityHowItWorks(steps: _hostSteps),
              ],
            ),
            children: [
              for (var i = 0; i < ranked.length; i++)
                PriorityRankRow(
                  key: ValueKey(ranked[i]),
                  wire: hostCriterionWire(ranked[i]),
                  index: i,
                  icon: _hostIcon(ranked[i]),
                  title: hostCriterionTitle(ranked[i]),
                  value: draft.valueLine(ranked[i]),
                  note: hostCriterionHint(ranked[i]),
                  mustHave: draft.isMustHave(ranked[i]),
                  onToggleType: () => _update(draft.toggleMustHave(ranked[i])),
                  onEdit: () => unawaited(_edit(draft, ranked[i])),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ShGradientButton(
            buttonKey: const Key('priority-save'),
            label: 'Save Priorities',
            busy: _busy,
            onPressed: () => unawaited(_save(draft)),
          ),
        ),
      ],
    );
  }

  Future<void> _save(HostTenantPriorities draft) async {
    setState(() => _busy = true);
    final notifier = ref.read(hostTenantPrioritiesProvider.notifier);
    final syncs = ref.read(prioritySyncProvider.notifier)..set(null);
    unawaited(notifier.save(draft).then(syncs.set));
    unawaited(
      ref
          .read(priorityStateProvider.notifier)
          .saveOrder(host: true, order: draft.legacyOrder),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _edited = false;
    });
    unawaited(context.push('${RoutePaths.prioritiesSaved}?side=host'));
  }

  Future<void> _addMore(
    HostTenantPriorities draft,
    List<HostCriterion> hidden,
  ) async {
    final picked = await showModalBottomSheet<HostCriterion>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('priority-add-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              homiziText(context, 'Add a preference'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final c in hidden)
              ListTile(
                key: Key('priority-add-${hostCriterionWire(c)}'),
                leading: Icon(_hostIcon(c), color: HomiziColors.logoOrange),
                title: Text(homiziText(context, hostCriterionTitle(c))),
                subtitle: Text(homiziText(context, hostCriterionHint(c))),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      _update(draft.add(picked));
    }
  }

  Future<void> _edit(HostTenantPriorities draft, HostCriterion c) async {
    final next = await showModalBottomSheet<HostTenantPriorities>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => _HostEditSheet(
        value: draft,
        criterion: c,
        canRemove: draft.activeOrdered.length > 3,
      ),
    );
    if (next != null && mounted) {
      _update(next);
    }
  }
}

IconData _hostIcon(HostCriterion c) => switch (c) {
  HostCriterion.budget => Icons.currency_rupee,
  HostCriterion.moveIn => Icons.calendar_month_outlined,
  HostCriterion.workingProfessional => Icons.work_outline,
  HostCriterion.vegetarian => Icons.eco_outlined,
  HostCriterion.genderAge => Icons.person_outline,
  HostCriterion.nonSmoker => Icons.smoke_free,
  HostCriterion.nonDrinker => Icons.no_drinks_outlined,
  HostCriterion.longStay => Icons.event_repeat_outlined,
};

class _PropertyPicker extends StatelessWidget {
  const _PropertyPicker({
    required this.properties,
    required this.selected,
    required this.onPick,
  });

  final List<HostProperty> properties;
  final HostProperty selected;
  final ValueChanged<HostProperty> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitChoiceField<String>(
          key: const Key('priority-host-property'),
          label: 'For your property',
          icon: RealLifeIcons.house,
          dense: true,
          selected: selected.id,
          options: [
            for (final item in properties)
              KitOption(
                value: item.id,
                label: '${item.label} · ${item.locality}',
                icon: RealLifeIcons.house,
              ),
          ],
          onChanged: (id) {
            for (final item in properties) {
              if (item.id == id) {
                onPick(item);
              }
            }
          },
        ),
        if (isSampleHostHome(selected))
          Text(
            homiziText(
              context,
              'Sample home until you post one. Values use its rent.',
            ),
            style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}

class _HostEditSheet extends StatefulWidget {
  const _HostEditSheet({
    required this.value,
    required this.criterion,
    required this.canRemove,
  });

  final HostTenantPriorities value;
  final HostCriterion criterion;
  final bool canRemove;

  @override
  State<_HostEditSheet> createState() => _HostEditSheetState();
}

class _HostEditSheetState extends State<_HostEditSheet> {
  late HostTenantPriorities _value = widget.value;
  late final _min = TextEditingController(
    text: widget.value.budgetMinInr > 0 ? '${widget.value.budgetMinInr}' : '',
  );
  late final _max = TextEditingController(
    text: widget.value.budgetMaxInr > 0 ? '${widget.value.budgetMaxInr}' : '',
  );
  String? _problem;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _done() {
    var next = _value;
    if (widget.criterion == HostCriterion.budget) {
      final low = int.tryParse(_min.text.trim());
      final high = int.tryParse(_max.text.trim());
      if (low == null || high == null || low < 1000 || high < low) {
        setState(
          () => _problem =
              'Enter a monthly range from ₹1,000, with the top at least the bottom.',
        );
        return;
      }
      next = next.copyWith(budgetMinInr: low, budgetMaxInr: high);
    }
    if (widget.criterion == HostCriterion.genderAge &&
        (next.ageMin < 18 || next.ageMax < next.ageMin)) {
      setState(() => _problem = 'Pick an age range from 18.');
      return;
    }
    Navigator.of(context).pop(next);
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final current = (from ? _value.moveInFrom : _value.moveInTo) ?? first;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (from) {
        final to = _value.moveInTo;
        _value = _value.copyWith(
          moveInFrom: picked,
          moveInTo: to == null || to.isBefore(picked)
              ? picked.add(const Duration(days: 30))
              : to,
        );
      } else {
        final start = _value.moveInFrom ?? first;
        _value = _value.copyWith(
          moveInTo: picked.isBefore(start) ? start : picked,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criterion;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('priority-edit-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homiziText(context, hostCriterionTitle(c)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                homiziText(context, hostCriterionHint(c)),
                style: const TextStyle(color: HomiziColors.muted),
              ),
              const SizedBox(height: 12),
              ...switch (c) {
                HostCriterion.budget => [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('priority-budget-min'),
                          controller: _min,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'From (₹ / month)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('priority-budget-max'),
                          controller: _max,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'To (₹ / month)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                HostCriterion.moveIn => [
                  ListTile(
                    key: const Key('priority-move-from'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(homiziText(context, 'Earliest move-in')),
                    subtitle: Text(
                      _value.moveInFrom == null
                          ? homiziText(context, 'Not set')
                          : dayLabel(_value.moveInFrom!),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () => unawaited(_pickDate(from: true)),
                  ),
                  ListTile(
                    key: const Key('priority-move-to'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(homiziText(context, 'Latest move-in')),
                    subtitle: Text(
                      _value.moveInTo == null
                          ? homiziText(context, 'Not set')
                          : dayLabel(_value.moveInTo!),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () => unawaited(_pickDate(from: false)),
                  ),
                ],
                HostCriterion.genderAge => [
                  KitChoiceField<String>(
                    label: 'Gender',
                    icon: RealLifeIcons.inclusive,
                    selected: _value.gender,
                    options: const [
                      KitOption(
                        value: 'any',
                        label: 'Any gender',
                        icon: RealLifeIcons.inclusive,
                        key: Key('priority-option-any'),
                      ),
                      KitOption(
                        value: 'male',
                        label: 'Male',
                        icon: RealLifeIcons.man,
                        key: Key('priority-option-male'),
                      ),
                      KitOption(
                        value: 'female',
                        label: 'Female',
                        icon: RealLifeIcons.woman,
                        key: Key('priority-option-female'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _value = _value.copyWith(gender: value)),
                  ),
                  Text(
                    '${homiziText(context, 'Age')}: ${_value.ageMin}–${_value.ageMax}',
                    key: const Key('priority-age-label'),
                  ),
                  RangeSlider(
                    key: const Key('priority-age'),
                    values: RangeValues(
                      _value.ageMin.toDouble(),
                      _value.ageMax.toDouble(),
                    ),
                    min: 18,
                    max: 60,
                    divisions: 42,
                    activeColor: HomiziColors.logoOrange,
                    onChanged: (range) => setState(
                      () => _value = _value.copyWith(
                        ageMin: range.start.round(),
                        ageMax: range.end.round(),
                      ),
                    ),
                  ),
                ],
                _ => [
                  Text(
                    homiziText(
                      context,
                      'Seekers whose public brief shows this score higher. Make it a must-have to keep others out of Top matches.',
                    ),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                ],
              },
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, _problem!),
                  key: const Key('priority-edit-problem'),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 16),
              ShGradientButton(
                buttonKey: const Key('priority-edit-done'),
                label: 'Done',
                onPressed: _done,
              ),
              if (widget.canRemove)
                TextButton(
                  key: const Key('priority-remove'),
                  onPressed: () =>
                      Navigator.of(context).pop(widget.value.remove(c)),
                  child: Text(
                    homiziText(context, 'Remove from my priorities'),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityError extends StatelessWidget {
  const _PriorityError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('priority-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: HomiziColors.logoOrange,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'Could not sync priorities'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                message.isEmpty
                    ? 'The ranking is saved on this device.'
                    : message,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('priority-retry'),
              onPressed: onRetry,
              child: Text(homiziText(context, 'Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
