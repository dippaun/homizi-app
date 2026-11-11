import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Broker-only listing answers. Kept off [ListingDraft] so the shared wizard
/// can grow without a merge on the same fields.
class BrokerListingExtras {
  const BrokerListingExtras({
    this.ownerAuthorised = false,
    this.authorisationName = '',
  });

  final bool ownerAuthorised;
  final String authorisationName;

  BrokerListingExtras copyWith({
    bool? ownerAuthorised,
    String? authorisationName,
  }) {
    return BrokerListingExtras(
      ownerAuthorised: ownerAuthorised ?? this.ownerAuthorised,
      authorisationName: authorisationName ?? this.authorisationName,
    );
  }
}

class BrokerListingExtrasController extends Notifier<BrokerListingExtras> {
  @override
  BrokerListingExtras build() => const BrokerListingExtras();

  void setAuthorised(bool value) {
    state = state.copyWith(ownerAuthorised: value);
  }

  void attach(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state.copyWith(ownerAuthorised: true, authorisationName: trimmed);
  }
}

final brokerListingExtrasProvider =
    NotifierProvider<BrokerListingExtrasController, BrokerListingExtras>(
      BrokerListingExtrasController.new,
    );

/// Ink on a pale wash. Never white on yellow.
class ListedByBrokerBadge extends StatelessWidget {
  const ListedByBrokerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('broker-listed-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiziColors.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 16, color: HomiziColors.ink),
          const SizedBox(width: 6),
          Text(
            homiziText(context, 'Listed by Broker'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owner authorisation for a broker-listed home. An upload is a declaration
/// on this device. It is not a verified document, and it is not Aadhaar.
class BrokerOwnerAuthorisation extends ConsumerWidget {
  const BrokerOwnerAuthorisation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(brokerListingExtrasProvider);
    final attached = extras.authorisationName.trim();
    return Column(
      key: const Key('broker-owner-auth'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Owner authorisation'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Confirm the owner allowed you to list this home. An upload stays on this device and is not marked verified.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('broker-owner-auth-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            homiziText(context, 'I have the owner\'s authorisation'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          value: extras.ownerAuthorised,
          activeThumbColor: HomiziColors.ink,
          activeTrackColor: HomiziColors.accent,
          onChanged: (value) => ref
              .read(brokerListingExtrasProvider.notifier)
              .setAuthorised(value),
        ),
        OutlinedButton.icon(
          key: const Key('broker-owner-auth-upload'),
          onPressed: () => ref
              .read(brokerListingExtrasProvider.notifier)
              .attach('owner-authorisation.pdf'),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            homiziText(
              context,
              attached.isEmpty ? 'Upload authorisation' : attached,
            ),
          ),
        ),
      ],
    );
  }
}
