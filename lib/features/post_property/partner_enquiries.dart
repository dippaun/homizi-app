import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/shared/widgets/homizi_match_card.dart';

class PartnerEnquiry {
  const PartnerEnquiry({
    required this.name,
    required this.place,
    required this.ask,
    required this.line,
    required this.avatar,
  });

  final String name;
  final String place;
  final String ask;

  /// Short line under the name, for example "Koramangala · 2BHK".
  final String line;
  final String avatar;
}

/// Sample enquiries. Shown until a live lead inbox is connected.
const partnerEnquiries = <PartnerEnquiry>[
  PartnerEnquiry(
    name: 'Ananya Sharma',
    place: 'Koramangala, Bengaluru',
    ask: '2 BHK apartment, move-in next month',
    line: 'Koramangala · 2BHK',
    avatar: 'assets/avatars/avatar_01.webp',
  ),
  PartnerEnquiry(
    name: 'Rohan Mehta',
    place: 'Bandra West, Mumbai',
    ask: 'Shared room for a working professional',
    line: 'Bandra West · Shared room',
    avatar: 'assets/avatars/avatar_02.webp',
  ),
  PartnerEnquiry(
    name: 'Priya Iyer',
    place: 'Indiranagar, Bengaluru',
    ask: '3 BHK villa, family of four',
    line: 'Indiranagar · 3BHK',
    avatar: 'assets/avatars/avatar_03.webp',
  ),
  PartnerEnquiry(
    name: 'Arjun Nair',
    place: 'Hinjewadi, Pune',
    ask: '1 BHK near the tech park',
    line: 'Hinjewadi · 1BHK',
    avatar: 'assets/avatars/avatar_04.webp',
  ),
  PartnerEnquiry(
    name: 'Sneha Reddy',
    place: 'Gachibowli, Hyderabad',
    ask: 'Full house, vegetarian home',
    line: 'Gachibowli · Full house',
    avatar: 'assets/avatars/avatar_05.webp',
  ),
];

/// Horizontal "suggested for you" row used on the partner desk.
class PartnerEnquiryStrip extends StatefulWidget {
  const PartnerEnquiryStrip({super.key});

  @override
  State<PartnerEnquiryStrip> createState() => _PartnerEnquiryStripState();
}

class _PartnerEnquiryStripState extends State<PartnerEnquiryStrip> {
  final _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final enquiry in partnerEnquiries)
        if (!_hidden.contains(enquiry.name)) enquiry,
    ];
    if (shown.isEmpty) {
      return Text(
        homiziText(context, 'No enquiries left in this sample.'),
        style: const TextStyle(color: HomiziColors.inkSoft),
      );
    }
    return SizedBox(
      key: const Key('partner-enquiry-strip'),
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final enquiry = shown[index];
          return _SuggestedCard(
            enquiry: enquiry,
            onDismiss: () => setState(() => _hidden.add(enquiry.name)),
          );
        },
      ),
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({required this.enquiry, required this.onDismiss});

  final PartnerEnquiry enquiry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: HomiziMatchCard(
        compact: true,
        title: enquiry.name,
        price: enquiry.ask,
        locality: enquiry.place,
        person: true,
        photos: [enquiry.avatar],
        photoSeed: enquiry.name,
        chips: [
          HomiziCardChip(
            enquiry.line,
            chipKey: Key('enquiry-line-${enquiry.name}'),
          ),
        ],
        actions: [
          HomiziCardAction(
            actionKey: Key('enquiry-dismiss-${enquiry.name}'),
            tooltip: 'Dismiss',
            icon: Icons.close,
            onPressed: onDismiss,
          ),
          HomiziCardAction(
            actionKey: Key('enquiry-respond-${enquiry.name}'),
            tooltip: 'Respond',
            icon: Icons.reply,
            label: 'Respond',
            primary: true,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    homiziText(context, 'Response noted for ${enquiry.name}.'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
