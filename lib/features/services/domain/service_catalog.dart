enum ServiceKind {
  packersMovers,
  cleaning,
  painting,
  acRepair,
  plumbing,
  electrician,
  carpentry,
}

const serviceCities = <String>[
  'Bengaluru',
  'Mumbai',
  'Pune',
  'Delhi NCR',
  'Hyderabad',
  'Chennai',
  'Ahmedabad',
];

const homeSizes = <String>[
  '1 RK',
  '1 BHK',
  '2 BHK',
  '3 BHK',
  'Villa',
  'A few items',
];

ServiceKind? serviceKindFromWire(String? value) {
  return switch (value) {
    'packers_movers' => ServiceKind.packersMovers,
    'cleaning' => ServiceKind.cleaning,
    'painting' => ServiceKind.painting,
    'ac_repair' => ServiceKind.acRepair,
    'plumbing' => ServiceKind.plumbing,
    'electrician' => ServiceKind.electrician,
    'carpentry' => ServiceKind.carpentry,
    _ => null,
  };
}

extension ServiceKindWire on ServiceKind {
  String get wire => switch (this) {
    ServiceKind.packersMovers => 'packers_movers',
    ServiceKind.cleaning => 'cleaning',
    ServiceKind.painting => 'painting',
    ServiceKind.acRepair => 'ac_repair',
    ServiceKind.plumbing => 'plumbing',
    ServiceKind.electrician => 'electrician',
    ServiceKind.carpentry => 'carpentry',
  };

  String get label => switch (this) {
    ServiceKind.packersMovers => 'Packers and movers',
    ServiceKind.cleaning => 'Cleaning',
    ServiceKind.painting => 'Painting',
    ServiceKind.acRepair => 'AC repair',
    ServiceKind.plumbing => 'Plumbing',
    ServiceKind.electrician => 'Electrician',
    ServiceKind.carpentry => 'Carpentry',
  };

  bool get asksForDestination => this == ServiceKind.packersMovers;
}

class ServiceLeadDraft {
  const ServiceLeadDraft({
    required this.kind,
    required this.fromLocality,
    required this.city,
    required this.requestedOn,
    required this.contactConsent,
    this.toLocality,
    this.homeSize,
    this.notes,
  });

  final ServiceKind kind;
  final String fromLocality;
  final String? toLocality;
  final String city;
  final DateTime requestedOn;
  final String? homeSize;
  final String? notes;
  final bool contactConsent;
}

String? validateServiceLead(ServiceLeadDraft draft) {
  if (!draft.contactConsent) {
    return 'Confirm that a HOMIZI partner may contact you.';
  }
  if (!serviceCities.contains(draft.city)) {
    return 'Choose a city.';
  }
  final from = draft.fromLocality.trim();
  if (from.length < 2 || from.length > 80) {
    return 'Enter the locality you are starting from.';
  }
  if (draft.kind.asksForDestination) {
    final to = draft.toLocality?.trim() ?? '';
    if (to.length < 2 || to.length > 80) {
      return 'Enter the locality you are moving to.';
    }
  }
  final notes = draft.notes?.trim() ?? '';
  if (notes.length > 1000) {
    return 'Keep the note under 1000 characters.';
  }
  if (notes.contains('@') || RegExp(r'\d{10}').hasMatch(notes)) {
    return 'Leave phone numbers and email addresses out of the note. HOMIZI uses the contact already on your account.';
  }
  final today = DateTime.now();
  final day = DateTime(
    draft.requestedOn.year,
    draft.requestedOn.month,
    draft.requestedOn.day,
  );
  final start = DateTime(today.year, today.month, today.day);
  if (day.isBefore(start)) {
    return 'Choose today or a later date.';
  }
  return null;
}

class ServiceLead {
  const ServiceLead({
    required this.id,
    required this.kind,
    required this.fromLocality,
    required this.city,
    required this.requestedOn,
    required this.status,
    this.toLocality,
    this.homeSize,
    this.notes,
  });

  final String id;
  final ServiceKind kind;
  final String fromLocality;
  final String? toLocality;
  final String city;
  final DateTime requestedOn;
  final String? homeSize;
  final String? notes;
  final String status;

  String get statusLabel => switch (status) {
    'contacted' => 'Contacted',
    'closed' => 'Closed',
    _ => 'Requested',
  };
}

const serviceLeadStatuses = <String>['requested', 'contacted', 'closed'];
