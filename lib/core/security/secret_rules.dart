/// Finds committed secrets. A hit is a rule name, never the secret itself.
List<String> secretRuleHits(String contents) {
  final hits = <String>[];
  if (contents.contains('-----BEGIN PRIVATE KEY-----') ||
      contents.contains('-----BEGIN RSA PRIVATE KEY-----') ||
      contents.contains('-----BEGIN OPENSSH PRIVATE KEY-----')) {
    hits.add('private-key');
  }
  if (RegExp(r'sk_live_[A-Za-z0-9]').hasMatch(contents) ||
      RegExp(r'rk_live_[A-Za-z0-9]').hasMatch(contents)) {
    hits.add('live-secret-key');
  }
  if (RegExp(r'AKIA[0-9A-Z]{16}').hasMatch(contents)) {
    hits.add('aws-access-key');
  }
  if (RegExp(
    r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
  ).hasMatch(contents)) {
    hits.add('jwt');
  }
  final assigned = RegExp(
    r'(?:^|[^A-Za-z0-9_])(service_role_key|secret_key)\s*[:=]\s*(\S+)',
    caseSensitive: false,
  );
  for (final match in assigned.allMatches(contents)) {
    final value = match.group(2) ?? '';
    if (value.isEmpty ||
        value == '""' ||
        value == "''" ||
        value.startsWith('your-') ||
        value.contains('example') ||
        value.contains('env(')) {
      continue;
    }
    hits.add('assigned-secret');
    break;
  }
  return hits;
}
