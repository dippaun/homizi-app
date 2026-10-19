class SeekerMatch {
  const SeekerMatch({
    required this.requirementId,
    required this.displayName,
    required this.city,
    required this.localities,
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.roomType,
    required this.seekerKind,
    required this.aboutMe,
    required this.profession,
    required this.matchPercent,
    this.listingTitle = '',
  });

  final String requirementId;
  final String displayName;
  final String city;
  final List<String> localities;
  final int budgetMinInr;
  final int budgetMaxInr;
  final String roomType;
  final String seekerKind;
  final String aboutMe;
  final String profession;
  final int matchPercent;
  final String listingTitle;
}

class SeekerMatchPage {
  const SeekerMatchPage({required this.seekers, required this.basis});

  final List<SeekerMatch> seekers;
  final String basis;
}

abstract interface class SeekerMatchGateway {
  Future<SeekerMatchPage> load();
}
