/// A snapped numeric range. [start] is never greater than [end].
class OrderedRange {
  const OrderedRange(this.start, this.end);

  final int start;
  final int end;
}

/// Rent and budget scale shared by profile, requirements, and filters.
abstract final class InrRangeScale {
  static const min = 0;
  static const max = 150000;
  static const step = 1000;

  /// Shown when a person has not saved a budget yet.
  static const presetMin = 12000;
  static const presetMax = 35000;
}

/// Built-up area filter. The ends mean "any".
abstract final class AreaRangeScale {
  static const min = 0;
  static const max = 4000;
  static const step = 100;
}

/// Floor filter. The ends mean "any".
abstract final class FloorRangeScale {
  static const min = 0;
  static const max = 20;
  static const step = 1;
}

int clampInt(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

/// Moves [value] onto the nearest [step] inside `[min, max]`.
int snapToStep(
  int value, {
  required int min,
  required int max,
  required int step,
}) {
  final bounded = clampInt(value, min, max);
  if (step <= 1) {
    return bounded;
  }
  final steps = ((bounded - min) / step).round();
  return clampInt(min + steps * step, min, max);
}

/// Snaps both ends and swaps them when the minimum would pass the maximum.
OrderedRange orderRange({
  required int start,
  required int end,
  required int min,
  required int max,
  required int step,
}) {
  var lo = snapToStep(start, min: min, max: max, step: step);
  var hi = snapToStep(end, min: min, max: max, step: step);
  if (lo > hi) {
    final swap = lo;
    lo = hi;
    hi = swap;
  }
  return OrderedRange(lo, hi);
}

/// Keeps a saved pair inside the scale without snapping, so a stored
/// value such as 9,999 still displays until the user drags.
OrderedRange clampOrdered({
  required int? start,
  required int? end,
  required int min,
  required int max,
  required int fallbackStart,
  required int fallbackEnd,
}) {
  var lo = clampInt(start ?? fallbackStart, min, max);
  var hi = clampInt(end ?? fallbackEnd, min, max);
  if (lo > hi) {
    final swap = lo;
    lo = hi;
    hi = swap;
  }
  return OrderedRange(lo, hi);
}

/// Null at an end means that side is open ("any").
({int? start, int? end}) openBounds({
  required int start,
  required int end,
  required int min,
  required int max,
}) {
  final ordered = start <= end
      ? OrderedRange(start, end)
      : OrderedRange(end, start);
  return (
    start: ordered.start <= min ? null : ordered.start,
    end: ordered.end >= max ? null : ordered.end,
  );
}

/// Live caption. Uses an en dash with spaces, for example ₹12,000 – ₹35,000.
String orderedRangeLabel({
  required int start,
  required int end,
  required int min,
  required int max,
  required String Function(int value) format,
  bool openAtBounds = false,
}) {
  final lo = start <= end ? start : end;
  final hi = start <= end ? end : start;
  final openMin = openAtBounds && lo <= min;
  final openMax = openAtBounds && hi >= max;
  if (openMin && openMax) {
    return 'Any';
  }
  if (openMin) {
    return 'Up to ${format(hi)}';
  }
  if (openMax) {
    return '${format(lo)} and above';
  }
  if (lo == hi) {
    return format(lo);
  }
  return '${format(lo)} – ${format(hi)}';
}

/// True when a tenant budget overlaps the owner's selected range.
/// A missing tenant budget matches only while the filter is fully open.
bool budgetOverlaps({
  required int? min,
  required int? max,
  required int? filterMin,
  required int? filterMax,
}) {
  if (filterMin == null && filterMax == null) {
    return true;
  }
  if (min == null && max == null) {
    return false;
  }
  final lo = min ?? 0;
  final hi = max ?? 1 << 30;
  final filterLo = filterMin ?? 0;
  final filterHi = filterMax ?? 1 << 30;
  return lo <= filterHi && hi >= filterLo;
}
