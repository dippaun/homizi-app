import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/priorities/host_priority_providers.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/priorities/priority_widgets.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/seeker_board.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

bool prioritiesAreHost(HomiziRole? role) {
  return role == HomiziRole.host || role == HomiziRole.broker;
}

/// Set Your Priorities. Tenants and flatmates rank what they need in a
/// home; hosts rank their preferred tenant profile. Saved priorities feed
/// the shared scorers, so every card and the screen it opens agree.
class PrioritiesScreen extends ConsumerWidget {
  const PrioritiesScreen({this.side, super.key});

  /// `host` or `tenant`. Null follows the current role.
  final String? side;

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
                router.go(host ? RoutePaths.hostOptions : RoutePaths.home);
              }
            },
          ),
          title: Text(homiziText(context, 'Set My Priorities')),
        ),
        body: switch (state.phase) {
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
          PriorityPhase.ready =>
            host ? const _HostPriorities() : const _TenantPriorities(),
        },
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
  (Icons.tune, 'Set your priorities'),
  (Icons.groups_outlined, 'Get top match profiles'),
  (Icons.event_available_outlined, 'Shortlist, connect & rent'),
];

// ---------------------------------------------------------------------------
// Tenant / flatmate
// ---------------------------------------------------------------------------

class _TenantPriorities extends ConsumerStatefulWidget {
  const _TenantPriorities();

  @override
  ConsumerState<_TenantPriorities> createState() => _TenantPrioritiesState();
}

class _TenantPrioritiesState extends ConsumerState<_TenantPriorities> {
  SearchPriorities? _draft;
  var _edited = false;
  var _tab = 0;
  var _busy = false;

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
    final draft = _draft ??= saved.saved
        ? saved
        : seedTenantPriorities(
            requirement: ref.read(activeRequirementProvider),
            search: search,
          );
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
                    _LifestyleForm(value: draft, onChanged: _update),
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
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _edited = false;
    });
    unawaited(context.push(RoutePaths.prioritiesSaved));
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
  late final _places = TextEditingController(
    text: widget.value.locations.join(', '),
  );
  late final _city = TextEditingController(text: widget.value.city);
  String? _problem;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _places.dispose();
    _city.dispose();
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
      final places = [
        for (final part in _places.text.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      if (places.isEmpty && _city.text.trim().isEmpty) {
        setState(() => _problem = 'Add a locality or a city.');
        return;
      }
      next = next.copyWith(locations: places, city: _city.text.trim());
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
      return RadioGroup<String>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) {
            setState(() => set(value));
          }
        },
        child: Column(
          children: [
            for (final entry in options.entries)
              RadioListTile<String>(
                key: Key('priority-option-${entry.key}'),
                value: entry.key,
                contentPadding: EdgeInsets.zero,
                title: Text(homiziText(context, entry.value)),
              ),
          ],
        ),
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
        TextField(
          key: const Key('priority-places'),
          controller: _places,
          decoration: const InputDecoration(
            labelText: 'Localities, e.g. Andheri East, Powai',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('priority-city'),
          controller: _city,
          decoration: const InputDecoration(labelText: 'City'),
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
              FilterChip(
                key: Key('priority-type-option-$type'),
                label: Text(homiziText(context, propertyTypeLabel(type))),
                selected: _value.propertyTypes.contains(type),
                selectedColor: HomiziColors.accentWash,
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

class _LifestyleForm extends StatelessWidget {
  const _LifestyleForm({required this.value, required this.onChanged});

  final SearchPriorities value;
  final ValueChanged<SearchPriorities> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pick(
      String key,
      String label,
      String current,
      Map<String, String> options,
      SearchPriorities Function(String) apply,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: Key('life-$key'),
          initialValue: options.containsKey(current) ? current : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: homiziText(context, label)),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(homiziText(context, entry.value)),
              ),
          ],
          onChanged: (next) {
            if (next != null) {
              onChanged(apply(next));
            }
          },
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
          pick(
            'drinking',
            'Do you drink?',
            value.drinking,
            yesNo,
            (v) => value.copyWith(drinking: v),
          ),
          pick('food', 'Food', value.food, const {
            'vegetarian': 'Vegetarian',
            'non_vegetarian': 'Non-vegetarian',
            'both': 'Both',
            'undisclosed': 'Prefer not to say',
          }, (v) => value.copyWith(food: v)),
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
              'Homes whose house rules clash with your smoking or drinking answer score lower when Lifestyle & habits is ranked.',
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
    return DropdownButtonFormField<String>(
      key: const Key('priority-host-property'),
      initialValue: selected.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: homiziText(context, 'For your property'),
        helperText: isSampleHostHome(selected)
            ? homiziText(
                context,
                'Sample home until you post one. Values use its rent.',
              )
            : null,
      ),
      items: [
        for (final item in properties)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.label} · ${item.locality} · ${formatInr(item.rentInr)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        for (final item in properties) {
          if (item.id == id) {
            onPick(item);
          }
        }
      },
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
                  RadioGroup<String>(
                    groupValue: _value.gender,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _value = _value.copyWith(gender: v));
                      }
                    },
                    child: Column(
                      children: [
                        for (final entry in const {
                          'any': 'Any gender',
                          'male': 'Male',
                          'female': 'Female',
                        }.entries)
                          RadioListTile<String>(
                            key: Key('priority-option-${entry.key}'),
                            value: entry.key,
                            contentPadding: EdgeInsets.zero,
                            title: Text(homiziText(context, entry.value)),
                          ),
                      ],
                    ),
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
