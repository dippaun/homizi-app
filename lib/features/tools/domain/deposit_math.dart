class DepositDeduction {
  const DepositDeduction({
    required this.id,
    required this.label,
    required this.amountInr,
  });

  final String id;
  final String label;
  final int amountInr;
}

int deductionTotal(Iterable<int> amounts) {
  var total = 0;
  for (final amount in amounts) {
    if (amount < 0) {
      throw ArgumentError('A deduction cannot be negative.');
    }
    total += amount;
  }
  return total;
}

/// Refund still due after deductions. Never negative.
int refundDueInr(int depositPaidInr, int deductionsInr) {
  if (depositPaidInr < 0) {
    throw ArgumentError('Deposit cannot be negative.');
  }
  final due = depositPaidInr - deductionsInr;
  return due < 0 ? 0 : due;
}

bool deductionsExceedDeposit(int depositPaidInr, int deductionsInr) {
  return deductionsInr > depositPaidInr;
}
