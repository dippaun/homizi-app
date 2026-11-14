/// Splits [total] whole points across [exact] shares so the parts always add
/// up to [total] (largest remainder). Used so every match breakdown sums to
/// the headline percent the card and the detail screen both show.
List<int> apportionPoints(List<double> exact, int total) {
  if (exact.isEmpty) {
    return const [];
  }
  final sum = exact.fold<double>(0, (a, b) => a + (b < 0 ? 0 : b));
  if (sum <= 0 || total <= 0) {
    return List<int>.filled(exact.length, 0);
  }
  final scaled = [for (final e in exact) (e < 0 ? 0 : e) * total / sum];
  final parts = [for (final s in scaled) s.floor()];
  var left = total - parts.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(exact.length, (i) => i)
    ..sort((a, b) {
      final byRest = (scaled[b] - parts[b]).compareTo(scaled[a] - parts[a]);
      return byRest != 0 ? byRest : a.compareTo(b);
    });
  for (final i in order) {
    if (left <= 0) {
      break;
    }
    parts[i] += 1;
    left -= 1;
  }
  return parts;
}
