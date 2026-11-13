/// Explainable match.
///
/// [percent] is 0–100. [topReasons] has at most five lines. [missing] lists
/// what did not fit, hard misses first.
class MatchResult {
  const MatchResult({
    required this.percent,
    required this.topReasons,
    required this.missing,
  });

  final int percent;
  final List<String> topReasons;
  final List<String> missing;
}
