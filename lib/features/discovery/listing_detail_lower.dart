import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_skyline.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

/// Cost, facts, privacy, and message. Skyline stays a faint backdrop.
class ListingLowerSection extends StatelessWidget {
  const ListingLowerSection({
    required this.listing,
    required this.cost,
    required this.detailed,
    required this.addressShown,
    required this.addressLine,
    required this.landmark,
    required this.gate,
    required this.matchId,
    required this.onMessage,
    super.key,
  });

  final Listing listing;
  final RentingCost cost;
  final bool detailed;
  final bool addressShown;
  final String? addressLine;
  final String? landmark;
  final ContactGate gate;
  final String? matchId;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final facts = listingFactTiles(listing);
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(opacity: 0.18, child: LoginSkyline()),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListingCostCard(cost: cost, detailed: detailed),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 16),
              ListingFactGrid(facts: facts),
            ],
            const SizedBox(height: 16),
            ListingPrivacyCard(
              addressShown: addressShown,
              addressLine: addressLine,
              landmark: landmark,
              gate: gate,
              matchId: matchId,
            ),
            const SizedBox(height: 16),
            ListingMessageButton(
              buttonKey: Key('open-chat-${matchId ?? listing.id}'),
              onPressed: onMessage,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ],
    );
  }
}

class ListingCostCard extends StatefulWidget {
  const ListingCostCard({
    required this.cost,
    required this.detailed,
    super.key,
  });

  final RentingCost cost;
  final bool detailed;

  @override
  State<ListingCostCard> createState() => _ListingCostCardState();
}

