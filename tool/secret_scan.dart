// Fails when a committed file looks like a secret.
// Usage: dart run tool/secret_scan.dart

import 'dart:io';

import 'package:homizi/core/security/secret_rules.dart';

const _skipDirs = {
  '.git',
  '.dart_tool',
  '.temp',
  'build',
  'uploads',
  'agent-tools',
  'Pods',
  '.gradle',
};

const _skipFiles = {
  'lib/core/security/secret_rules.dart',
  'test/core/security/secret_rules_test.dart',
};

const _skipExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.jar',
  '.apk',
  '.so',
};

Future<void> main() async {
  final root = Directory.current;
  final findings = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = entity.path.startsWith(root.path)
        ? entity.path.substring(root.path.length + 1)
        : entity.path;
    if (_skipped(relative)) {
      continue;
    }
    final bytes = await entity.length();
    if (bytes > 1000000) {
      continue;
    }
    late final String contents;
    try {
      contents = await entity.readAsString();
    } on FileSystemException {
      continue;
    } on FormatException {
      continue;
    }
    for (final rule in secretRuleHits(contents)) {
      findings.add('$relative ($rule)');
    }
  }
  if (findings.isNotEmpty) {
    stderr.writeln('Secret scan found ${findings.length} hit(s):');
    for (final finding in findings) {
      stderr.writeln(finding);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('secret scan passed');
}

bool _skipped(String relative) {
  final parts = relative.split(RegExp(r'[/\\]'));
  final normalized = relative.replaceAll('\\', '/');
  if (_skipFiles.contains(normalized)) {
    return true;
  }
  if (parts.any(_skipDirs.contains)) {
    return true;
  }
  final dot = relative.lastIndexOf('.');
  if (dot != -1 && _skipExtensions.contains(relative.substring(dot))) {
    return true;
  }
  return false;
}
