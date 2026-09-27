import 'dart:convert';
import 'dart:io';

import 'package:iphone_duo_adapt/audit.dart';

const String _usage = '''
Find code that breaks on iPhone Duo and other foldables.

Usage: dart run iphone_duo_adapt:duo_audit [paths...] [options]

  paths                 Files or folders to scan (default: lib)
  --json                Print findings as JSON
  --fail-on=<level>     Exit 1 at or above: info, warning, error, none
                        (default: error)
  --rules               List rules and exit
  -h, --help            Show this help

Silence a line with   // duo-ignore: <rule-id>
Silence a file with   // duo-ignore-file: <rule-id>
''';

void main(List<String> args) {
  var json = false;
  var failOn = 'error';
  final paths = <String>[];
  for (final a in args) {
    if (a == '-h' || a == '--help') {
      stdout.write(_usage);
      return;
    } else if (a == '--json') {
      json = true;
    } else if (a == '--rules') {
      for (final r in duoRules) {
        stdout.writeln('${r.id.padRight(24)} ${r.severity.name.padRight(8)} '
            '${r.message}');
      }
      return;
    } else if (a.startsWith('--fail-on=')) {
      failOn = a.substring('--fail-on='.length);
    } else if (a.startsWith('-')) {
      stderr.writeln('Unknown option $a\n');
      stderr.write(_usage);
      exitCode = 64;
      return;
    } else {
      paths.add(a);
    }
  }
  if (paths.isEmpty) paths.add('lib');

  final auditor = DuoAuditor();
  final findings = <DuoFinding>[];
  var files = 0;
  for (final p in paths) {
    for (final f in _dartFiles(p)) {
      files++;
      findings.addAll(auditor.auditSource(f.path, f.readAsStringSync()));
    }
  }

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'files': files,
      'findings': findings.map((f) => f.toJson()).toList(),
    }));
  } else {
    for (final f in findings) {
      stdout.writeln(f);
    }
    final counts = <DuoSeverity, int>{
      for (final s in DuoSeverity.values)
        s: findings.where((f) => f.rule.severity == s).length,
    };
    stdout.writeln('\nScanned $files Dart files: '
        '${counts[DuoSeverity.error]} errors, '
        '${counts[DuoSeverity.warning]} warnings, '
        '${counts[DuoSeverity.info]} hints.');
  }

  final threshold = switch (failOn) {
    'info' => DuoSeverity.info,
    'warning' => DuoSeverity.warning,
    'error' => DuoSeverity.error,
    _ => null,
  };
  if (threshold != null &&
      findings.any((f) => f.rule.severity.index >= threshold.index)) {
    exitCode = 1;
  }
}

Iterable<File> _dartFiles(String path) sync* {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.file) {
    if (path.endsWith('.dart')) yield File(path);
    return;
  }
  if (type != FileSystemEntityType.directory) {
    stderr.writeln('Skipping $path: not found');
    return;
  }
  final entries = Directory(path).listSync(recursive: true)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final e in entries) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final p = e.path;
    if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) continue;
    if (p.contains('/.dart_tool/') || p.contains('/build/')) continue;
    yield e;
  }
}