class _ListingCostCardState extends State<ListingCostCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final lines = <(IconData, String, int)>[
      (Icons.payments_outlined, 'Monthly rent', widget.cost.rent),
      (
        Icons.account_balance_wallet_outlined,
        'Security deposit',
        widget.cost.deposit,
      ),
      (Icons.handyman_outlined, 'Maintenance', widget.cost.maintenance),
      (Icons.receipt_long_outlined, 'Brokerage', widget.cost.brokerage),
    ];
    final shown = [
      for (final line in lines)
        if (widget.detailed || line.$3 > 0) line,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1E8), Color(0xFFF3EEFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: HomiziColors.clear,
        child: InkWell(
          key: const Key('listing-cost-section'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.currency_rupee,
                      color: HomiziColors.logoOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        homiziText(context, 'Cost of renting'),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      color: HomiziColors.ink,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _CountUp(
                  value: widget.cost.moveInTotal,
                  reduce: reduce,
                  label: 'Move-in',
                ),
                AnimatedSize(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              for (final line in shown)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        line.$1,
                                        size: 18,
                                        color: HomiziColors.homiziPurple,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          homiziText(context, line.$2),
                                          style: const TextStyle(
                                            color: HomiziColors.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formatInr(line.$3),
                                        key: line.$2 == 'Move-in total'
                                            ? const Key('listing-cost-move-in')
                                            : Key('listing-cost-${line.$2}'),
                                        style: const TextStyle(
                                          color: HomiziColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Move-in total',
                                      style: TextStyle(
                                        color: HomiziColors.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatInr(widget.cost.moveInTotal),
                                    key: const Key('listing-cost-move-in'),
                                    style: const TextStyle(
                                      color: HomiziColors.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.reduce,
    required this.label,
  });

  final int value;
  final bool reduce;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (reduce) {
      return Text(
        homiziText(context, '$label ${formatInr(value)}'),
        style: const TextStyle(
          color: HomiziColors.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, amount, child) {
        return Text(
          homiziText(context, '$label ${formatInr(amount.round())}'),
          style: const TextStyle(
            color: HomiziColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}

class ListingFact {
  const ListingFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
}

List<ListingFact> listingFactTiles(Listing listing) {
  final facts = <ListingFact>[];
  if (listing.floorNo != null) {
    final floor = listing.totalFloors == null
        ? 'Floor ${listing.floorNo}'
        : 'Floor ${listing.floorNo} of ${listing.totalFloors}';
    facts.add(
      ListingFact(
        icon: Icons.stairs_outlined,
        label: 'Floor',
        value: floor,
        tint: const Color(0xFFFFE8DC),
      ),
    );
  }
  final open = _openTo(listing);
  if (open.isNotEmpty) {
    facts.add(
      ListingFact(
        icon: Icons.groups_outlined,
        label: 'Open to',
        value: open,
        tint: const Color(0xFFF3EEFF),
      ),
    );
  }
  if (listing.furnishing.trim().isNotEmpty) {
    facts.add(
      ListingFact(
        icon: Icons.chair_outlined,
        label: 'Furnishing',
        value: listing.furnishingLabel,
        tint: const Color(0xFFFFF6D8),
      ),
    );
  }
  facts.add(
    ListingFact(
      icon: Icons.local_parking_outlined,
      label: 'Parking',
      value: listing.parking ? 'Available' : 'No parking',
      tint: const Color(0xFFE7F6EC),
    ),
  );
  if (listing.bhkLabel.trim().isNotEmpty) {
    facts.add(
      ListingFact(
        icon: Icons.apartment_outlined,
        label: 'Home',
        value: listing.bhkLabel,
        tint: const Color(0xFFE8F1FF),
      ),
    );
  }
  final bath = listing.bathroom.trim();
  if (bath.isNotEmpty) {
    facts.add(
      ListingFact(
        icon: Icons.bathtub_outlined,
        label: 'Bath',
        value: bath,
        tint: const Color(0xFFE7F6F4),
      ),
    );
  }
  final area = listing.areaSqft;
  if (area != null && area > 0) {
    facts.add(
      ListingFact(
        icon: Icons.square_foot,
        label: 'Area',
        value: '$area sq ft',
        tint: const Color(0xFFFFE8DC),
      ),
    );
  }
  if (listing.leaseMonths != null && listing.leaseMonths! > 0) {
    facts.add(
      ListingFact(
        icon: Icons.event_outlined,
        label: 'Lease',
        value: '${listing.leaseMonths} months',
        tint: const Color(0xFFF3EEFF),
      ),
    );
  }
  return facts;
}

String _openTo(Listing listing) {
  final labels = [
    for (final key in listing.preferredTenants)
      if (key == 'any') 'Anyone' else preferredTenantLabel(key),
  ];
  if (labels.isEmpty) {
    return '';
  }
  if (labels.length == 1 && labels.single == 'Anyone') {
    return 'Anyone';
  }
  return labels.join(', ');
}

class ListingFactGrid extends StatelessWidget {
  const ListingFactGrid({required this.facts, super.key});

  final List<ListingFact> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < facts.length; i++)
          _Stagger(
            index: i,
            child: _FactTile(fact: facts[i]),
          ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final ListingFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fact.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(fact.icon, color: HomiziColors.logoOrange, size: 20),
          const SizedBox(height: 8),
          Text(
            homiziText(context, fact.label),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            homiziText(context, fact.value),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class ListingPrivacyCard extends StatelessWidget {
  const ListingPrivacyCard({
    required this.addressShown,
    required this.addressLine,
    required this.landmark,
    required this.gate,
    required this.matchId,
    super.key,
  });

  final bool addressShown;
  final String? addressLine;
  final String? landmark;
  final ContactGate gate;
  final String? matchId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: gate.showsContact ? null : const Key('contact-gate'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7F2), Color(0xFFF6F3FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: HomiziColors.homiziPurple),
              SizedBox(width: 8),
              Icon(
                Icons.lock_outline,
                color: HomiziColors.logoOrange,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Private until you agree',
                  style: TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('listing-address-gate'),
            homiziText(
              context,
              addressShown
                  ? (addressLine ?? '')
                  : 'The street address appears after a visit is agreed.',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (addressShown && landmark != null) ...[
            const SizedBox(height: 4),
            Text(homiziText(context, landmark!)),
          ],
          const SizedBox(height: 6),
          if (gate.showsContact)
            ContactGatePanel(gate: gate, matchId: matchId)
          else
            Text(
              homiziText(
                context,
                'Phone and email appear after you both match and consent.',
              ),
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class ListingMessageButton extends StatelessWidget {
  const ListingMessageButton({
    required this.buttonKey,
    required this.onPressed,
    super.key,
  });

  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HomiziColors.brandRedOrange, HomiziColors.homiziPurple],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: HomiziColors.clear,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: HomiziColors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  homiziText(context, 'Message'),
                  style: const TextStyle(
                    color: HomiziColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
