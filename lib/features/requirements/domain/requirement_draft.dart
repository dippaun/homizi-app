class RequirementDraft {
  const RequirementDraft({
    this.budgetMinInr,
    this.budgetMaxInr,
    this.city = '',
    this.locality = '',
    this.moveInDate,
    this.occupancy = 1,
  });

  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String city;
  final String locality;
  final DateTime? moveInDate;
  final int occupancy;

  List<String> errors({required DateTime today}) {
    final issues = <String>[];
    if (city.trim().isEmpty) {
      issues.add('Choose a city.');
    }
    if (locality.trim().isEmpty) {
      issues.add('Add at least one locality.');
    }
    if (budgetMinInr == null || budgetMinInr! <= 0) {
      issues.add('Enter a minimum budget.');
    }
    if (budgetMaxInr == null || budgetMaxInr! <= 0) {
      issues.add('Enter a maximum budget.');
    }
    if (budgetMinInr != null &&
        budgetMaxInr != null &&
        budgetMinInr! > budgetMaxInr!) {
      issues.add('Minimum budget cannot exceed the maximum.');
    }
    if (occupancy < 1 || occupancy > 20) {
      issues.add('Occupancy must be between 1 and 20.');
    }
    if (moveInDate != null) {
      final day = DateTime(today.year, today.month, today.day);
      final move = DateTime(
        moveInDate!.year,
        moveInDate!.month,
        moveInDate!.day,
      );
      if (move.isBefore(day)) {
        issues.add('Move-in date cannot be in the past.');
      }
    }
    return issues;
  }
}
