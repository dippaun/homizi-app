import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/trust/trust_badge_section.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _bio = TextEditingController();
  final _localities = TextEditingController();
  final _occupancy = TextEditingController(text: '1');
  int _budgetMin = InrRangeScale.presetMin;
  int _budgetMax = InrRangeScale.presetMax;
  final _propertyTypes = <String>{};
  final _lifestyle = <String>{};
  VerificationStatus _status = VerificationStatus.notStarted;
  String? _avatar;
  String _ageRange = '';
  ViewStatus _view = ViewStatus.loading;
  String? _error;
  String? _note;
  String? _localityError;
  String? _occupancyError;
  String? _budgetError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refreshHeader);
    unawaited(_load());
  }

  void _refreshHeader() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.removeListener(_refreshHeader);
    _name.dispose();
    _occupation.dispose();
    _bio.dispose();
    _localities.dispose();
    _occupancy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _view = ViewStatus.loading);
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
      final budget = clampOrdered(
        start: profile.preferences.budgetMinInr,
        end: profile.preferences.budgetMaxInr,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        fallbackStart: InrRangeScale.presetMin,
        fallbackEnd: InrRangeScale.presetMax,
      );
      _budgetMin = budget.start;
      _budgetMax = budget.end;
      _localities.text = profile.preferences.localities.join(', ');
      _occupancy.text = profile.preferences.occupancy.toString();
      setState(() {
        _status = profile.verification;
        _avatar = profile.avatarUrl;
        _ageRange = profile.ageRange;
        _propertyTypes
          ..clear()
          ..addAll(profile.preferences.propertyTypes);
        _lifestyle
          ..clear()
          ..addAll(profile.preferences.lifestyle);
        _view = ViewStatus.ready;
        _error = null;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _view = ViewStatus.error;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _view = ViewStatus.error;
        _error = describedFailure(error);
      });
    }
  }

  TenantPreferences? _preferencesFromForm() {
    final occupancy = _count(_occupancy.text);
    if (occupancy == null) {
      setState(() => _applyFormError('Occupancy must be between 1 and 20.'));
      return null;
    }
    final localities = <String>[];
    for (final part in _localities.text.split(',')) {
      final item = part.trim();
      if (item.isEmpty) {
        continue;
      }
      if (item.length > 80) {
        setState(
          () =>
              _applyFormError('Each locality must be 80 characters or fewer.'),
        );
        return null;
      }
      localities.add(item);
    }
    return TenantPreferences(
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      localities: localities,
      occupancy: occupancy,
      propertyTypes: _propertyTypes.toList(),
      lifestyle: _lifestyle.toList(),
    );
  }

  Future<void> _save() async {
    final preferences = _preferencesFromForm();
    if (preferences == null) {
      return;
    }
    final invalid = preferenceSaveError(preferences);
    if (invalid != null) {
      setState(() => _applyFormError(invalid));
      return;
    }
    setState(() {
      _busy = true;
      _clearFieldErrors();
    });
    try {
      await ref
          .read(accountGatewayProvider)
          .saveTenantProfile(
            TenantProfile(
              displayName: _name.text,
              occupation: _occupation.text,
              bio: _bio.text,
              verification: _status,
              preferences: preferences,
              avatarUrl: _avatar,
              ageRange: _ageRange,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note =
            'Profile saved. Name, bio, and preferences were stored. Contact details were not part of this form.';
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = describedFailure(error);
      });
    }
  }

  Future<void> _mockVerify() async {
    setState(() => _busy = true);
    try {
      final status = await ref
          .read(accountGatewayProvider)
          .requestMockVerification();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = status;
        _note = mockVerificationMessage;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canQueue =
        _status == VerificationStatus.notStarted ||
        _status == VerificationStatus.rejected;
    final scheme = Theme.of(context).colorScheme;
    final name = _name.text.trim();
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(homiziText(context, 'Tenant profile')),
            ),
            if (_view != ViewStatus.ready)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AsyncStateBody(
                  status: _view,
                  loadingMessage: 'Loading your profile',
                  emptyTitle: 'No profile yet',
                  emptyMessage: 'Sign in to create your tenant profile.',
                  errorTitle: 'Profile unavailable',
                  errorMessage: _error ?? 'The profile could not be loaded.',
                  onRetry: () => unawaited(_load()),
                  child: const SizedBox.shrink(),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProfilePhotoRow(
                                name: name,
                                photoRef: _avatar,
                                gateway: ref.read(accountGatewayProvider),
                                onSaved: (next) =>
                                    setState(() => _avatar = next),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                homiziText(
                                  context,
                                  name.isEmpty ? 'Tenant profile' : name,
                                ),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (_occupation.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  homiziText(context, _occupation.text.trim()),
                                ),
                              ],
                              const SizedBox(height: 8),
                              VerifiedBadge(label: _status.label),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('tenant-age-range'),
                                initialValue: _ageRange.isEmpty
                                    ? null
                                    : _ageRange,
                                decoration: InputDecoration(
                                  labelText: homiziText(
                                    context,
                                    'Age range (optional)',
                                  ),
                                ),
                                items: [
                                  for (final range in ageRanges)
                                    DropdownMenuItem(
                                      value: range,
                                      child: Text(range),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _ageRange = value ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        homiziText(
                          context,
                          'Only fields a match needs. Date of birth and contact details are not on this form.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const TrustBadgeSection(),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('tenant-display-name'),
                        controller: _name,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Display name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _occupation,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Occupation'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('tenant-bio'),
                        controller: _bio,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Public bio'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        homiziText(
                          context,
                          'Leave localities blank when you have no preference. Published homes stay in Discover and Explore.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      HomiziRangeField(
                        label: 'Budget',
                        min: InrRangeScale.min,
                        max: InrRangeScale.max,
                        step: InrRangeScale.step,
                        start: _budgetMin,
                        end: _budgetMax,
                        formatValue: formatInr,
                        minSemantics: 'Budget minimum (INR)',
                        maxSemantics: 'Budget maximum (INR)',
                        sliderKey: const Key('tenant-budget-slider'),
                        valueKey: const Key('tenant-budget-value'),
                        onChanged: (start, end) => setState(() {
                          _budgetMin = start;
                          _budgetMax = end;
                        }),
                      ),
                      if (_budgetError != null)
                        LiveNotice(
                          message: homiziText(context, _budgetError!),
                          isError: true,
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('tenant-localities'),
                        controller: _localities,
                        decoration: InputDecoration(
                          labelText: homiziText(
                            context,
                            'Localities, comma separated',
                          ),
                          errorText: _localityError == null
                              ? null
                              : homiziText(context, _localityError!),
                        ),
                      ),
                      if (_localityError != null)
                        LiveLabel(
                          message: homiziText(context, _localityError!),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('tenant-occupancy'),
                        controller: _occupancy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: homiziText(context, 'Occupancy'),
                          errorText: _occupancyError == null
                              ? null
                              : homiziText(context, _occupancyError!),
                        ),
                      ),
                      if (_occupancyError != null)
                        LiveLabel(
                          message: homiziText(context, _occupancyError!),
                        ),
                      const SizedBox(height: 12),
                      Text(homiziText(context, 'Property types')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in tenantPropertyTypes)
                            FilterChip(
                              key: Key('pref-type-$type'),
                              label: Text(
                                homiziText(
                                  context,
                                  tenantPropertyTypeLabel(type),
                                ),
                              ),
                              selected: _propertyTypes.contains(type),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _propertyTypes.add(type);
                                  } else {
                                    _propertyTypes.remove(type);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(homiziText(context, 'Lifestyle')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in tenantLifestyles)
                            FilterChip(
                              key: Key('pref-life-$item'),
                              label: Text(
                                homiziText(context, tenantLifestyleLabel(item)),
                              ),
                              selected: _lifestyle.contains(item),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _lifestyle.add(item);
                                  } else {
                                    _lifestyle.remove(item);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(homiziText(context, 'Verification status')),
                        subtitle: Text(homiziText(context, _status.label)),
                      ),
                      if (_note != null)
                        LiveNotice(
                          key: const Key('tenant-profile-note'),
                          message: homiziText(context, _note!),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('save-tenant-profile'),
                        onPressed: _busy ? null : () => unawaited(_save()),
                        child: Text(
                          homiziText(
                            context,
                            _busy ? 'Saving…' : 'Save profile',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _busy || !canQueue
                            ? null
                            : () => unawaited(_mockVerify()),
                        child: Text(
                          homiziText(context, 'Start mock verification'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homiziText(
                          context,
                          'This does not call a verification provider and does not upload a document. The server only moves the status to mock pending.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _clearFieldErrors() {
    _localityError = null;
    _occupancyError = null;
    _budgetError = null;
  }

  void _applyFormError(String message) {
    final lower = message.toLowerCase();
    _localityError = lower.contains('locality') ? message : null;
    _occupancyError = lower.contains('occupancy') ? message : null;
    _budgetError = lower.contains('budget') ? message : null;
    final tied =
        _localityError != null ||
        _occupancyError != null ||
        _budgetError != null;
    _note = tied ? null : message;
  }
}

int? _count(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return 1;
  }
  final value = int.tryParse(text);
  if (value == null || value < 1 || value > 20) {
    return null;
  }
  return value;
}
