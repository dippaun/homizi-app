import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/payments/domain/payment_rules.dart';
import 'package:homizi/features/payments/payment_gateway.dart';
import 'package:homizi/features/payments/payment_providers.dart';
import 'package:homizi/features/payments/razorpay_checkout.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _amount = TextEditingController(text: '22000');
  final _period = TextEditingController(text: 'October 2026');
  PaymentKind _kind = PaymentKind.rent;
  String? _matchId;
  var _busy = false;
  String? _note;
  List<PaymentRecord> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _period.dispose();
    super.dispose();
  }

  List<MatchSummary> _matches() {
    final live = ref.read(discoveryProvider).matches;
    if (live.isNotEmpty) {
      return live;
    }
    final config = ref.read(appConfigProvider);
    if (config.connectsToSupabase && !ref.read(forceDemoModeProvider)) {
      return const [];
    }
    return const [
      MatchSummary(
        matchId: 'demo-match-lst_koramangala',
        otherUserId: 'demo-host-rohan',
        otherDisplayName: 'Rohan M.',
        listingTitle: 'Sunlit 2BHK in Koramangala',
        contact: ContactGate.hidden('demo'),
      ),
    ];
  }

  Future<void> _load() async {
    final rows = await ref.read(paymentGatewayProvider).listMine();
    if (!mounted) {
      return;
    }
    setState(() => _rows = rows);
  }

  Future<void> _start() async {
    final amount = int.tryParse(_amount.text.trim());
    final problem = validatePaymentAmount(amount);
    final matches = _matches();
    final matchId = _matchId ?? (matches.isEmpty ? '' : matches.first.matchId);
    if (problem != null || matchId.isEmpty || amount == null) {
      setState(() => _note = problem ?? 'Choose a match before paying.');
      return;
    }
    final named = matches.where((match) => match.matchId == matchId);
    final name = named.isEmpty ? null : named.first.otherDisplayName;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final session = await ref
          .read(paymentGatewayProvider)
          .start(
            matchId: matchId,
            kind: _kind,
            amountInr: amount,
            counterpartyName: name ?? 'Match',
            periodLabel: _period.text.trim(),
          );
      if (!mounted) {
        return;
      }
      if (session.usesRazorpay) {
        final checkout = await openRazorpayCheckout(
          RazorpayCheckoutRequest(
            keyId: session.razorpayKeyId!,
            orderId: session.razorpayOrderId!,
            amountPaise: session.amountPaise ?? amountPaise(amount),
            description: '${_kind.label} to ${name ?? 'your match'}',
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() => _note = checkout.message);
      } else {
        setState(
          () => _note = 'Test mode is ready. Simulate the result below.',
        );
      }
      await _load();
    } on PaymentFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _finish(PaymentRecord row, bool success) async {
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(paymentGatewayProvider)
          .completeDemo(paymentId: row.id, success: success);
      if (!mounted) {
        return;
      }
      setState(() {
        _note = next.isPaid
            ? 'Marked paid in test mode. No real money moved.'
            : 'Marked failed in test mode. No real money moved.';
      });
      await _load();
    } on PaymentFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openReceipts() {
    final router = GoRouter.of(context);
    if (_hasPath(router, RoutePaths.tools)) {
      context.push(RoutePaths.tools);
      return;
    }
    final paid = _rows.where((row) => row.isPaid);
    final latest = paid.isEmpty ? null : paid.first;
    final detail = latest == null
        ? 'Receipts are filled in under Tools once that section is available.'
        : 'Copy this test payment into a receipt under Tools: ${latest.kind.label}, ${formatInr(latest.amountInr)}, ${latest.periodLabel ?? 'this period'}.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(homiziText(context, 'Rent receipt')),
        content: Text(homiziText(context, detail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(homiziText(context, 'OK')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches();
    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Pay rent')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            homiziText(context, 'Pay rent after you match with an owner.'),
          ),
        ),
      );
    }
    final selected = _matchId ?? matches.first.matchId;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Pay rent')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Material(
            key: const Key('payments-test-banner'),
            color: HomiziColors.accent,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                homiziText(
                  context,
                  'Test mode. No real money moves. Razorpay stays in test mode, and demo mode simulates the result.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: HomiziColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            key: const Key('payment-match'),
            initialSelection: selected,
            label: Text(homiziText(context, 'Choose a match')),
            dropdownMenuEntries: [
              for (final match in matches)
                DropdownMenuEntry(
                  value: match.matchId,
                  label:
                      '${match.otherDisplayName} · ${match.listingTitle ?? 'Home'}',
                ),
            ],
            onSelected: (value) => setState(() => _matchId = value),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentKind>(
            segments: [
              for (final kind in PaymentKind.values)
                ButtonSegment(
                  value: kind,
                  label: Text(homiziText(context, kind.label)),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (next) => setState(() => _kind = next.first),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('payment-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Amount (INR)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _period,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Period'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('payment-start'),
            onPressed: _busy ? null : () => unawaited(_start()),
            child: Text(homiziText(context, 'Pay')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('payment-note')),
          ],
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Your payments'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_rows.isEmpty) Text(homiziText(context, 'No test payments yet.')),
          for (final row in _rows) _PaymentTile(row: row, onFinish: _finish),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('payment-receipt'),
            onPressed: _openReceipts,
            child: Text(homiziText(context, 'Rent receipt')),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.row, required this.onFinish});

  final PaymentRecord row;
  final Future<void> Function(PaymentRecord row, bool success) onFinish;

  @override
  Widget build(BuildContext context) {
    final open = row.isOpen && row.isDemo;
    return Card(
      color: HomiziColors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row.kind.label} · ${formatInr(row.amountInr)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(homiziText(context, _statusLabel(row.status))),
            if (open)
              Row(
                children: [
                  TextButton(
                    key: const Key('payment-success'),
                    onPressed: () => unawaited(onFinish(row, true)),
                    child: Text(homiziText(context, 'Simulate success')),
                  ),
                  TextButton(
                    key: const Key('payment-failure'),
                    onPressed: () => unawaited(onFinish(row, false)),
                    child: Text(homiziText(context, 'Simulate failure')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'succeeded' || 'paid' => 'Paid',
    'failed' => 'Failed',
    'refunded' => 'Refunded',
    _ => 'Pending',
  };
}

bool _hasPath(GoRouter router, String path) {
  bool walk(RouteBase route) {
    if (route is GoRoute && route.path == path) {
      return true;
    }
    for (final child in route.routes) {
      if (walk(child)) {
        return true;
      }
    }
    return false;
  }

  for (final route in router.configuration.routes) {
    if (walk(route)) {
      return true;
    }
  }
  return false;
}
