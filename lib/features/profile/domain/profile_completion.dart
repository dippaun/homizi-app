/// Fields that count toward the profile meter. Contact details are not included.
class CompletionInput {
  const CompletionInput({
    required this.displayName,
    required this.occupation,
    required this.bio,
    required this.hasBudget,
    required this.hasLocality,
    required this.hasRole,
  });

  final String displayName;
  final String occupation;
  final String bio;
  final bool hasBudget;
  final bool hasLocality;
  final bool hasRole;
}

class CompletionScore {
  const CompletionScore({required this.filled, required this.total});

  final int filled;
  final int total;

  double get fraction => total == 0 ? 0 : filled / total;

  int get percent => (fraction * 100).round();
}

CompletionScore profileCompletion(CompletionInput input) {
  final checks = <bool>[
    input.displayName.trim().length >= 2,
    input.occupation.trim().isNotEmpty,
    input.bio.trim().length >= 20,
    input.hasBudget,
    input.hasLocality,
    input.hasRole,
  ];
  return CompletionScore(
    filled: checks.where((item) => item).length,
    total: checks.length,
  );
}

/// Two letters when the name has two parts, otherwise one. Empty becomes H.
String profileInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'H';
  }
  String first(String word) {
    final iterator = word.runes.iterator;
    if (!iterator.moveNext()) {
      return '';
    }
    return String.fromCharCode(iterator.current).toUpperCase();
  }

  if (parts.length == 1) {
    return first(parts.first);
  }
  return '${first(parts.first)}${first(parts.last)}';
}
