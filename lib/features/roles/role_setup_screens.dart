import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_flow.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';
import 'package:homizi/features/roles/role_setup.dart';

class OwnerSetupScreen extends ConsumerStatefulWidget {
  const OwnerSetupScreen({super.key});

  @override
  ConsumerState<OwnerSetupScreen> createState() => _OwnerSetupScreenState();
}

class _OwnerSetupScreenState extends ConsumerState<OwnerSetupScreen> {
  String? _error;

  void _continue() {
    final city = ref.read(personalizationProvider).city.trim();
    final setup = ref.read(roleSetupProvider);
    if (city.length < 2) {
      setState(() => _error = 'Choose a city, or type one.');
      return;
    }
    if (setup.propertyType.isEmpty) {
      setState(() => _error = 'Choose a property type.');
      return;
    }
    if (setup.propertyCount.isEmpty) {
      setState(() => _error = 'Choose how many properties you have.');
      return;
    }
    context.push(readyLocation('host'));
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(personalizationProvider).city;
    final setup = ref.watch(roleSetupProvider);
    return RoleFlowScaffold(
      screenKey: const Key('owner-setup-screen'),
      title: 'Your property',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RoleFlowIntro(
            'A short note is enough. You can list the home in the next step.',
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('City'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: {for (final name in personalCities) name: name},
            selected: (id) => city == id,
            onSelected: (id) =>
                ref.read(personalizationProvider.notifier).setCity(id),
            keyFor: (id) => Key('owner-city-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Property type'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: ownerPropertyTypes,
            selected: (id) => setup.propertyType == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setPropertyType(id),
            keyFor: (id) => Key('owner-type-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('How many properties?'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: ownerPropertyCounts,
            selected: (id) => setup.propertyCount == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setPropertyCount(id),
            keyFor: (id) => Key('owner-count-$id'),
          ),
          RoleFlowError(
            message: _error,
            errorKey: const Key('owner-setup-error'),
          ),
          const SizedBox(height: 20),
          RoleFlowContinue(
            buttonKey: const Key('owner-setup-continue'),
            label: 'Continue',
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}

class PartnerSetupScreen extends ConsumerStatefulWidget {
  const PartnerSetupScreen({super.key});

  @override
  ConsumerState<PartnerSetupScreen> createState() => _PartnerSetupScreenState();
}

class _PartnerSetupScreenState extends ConsumerState<PartnerSetupScreen> {
  late final TextEditingController _agency;
  late final TextEditingController _rera;
  late final TextEditingController _locality;
  String? _error;

  @override
  void initState() {
    super.initState();
    final setup = ref.read(roleSetupProvider);
    _agency = TextEditingController(text: setup.agencyName);
    _rera = TextEditingController(text: setup.rera);
    _locality = TextEditingController(text: setup.locality);
  }

  @override
  void dispose() {
    _agency.dispose();
    _rera.dispose();
    _locality.dispose();
    super.dispose();
  }

  void _continue() {
    final setup = ref.read(roleSetupProvider);
    ref.read(roleSetupProvider.notifier).setAgencyName(_agency.text.trim());
    ref.read(roleSetupProvider.notifier).setRera(_rera.text.trim());
    ref.read(roleSetupProvider.notifier).setLocality(_locality.text.trim());
    if (setup.cities.isEmpty) {
      setState(() => _error = 'Choose at least one city you serve.');
      return;
    }
    context.push(readyLocation('broker'));
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(roleSetupProvider).cities;
    return RoleFlowScaffold(
      screenKey: const Key('partner-setup-screen'),
      title: 'Partner setup',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RoleFlowIntro(
            'Agency name and RERA are optional. Cities help match seeker briefs.',
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Agency name'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('partner-agency'),
            controller: _agency,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: homiziText(context, 'Deshpande Realty'),
              filled: true,
              fillColor: HomiziColors.soft,
            ),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Cities you serve'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: {for (final name in personalCities) name: name},
            selected: cities.contains,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).toggleCity(id),
            keyFor: (id) => Key('partner-city-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Locality'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('partner-locality'),
            controller: _locality,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: homiziText(context, 'Koramangala, Bandra West'),
              filled: true,
              fillColor: HomiziColors.soft,
            ),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('RERA number'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('partner-rera'),
            controller: _rera,
            decoration: InputDecoration(
              hintText: homiziText(context, 'Optional'),
              filled: true,
              fillColor: HomiziColors.soft,
            ),
          ),
          RoleFlowError(
            message: _error,
            errorKey: const Key('partner-setup-error'),
          ),
          const SizedBox(height: 20),
          RoleFlowContinue(
            buttonKey: const Key('partner-setup-continue'),
            label: 'Continue',
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}

class SharerSetupScreen extends ConsumerStatefulWidget {
  const SharerSetupScreen({super.key});

  @override
  ConsumerState<SharerSetupScreen> createState() => _SharerSetupScreenState();
}

class _SharerSetupScreenState extends ConsumerState<SharerSetupScreen> {
  late final TextEditingController _locality;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locality = TextEditingController(
      text: ref.read(roleSetupProvider).locality,
    );
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  void _continue() {
    final city = ref.read(personalizationProvider).city.trim();
    final setup = ref.read(roleSetupProvider);
    ref.read(roleSetupProvider.notifier).setLocality(_locality.text.trim());
    if (city.length < 2) {
      setState(() => _error = 'Choose a city, or type one.');
      return;
    }
    if (setup.roomKind.isEmpty) {
      setState(() => _error = 'Choose the room you are sharing.');
      return;
    }
    context.push(readyLocation('roommate'));
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(personalizationProvider).city;
    final setup = ref.watch(roleSetupProvider);
    return RoleFlowScaffold(
      screenKey: const Key('sharer-setup-screen'),
      title: 'Your room',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RoleFlowIntro(
            'Tell flatmates the room, the house rules, and your share of the rent.',
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('City'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: {for (final name in personalCities) name: name},
            selected: (id) => city == id,
            onSelected: (id) =>
                ref.read(personalizationProvider.notifier).setCity(id),
            keyFor: (id) => Key('sharer-city-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Locality'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('sharer-locality'),
            controller: _locality,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: homiziText(context, 'Koramangala'),
              filled: true,
              fillColor: HomiziColors.soft,
            ),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Room'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: sharerRoomKinds,
            selected: (id) => setup.roomKind == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setRoomKind(id),
            keyFor: (id) => Key('sharer-room-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Flatmate'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: sharerGenders,
            selected: (id) => setup.gender == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setGender(id),
          ),
          const SizedBox(height: 12),
          RoleFlowChips(
            options: sharerFood,
            selected: (id) => setup.food == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setFood(id),
          ),
          const SizedBox(height: 12),
          RoleFlowChips(
            options: sharerSmoking,
            selected: (id) => setup.smoking == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setSmoking(id),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Your share of the rent'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: sharerBudgetShares,
            selected: (id) => setup.budgetShare == id,
            onSelected: (id) =>
                ref.read(roleSetupProvider.notifier).setBudgetShare(id),
            keyFor: (id) => Key('sharer-budget-$id'),
          ),
          RoleFlowError(
            message: _error,
            errorKey: const Key('sharer-setup-error'),
          ),
          const SizedBox(height: 20),
          RoleFlowContinue(
            buttonKey: const Key('sharer-setup-continue'),
            label: 'Continue',
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}
