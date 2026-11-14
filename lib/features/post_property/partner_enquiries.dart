class PartnerEnquiry {
  const PartnerEnquiry({
    required this.name,
    required this.place,
    required this.ask,
  });

  final String name;
  final String place;
  final String ask;
}

/// Sample enquiries. Shown until a live lead inbox is connected.
const partnerEnquiries = <PartnerEnquiry>[
  PartnerEnquiry(
    name: 'Ananya Sharma',
    place: 'Koramangala, Bengaluru',
    ask: '2 BHK apartment, move-in next month',
  ),
  PartnerEnquiry(
    name: 'Rohan Mehta',
    place: 'Bandra West, Mumbai',
    ask: 'Shared room for a working professional',
  ),
  PartnerEnquiry(
    name: 'Priya Iyer',
    place: 'Indiranagar, Bengaluru',
    ask: '3 BHK villa, family of four',
  ),
  PartnerEnquiry(
    name: 'Arjun Nair',
    place: 'Hinjewadi, Pune',
    ask: '1 BHK near the tech park',
  ),
  PartnerEnquiry(
    name: 'Sneha Reddy',
    place: 'Gachibowli, Hyderabad',
    ask: 'Full house, vegetarian home',
  ),
];
