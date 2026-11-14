import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

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
      width: 168,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    key: Key('enquiry-dismiss-${enquiry.name}'),
                    padding: EdgeInsets.zero,
                    tooltip: homiziText(context, 'Dismiss'),
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 16),
                    color: HomiziColors.ink,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: HomiziColors.mist,
                backgroundImage: AssetImage(enquiry.avatar),
              ),
              const SizedBox(height: 8),
              Text(
                enquiry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                enquiry.line,
                key: Key('enquiry-line-${enquiry.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        HomiziColors.brandGolden,
                        HomiziColors.logoOrange,
                      ],
                    ),
                  ),
                  child: TextButton(
                    key: Key('enquiry-respond-${enquiry.name}'),
                    style: TextButton.styleFrom(
                      foregroundColor: HomiziColors.ink,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 36),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            homiziText(
                              context,
                              'Response noted for ${enquiry.name}.',
                            ),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      homiziText(context, 'Respond'),
                      style: const TextStyle(
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
      ),
    );
  }
}
