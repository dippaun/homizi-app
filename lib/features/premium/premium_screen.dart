import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_providers.dart';
import 'package:homizi/ui/kit/sticky_cta.dart';

/// HOMIZI Premium paywall: benefits, the two plans, and one confirm button.
/// A finished purchase opens the shared confirmation page.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  PremiumPeriod _selected = PremiumPeriod.annual;
  List<PremiumPlan> _plans = premiumDefaultPlans;
  var _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlans());
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ref.read(premiumServiceProvider).loadPlans();
      if (mounted) {
        setState(() => _plans = plans);
      }
    } on PremiumFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    }
  }

  PremiumPlan get _plan =>
      _plans.firstWhere((plan) => plan.period == _selected);

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    final plan = _plan;
    try {
      await ref.read(premiumStatusProvider.notifier).purchase(plan);
      if (!mounted) {
        return;
      }
      openDemoSuccess(
        context,
        title: 'Welcome to HOMIZI Premium',
        detail: plan.isAnnual
            ? 'Your yearly plan is on. Unlimited contacts, a boosted listing and priority matches are ready.'
            : 'Your monthly plan is on. Unlimited contacts, a boosted listing and priority matches are ready.',
      );
    } on PremiumCancelled {
      // The person closed checkout. Nothing to report.
    } on PremiumFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final status = await ref.read(premiumStatusProvider.notifier).restore();
      if (mounted) {
        setState(
          () => _note = status.isActive
              ? 'Your Premium plan is back.'
              : 'No earlier Premium plan was found.',
        );
      }
    } on PremiumFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(premiumStatusProvider).value;
    final active = status?.isActive ?? false;
    final mode = ref.watch(premiumServiceProvider).mode;
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('premium-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'HOMIZI Premium')),
      ),
      bottomNavigationBar: active
          ? null
          : StickyCta(
              child: FilledButton(
                key: const Key('premium-subscribe'),
                onPressed: _busy ? null : () => unawaited(_buy()),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '${homiziText(context, 'Get Premium')} · '
                        '${_plan.priceLabel}/${homiziText(context, _plan.periodWord)}',
                      ),
              ),
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const _Hero(),
              const SizedBox(height: 20),
              for (final benefit in premiumBenefits)
                _BenefitRow(benefit: benefit),
              const SizedBox(height: 8),
              if (mode.chargesNothing)
                Container(
                  key: const Key('premium-sandbox-note'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomiziColors.accentWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        size: 20,
                        color: HomiziColors.ink,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          homiziText(
                            context,
                            'Test mode. No real money is charged.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HomiziColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (mode.chargesNothing) const SizedBox(height: 12),
              const SizedBox(height: 8),
              if (active)
                _ActiveCard(status: status!)
              else ...[
                for (final plan in _plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanCard(
                      plan: plan,
                      saving: PremiumPlan.annualSavingInr(
                        monthly: premiumDefaultPlans.first.priceInr,
                        annual: premiumDefaultPlans.last.priceInr,
                      ),
                      selected: plan.period == _selected,
                      onTap: () => setState(() => _selected = plan.period),
                    ),
                  ),
                TextButton(
                  key: const Key('premium-restore'),
                  onPressed: _busy ? null : () => unawaited(_restore()),
                  child: Text(homiziText(context, 'Restore purchase')),
                ),
              ],
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    homiziText(context, _note!),
                    key: const Key('premium-note'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                homiziText(
                  context,
                  'Cancel any time. Rent and deposits are paid separately and are not part of Premium.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HomiziColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomiziColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: HomiziColors.logoOrange,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                Icons.workspace_premium,
                size: 30,
                color: HomiziColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, 'Find and fill homes faster'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: HomiziColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  homiziText(context, 'One plan for tenants and owners.'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: HomiziColors.line),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final PremiumBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('premium-benefit-${benefit.key}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, benefit.title),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                Text(
                  homiziText(context, benefit.detail),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.saving,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlan plan;
  final int saving;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('premium-plan-${plan.period.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? HomiziColors.accentWash : HomiziColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? HomiziColors.logoOrange : HomiziColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? HomiziColors.logoOrange : HomiziColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, plan.title),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                    if (plan.isAnnual)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: HomiziColors.brandYellow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            child: Text(
                              '${homiziText(context, 'Best value')} · '
                              '${homiziText(context, 'Save')} ₹$saving',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${plan.priceLabel}/${homiziText(context, plan.periodWord)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.status});

  final PremiumStatus status;

  @override
  Widget build(BuildContext context) {
    final period = status.period == PremiumPeriod.annual ? 'yearly' : 'monthly';
    return Container(
      key: const Key('premium-active'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: HomiziColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${homiziText(context, 'You have HOMIZI Premium')} '
              '(${homiziText(context, period)})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
