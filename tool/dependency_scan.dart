// Checks the lockfile for unlocked sources. Does not call a vulnerability feed.
// Usage: dart run tool/dependency_scan.dart

import 'dart:io';

Future<void> main() async {
  final lock = File('pubspec.lock');
  if (!lock.existsSync()) {
    stderr.writeln('pubspec.lock is missing. Run flutter pub get.');
    exitCode = 1;
    return;
  }
  final text = lock.readAsStringSync();
  final git = RegExp(r'^\s*source:\s+git\s*$', multiLine: true);
  final path = RegExp(r'^\s*source:\s+path\s*$', multiLine: true);
  if (git.hasMatch(text) || path.hasMatch(text)) {
    stderr.writeln(
      'Dependency scan failed. pubspec.lock uses a git or path source.',
    );
    exitCode = 1;
    return;
  }
  final packages = RegExp(
    r'^  ([A-Za-z0-9_]+):\n(?:    .*\n)*?    version:\s+"([^"]+)"',
    multiLine: true,
  ).allMatches(text);
  final names = packages.map((match) => match.group(1)!).toList()..sort();
  stdout.writeln(
    'dependency scan passed (${names.length} locked hosted packages)',
  );
}
