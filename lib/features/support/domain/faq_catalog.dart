class FaqEntry {
  const FaqEntry({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

const faqCategories = <String>[
  'all',
  'renting',
  'flatmates',
  'safety',
  'payments',
];

String faqCategoryLabel(String category) {
  return switch (category) {
    'renting' => 'Renting',
    'flatmates' => 'Flatmates',
    'safety' => 'Safety',
    'payments' => 'Payments',
    _ => 'All',
  };
}

const faqCatalog = <FaqEntry>[
  FaqEntry(
    category: 'safety',
    question: 'When can someone see my phone number?',
    answer:
        'Only after a mutual match, and only for the part you share. Share and stop sharing call grant_contact_consent and revoke_contact_consent. The app shows a phone or email only when get_contact_visibility returns one.',
  ),
  FaqEntry(
    category: 'safety',
    question: 'Is identity verification real?',
    answer:
        'No. The app exposes a mock interface. It does not collect Aadhaar, passport, or a face scan. A provider needs legal approval before any real check.',
  ),
  FaqEntry(
    category: 'safety',
    question: 'Can I send my phone number in chat?',
    answer:
        'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.',
  ),
  FaqEntry(
    category: 'renting',
    question: 'What can a notification include?',
    answer:
        'A match, a message, a visit, a listing like, or a deposit reminder. The row stores ids only. It never includes a phone number, an email address, or a street address. Marking one read updates that timestamp and nothing else.',
  ),
  FaqEntry(
    category: 'payments',
    question: 'Can I pay for a listing here?',
    answer:
        'Payments are not supported. There is no checkout, and the client cannot mark a plan as paid. HOMIZI does not collect rent, a deposit, or a fee.',
  ),
  FaqEntry(
    category: 'payments',
    question: 'Does a rent receipt move money?',
    answer:
        'No. The receipt tool writes down a payment you already made outside HOMIZI and saves it on your account so you can download the PDF again.',
  ),
  FaqEntry(
    category: 'renting',
    question: 'Is the rent agreement registered?',
    answer:
        'No. The agreement tool fills an 11-month leave-and-licence draft. The PDF says it is not stamped or registered. HOMIZI does not e-stamp or deliver a signed copy.',
  ),
  FaqEntry(
    category: 'flatmates',
    question: 'How does the rent split work?',
    answer:
        'Enter the rent, deposit, maintenance, and utilities, then a weight for each room. A larger room can take a higher weight. The shares add back to the amounts you entered. An optional income shows whether the household housing cost is comfortable, a stretch, or above a third of take-home.',
  ),
  FaqEntry(
    category: 'flatmates',
    question: 'Who can see a move-in checklist?',
    answer:
        'You can. If you link a match, the other person on that match can read the rooms, notes, and photos. They cannot edit them.',
  ),
  FaqEntry(
    category: 'safety',
    question: 'How do I report someone?',
    answer:
        'Open a listing or a chat and use the flag icon. The report is stored for your account. Blocking is recorded with it and stops messages and contact in both directions. A staff account can review the report. No one is named as moderator in this build.',
  ),
  FaqEntry(
    category: 'renting',
    question: 'How do I delete my account?',
    answer:
        'Settings has Delete account. On this device it clears the local profile. With the local server connected it removes the auth user, profile, listings, photos, messages, and the private contact row. It does not call a payment provider, an identity provider, or a production backup.',
  ),
];

const safetyTips = <String>[
  'Do not share an OTP, and do not move money before you have met or verified the home through a channel you trust.',
  'Meet in a public place first. A visit time in HOMIZI is not a street address.',
  'Keep the conversation in the match chat. The chat refuses a phone number or an email address.',
  'A deposit tracker only reminds you inside the app. It does not transfer money.',
];

List<FaqEntry> searchFaqs({required String query, required String category}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final entry in faqCatalog)
      if (category == 'all' || entry.category == category)
        if (needle.isEmpty ||
            entry.question.toLowerCase().contains(needle) ||
            entry.answer.toLowerCase().contains(needle))
          entry,
  ];
}

String? supportMessageError(String message) {
  final trimmed = message.trim();
  if (trimmed.length < 10 || trimmed.length > 1000) {
    return 'Write between 10 and 1000 characters.';
  }
  if (trimmed.contains('@') || RegExp(r'[0-9]{10}').hasMatch(trimmed)) {
    return 'Leave out phone numbers and email addresses.';
  }
  return null;
}
