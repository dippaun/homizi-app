import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

/// Writes `profiles` and `tenant_preferences` for the signed-in tenant.
class TenantSetupScreen extends ConsumerStatefulWidget {
  const TenantSetupScreen({super.key});

  @override
  ConsumerState<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends ConsumerState<TenantSetupScreen> {
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _bio = TextEditingController();
  final _localities = TextEditingController();
  int _budgetMin = InrRangeScale.presetMin;
  int _budgetMax = InrRangeScale.presetMax;
  final _types = <String>{'apartment'};
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    _bio.dispose();
    _localities.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (ref.read(sessionProvider).phase != SessionPhase.ready) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      if (!mounted) {
        return;
      }
      _name.text = profile.displayName;
      _occupation.text = profile.occupation;
      _bio.text = profile.bio;
      _localities.text = profile.preferences.localities.join(', ');
      final budget = clampOrdered(
        start: profile.preferences.budgetMinInr,
        end: profile.preferences.budgetMaxInr,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        fallbackStart: InrRangeScale.presetMin,
        fallbackEnd: InrRangeScale.presetMax,
      );
      setState(() {
        _budgetMin = budget.start;
        _budgetMax = budget.end;
        if (profile.preferences.propertyTypes.isNotEmpty) {
          _types
            ..clear()
            ..addAll(profile.preferences.propertyTypes);
        }
        _loading = false;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  List<String> _localityList() {
    final items = <String>[];
    for (final part in _localities.text.split(',')) {
      final item = part.trim();
      if (item.isEmpty || item.length > 80) {
        continue;
      }
      items.add(item);
    }
    return items;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter the name you want hosts to see.');
      return;
    }
    final preferences = TenantPreferences(
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      localities: _localityList(),
      propertyTypes: [
        for (final type in _types)
          if (tenantPropertyTypes.contains(type)) type,
      ],
    );
    final invalid = preferenceSaveError(preferences);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountGatewayProvider)
          .saveTenantProfile(
            TenantProfile(
              displayName: name,
              occupation: _occupation.text.trim(),
              bio: _bio.text.trim(),
              preferences: preferences,
            ),
          );
      if (!mounted) {
        return;
      }
      ref.read(tenantIntentProvider.notifier).clear();
      if (demoModeOn(ref)) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Profile saved',
          detail: 'Your tenant profile is ready.',
        );
        return;
      }
      context.go(RoutePaths.home);
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (demoModeOn(ref)) {
        setState(() => _busy = false);
        ref.read(tenantIntentProvider.notifier).clear();
        openDemoSuccess(
          context,
          title: 'Profile saved',
          detail: 'Your tenant profile is ready.',
        );
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  void _skip() {
    ref.read(tenantIntentProvider.notifier).clear();
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(sessionProvider).phase;
    if (phase != SessionPhase.ready) {
      return Scaffold(
        key: const Key('tenant-setup-screen'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Tenant profile')),
        ),
        body: Center(
          child:
              phase == SessionPhase.needsRole || phase == SessionPhase.booting
              ? const CircularProgressIndicator()
              : const TenantSignInPrompt(),
        ),
      );
    }
    return Scaffold(
      key: const Key('tenant-setup-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: HomiziBackButton(
          key: const Key('tenant-setup-skip'),
          onPressed: () {
            if (_busy) {
              return;
            }
            _skip();
          },
        ),
        title: Text(homiziText(context, 'Tenant profile')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  homiziText(context, 'Tell hosts who you are'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'Your name and preferences are saved on your account. Phone and email stay off this form.',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('tenant-setup-name'),
                  controller: _name,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Display name'),
                    hintText: homiziText(context, 'Meera Iyer'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('tenant-setup-occupation'),
                  controller: _occupation,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Occupation'),
                    hintText: homiziText(
                      context,
                      'Product designer in Bengaluru',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('tenant-setup-bio'),
                  controller: _bio,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'About you'),
                    hintText: homiziText(
                      context,
                      'Quiet on weeknights. I cook most evenings.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                HomiziRangeField(
                  label: 'Monthly budget',
                  min: InrRangeScale.min,
                  max: InrRangeScale.max,
                  step: InrRangeScale.step,
                  start: _budgetMin,
                  end: _budgetMax,
                  formatValue: formatInr,
                  minSemantics: 'Budget minimum (INR)',
                  maxSemantics: 'Budget maximum (INR)',
                  sliderKey: const Key('tenant-setup-budget'),
                  onChanged: (start, end) => setState(() {
                    _budgetMin = start;
                    _budgetMax = end;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('tenant-setup-locality'),
                  controller: _localities,
                  decoration: InputDecoration(
                    labelText: homiziText(
                      context,
                      'Localities, comma separated',
                    ),
                    hintText: homiziText(context, 'Indiranagar, Koramangala'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  homiziText(context, 'Home type'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in tenantPropertyTypes)
                      FilterChip(
                        key: Key('tenant-setup-type-$type'),
                        label: Text(
                          homiziText(context, tenantPropertyTypeLabel(type)),
                        ),
                        selected: _types.contains(type),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _types.add(type);
                            } else {
                              _types.remove(type);
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    key: const Key('tenant-setup-error'),
                    homiziText(context, _error!),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save-tenant-setup'),
                  onPressed: _busy ? null : () => unawaited(_save()),
                  child: Text(
                    homiziText(context, _busy ? 'Saving…' : 'Save profile'),
                  ),
                ),
              ],
            ),
    );
  }
}
