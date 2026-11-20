/// User-facing form of a missing table or function. [isMissingRelation]
/// treats this sentence as that failure so sample fallback still runs
/// after the raw Postgres text has been hidden.
const unavailableYetMessage = 'This is not available yet.';

/// True when PostgREST or Postgres says the table or function is not there.
///
/// A permission denial is not a missing relation. The caller keeps the real
/// error so a signed-in person is not shown sample rows by mistake.
bool isMissingRelation(Object error) {
  final text = error.toString();
  if (text.contains(unavailableYetMessage)) {
    return true;
  }
  final lower = text.toLowerCase();
  if (lower.contains('pgrst205') || lower.contains('pgrst202')) {
    return true;
  }
  if (text.contains('42P01') || text.contains('42883')) {
    return true;
  }
  if (lower.contains('could not find the table') ||
      lower.contains('could not find the function') ||
      lower.contains('schema cache')) {
    return true;
  }
  return lower.contains('does not exist') &&
      (lower.contains('relation') ||
          lower.contains('function') ||
          lower.contains('table'));
}
