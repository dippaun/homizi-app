import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/room_share_plan.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Rooms on offer, the poster's profile, and a live rent estimate.
class RoomShareOffer extends StatelessWidget {
  const RoomShareOffer({
    required this.configuration,
    required this.raw,
    required this.onChanged,
    super.key,
  });

  final String configuration;
  final String raw;
  final ValueChanged<String> onChanged;

  void _emit(RoomSharePlan plan) {
    onChanged(plan.clamped(configuration).encode());
  }

  @override
  Widget build(BuildContext context) {
    final plan = RoomSharePlan.decode(raw).clamped(configuration);
    final cap = configurationRooms(configuration);
    final maxRooms = cap < 1 ? 4 : cap;
    final one = plan.quote(1);
    final two = plan.quote(2);
    return Column(
      key: const Key('room-share-offer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Rooms up for rent'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'In a shared home, some rooms stay with the people who already live there.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.3),
        ),
        const SizedBox(height: 10),
        OptionGrid(
          minTileWidth: 64,
          maxColumns: 4,
          children: [
            for (var count = 1; count <= maxRooms; count++)
              OptionTile(
                key: Key('share-rooms-$count'),
                label: '$count',
                icon: Icons.meeting_room_outlined,
                selected: plan.roomsForRent == count,
                onTap: () => _emit(plan.copyWith(roomsForRent: count)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < plan.roomsForRent; index++) ...[
          Text(
            homiziText(context, 'Room ${index + 1} occupancy'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          OptionGrid(
            minTileWidth: 96,
            children: [
              for (final seats in const [1, 2, 3])
                OptionTile(
                  key: Key('share-room-$index-seats-$seats'),
                  label: seats == 1 ? '1 person' : '$seats people',
                  icon: seats == 1
                      ? Icons.person_outline
                      : Icons.groups_outlined,
                  selected: plan.occupancy[index] == seats,
                  onTap: () {
                    final next = [...plan.occupancy];
                    next[index] = seats;
                    _emit(plan.copyWith(occupancy: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          homiziText(context, 'About the current occupant'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: const Key('share-occupant-profile'),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              homiziText(
                context,
                'Seekers see your profile: name, photo, city, budget, food, smoking, pets, and schedule. Edit those on your profile, not on this listing.',
              ),
              style: const TextStyle(color: HomiziColors.ink, height: 1.35),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MoneyField(
          fieldKey: const Key('share-total-rent'),
          label: 'Total rent of the home',
          icon: Icons.account_balance_wallet_outlined,
          amount: plan.totalRent,
          onChanged: (value) => _emit(plan.copyWith(totalRent: value)),
        ),
        const SizedBox(height: 12),
        _MoneyField(
          fieldKey: const Key('share-per-person-rent'),
          label: 'Rent per person today',
          icon: Icons.person_outline,
          amount: plan.perPersonRent,
          onChanged: (value) => _emit(plan.copyWith(perPersonRent: value)),
        ),
        const SizedBox(height: 14),
        _EstimateCard(one: one, two: two),
      ],
    );
  }
}

class _MoneyField extends StatefulWidget {
  const _MoneyField({
    required this.fieldKey,
    required this.label,
    required this.icon,
    required this.amount,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final IconData icon;
  final int amount;
  final ValueChanged<int> onChanged;

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.amount > 0 ? '${widget.amount}' : '',
  );

  @override
  void didUpdateWidget(_MoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = widget.amount > 0 ? '${widget.amount}' : '';
    if (_text.text != shown && widget.amount.toString() != _text.text) {
      if (widget.amount == 0 && _text.text.isEmpty) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _text,
      keyboardType: TextInputType.number,
      inputFormatters: const [WholeAmountFormatter()],
      decoration: listingFieldDecoration(context, widget.label, widget.icon),
      onChanged: (value) => widget.onChanged(int.tryParse(value.trim()) ?? 0),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.one, required this.two});

  final int? one;
  final int? two;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1E4), Color(0xFFF3ECFF)],
        ),
        border: Border.all(color: HomiziColors.logoOrange),
      ),
      child: Column(
        key: const Key('share-rent-estimate'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: HomiziColors.logoOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  homiziText(context, 'Rent for the room on offer'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Quote(
            icon: Icons.person_outline,
            label: 'If 1 person takes it',
            amount: one,
          ),
          const SizedBox(height: 8),
          _Quote(
            icon: Icons.groups_outlined,
            label: 'If 2 people take it',
            amount: two,
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.icon, required this.label, required this.amount});

  final IconData icon;
  final String label;
  final int? amount;

  @override
  Widget build(BuildContext context) {
    final shown = amount == null
        ? 'Add the rent'
        : '${formatInr(amount!)} / person';
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: HomiziColors.white,
          child: Icon(icon, size: 18, color: HomiziColors.homiziPurple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            homiziText(context, label),
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            shown,
            key: ValueKey(shown),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
