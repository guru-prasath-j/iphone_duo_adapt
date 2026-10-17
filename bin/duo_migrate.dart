import 'dart:convert';
import 'dart:io';

import 'package:flutter_iphone_duo_adapt/migrate.dart';

const String _usage = '''
Retrofit an existing Flutter app for iPhone Duo.

Usage: dart run flutter_iphone_duo_adapt:duo_migrate [paths...] [options]

Shows what it would change by default. Nothing is written without --apply.

Steps (all by default):
  app-builder     Add builder: DuoAdapt.builder() to MaterialApp /
                  CupertinoApp / WidgetsApp (keeps an existing builder)
  scaffold        Wrap Scaffolds that have a bottomNavigationBar in
                  DuoAdaptiveScaffold
  cupertino-tabs  CupertinoTabScaffold -> DuoCupertinoTabScaffold

Options:
  --apply             Write the changes
  --only=<a,b>        Run only these steps
  --skip=<a,b>        Skip these steps
  --json              Machine-readable output (for CI and AI agents)
  -h, --help          Show this help

Afterwards: dart format lib && flutter analyze && flutter test
''';

void main(List<String> args) {
  var apply = false;
  var json = false;
  Set<DuoMigrationStep>? only;
  final skip = <DuoMigrationStep>{};
  final paths = <String>[];

  Set<DuoMigrationStep>? parseSteps(String list) {
    final out = <DuoMigrationStep>{};
    final ids = list.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final id in ids) {
      final step = DuoMigrationStep.byId(id);
      if (step == null) {
        stderr.writeln('Unknown step "$id". Steps: '
            '${DuoMigrationStep.values.map((s) => s.id).join(', ')}');
        return null;
      }
      out.add(step);
    }
    return out;
  }

  for (final a in args) {
    if (a == '-h' || a == '--help') {
      stdout.write(_usage);
      return;
    } else if (a == '--apply') {
      apply = true;
    } else if (a == '--json') {
      json = true;
    } else if (a.startsWith('--only=')) {
      only = parseSteps(a.substring(7));
      if (only == null) {
        exitCode = 64;
        return;
      }
    } else if (a.startsWith('--skip=')) {
      final s = parseSteps(a.substring(7));
      if (s == null) {
        exitCode = 64;
        return;
      }
      skip.addAll(s);
    } else if (a.startsWith('-')) {
      stderr
        ..writeln('Unknown option $a\n')
        ..write(_usage);
      exitCode = 64;
      return;
    } else {
      paths.add(a);
    }
  }
  if (paths.isEmpty) paths.add('lib');

  final steps = (only ?? DuoMigrationStep.values.toSet()).difference(skip);
  final migrator = DuoMigrator(steps: steps);
  final results = <DuoMigrationResult>[];
  for (final p in paths) {
    for (final f in _dartFiles(p)) {
      final r = migrator.migrate(f.path, f.readAsStringSync());
      if (r.changed) {
        results.add(r);
        if (apply) f.writeAsStringSync(r.migrated);
      }
    }
  }

  final pubspec = File('pubspec.yaml');
  final hasDependency = pubspec.existsSync() &&
      RegExp(r'^\s+flutter_iphone_duo_adapt\s*:', multiLine: true)
          .hasMatch(pubspec.readAsStringSync());

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'schema': 'iphone_duo_adapt/migrate@1',
      'applied': apply,
      'steps': steps.map((s) => s.id).toList(),
      'dependencyInPubspec': hasDependency,
      'files': results.map((r) => r.toJson()).toList(),
    }));
    return;
  }

  if (results.isEmpty) {
    stdout.writeln('Nothing to change.');
  }
  for (final r in results) {
    stdout.writeln(r.path);
    for (final e in r.edits) {
      stdout.writeln('  line ${e.line}: ${e.description}');
    }
    if (!apply) _diff(r.original, r.migrated);
    stdout.writeln();
  }
  if (!hasDependency) {
    stdout.writeln('Add the package first: flutter pub add flutter_iphone_duo_adapt');
  }
  if (results.isNotEmpty) {
    stdout.writeln(apply
        ? 'Changed ${results.length} files. Now run: dart format lib && '
            'flutter analyze && flutter test'
        : 'Dry run. Re-run with --apply to write these changes.');
  }
}

// Prints changed lines. Enough to review a migration; use git diff for more.
void _diff(String a, String b) {
  final x = a.split('\n');
  final y = b.split('\n');
  var i = 0;
  var j = 0;
  while (i < x.length || j < y.length) {
    if (i < x.length && j < y.length && x[i] == y[j]) {
      i++;
      j++;
      continue;
    }
    // Look ahead for a resync point.
    var synced = false;
    for (var k = 1; k <= 3 && !synced; k++) {
      if (j + k < y.length && i < x.length && x[i] == y[j + k]) {
        for (var n = 0; n < k; n++) {
          stdout.writeln('  + ${y[j + n]}');
        }
        j += k;
        synced = true;
      } else if (i + k < x.length && j < y.length && x[i + k] == y[j]) {
        for (var n = 0; n < k; n++) {
          stdout.writeln('  - ${x[i + n]}');
        }
        i += k;
        synced = true;
      }
    }
    if (synced) continue;
    if (i < x.length) stdout.writeln('  - ${x[i++]}');
    if (j < y.length) stdout.writeln('  + ${y[j++]}');
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
    final p = e.path.replaceAll(r'\', '/');
    if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) continue;
    if (p.contains('/.dart_tool/') || p.contains('/build/')) continue;
    yield e;
  }
}
