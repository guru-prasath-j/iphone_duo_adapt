import 'dart:convert';
import 'dart:io';

import 'package:flutter_iphone_duo_adapt/audit.dart';

const String _usage = '''
Find code and settings that break on iPhone Duo and other foldables.

Usage: dart run flutter_iphone_duo_adapt:duo_audit [paths...] [options]

Run it in your app's root folder. It scans lib/ (or the paths you give),
native iOS sources, ios/Runner/Info.plist and the Android manifest.

  --format=<f>          text (default), json, markdown, github
  --json                Same as --format=json
  --fail-on=<level>     Exit 1 at or above: info, warning, error, none
                        (default: error)
  --config=<file>       Settings file (default: iphone_duo_adapt.yaml)
  --rules               List rules and exit
  --checklist           Print the manual test checklist and exit
  -h, --help            Show this help

Silence a line with   // duo-ignore: <rule-id>
Silence a file with   // duo-ignore-file: <rule-id>
Fix automatically     dart run flutter_iphone_duo_adapt:duo_migrate
''';

void main(List<String> args) {
  var format = 'text';
  var failOn = 'error';
  String? configPath;
  final paths = <String>[];
  for (final a in args) {
    if (a == '-h' || a == '--help') {
      stdout.write(_usage);
      return;
    } else if (a == '--json') {
      format = 'json';
    } else if (a.startsWith('--format=')) {
      format = a.substring('--format='.length);
    } else if (a.startsWith('--fail-on=')) {
      failOn = a.substring('--fail-on='.length);
    } else if (a.startsWith('--config=')) {
      configPath = a.substring('--config='.length);
    } else if (a == '--rules') {
      for (final r in duoRules) {
        stdout.writeln(
          '${r.id.padRight(26)} ${r.severity.name.padRight(8)} '
          '${r.kind.name.padRight(16)} ${r.message}',
        );
      }
      for (final r in duoProjectRules) {
        stdout.writeln(
          '${r.id.padRight(26)} ${r.severity.name.padRight(8)} '
          '${'project'.padRight(16)} ${r.message}',
        );
      }
      return;
    } else if (a == '--checklist') {
      stdout.writeln('Manual iPhone Duo checks (a scan cannot see these):\n');
      for (final c in duoManualChecklist) {
        stdout.writeln('[ ] ${c['id']}: ${c['check']}');
      }
      return;
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

  var config = const DuoAuditConfig();
  final cfgFile = File(configPath ?? 'iphone_duo_adapt.yaml');
  if (cfgFile.existsSync()) {
    try {
      config = DuoAuditConfig.fromYaml(cfgFile.readAsStringSync());
    } on FormatException catch (e) {
      stderr.writeln('Bad config ${cfgFile.path}: ${e.message}');
      exitCode = 64;
      return;
    }
  } else if (configPath != null) {
    stderr.writeln('Config file not found: $configPath');
    exitCode = 64;
    return;
  }

  final auditor = DuoAuditor(config: config);
  final report = auditor.auditProject(
    Directory.current.path,
    dartPaths: paths.isEmpty ? null : paths,
  );

  switch (format) {
    case 'json':
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(report.toJson()),
      );
    case 'markdown':
      _markdown(report);
    case 'github':
      for (final f in report.findings) {
        final level = switch (f.rule.severity) {
          DuoSeverity.error => 'error',
          DuoSeverity.warning => 'warning',
          DuoSeverity.info => 'notice',
        };
        stdout.writeln(
          '::$level file=${f.path},line=${f.line},'
          'col=${f.column},title=${f.rule.id}::'
          '${f.rule.message} Fix: ${f.rule.fix}',
        );
      }
    default:
      for (final f in report.findings) {
        stdout
          ..writeln(f)
          ..writeln();
      }
      final c = report.counts;
      stdout.writeln(
        'Scanned ${report.files} files: '
        '${c[DuoSeverity.error]} errors, '
        '${c[DuoSeverity.warning]} warnings, '
        '${c[DuoSeverity.info]} hints.',
      );
      if (report.findings.any((f) => f.rule.autofix != null)) {
        stdout.writeln(duoMigrateHint);
      }
      stdout.writeln('Also run with --checklist for what a scan cannot see.');
  }

  final threshold = switch (failOn) {
    'info' => DuoSeverity.info,
    'warning' => DuoSeverity.warning,
    'error' => DuoSeverity.error,
    _ => null,
  };
  if (threshold != null &&
      report.findings.any((f) => f.rule.severity.index >= threshold.index)) {
    exitCode = 1;
  }
}

void _markdown(DuoAuditReport report) {
  final c = report.counts;
  stdout
    ..writeln('# iPhone Duo audit')
    ..writeln()
    ..writeln(
      '${report.files} files · ${c[DuoSeverity.error]} errors · '
      '${c[DuoSeverity.warning]} warnings · ${c[DuoSeverity.info]} hints',
    )
    ..writeln()
    ..writeln('| Severity | Rule | Where | Fix |')
    ..writeln('|---|---|---|---|');
  for (final f in report.findings) {
    stdout.writeln(
      '| ${f.rule.severity.name} | `${f.rule.id}` | '
      '`${f.path}:${f.line}` | ${f.rule.fix.replaceAll('|', '\\|')} |',
    );
  }
  stdout
    ..writeln()
    ..writeln('## Manual checks')
    ..writeln();
  for (final item in duoManualChecklist) {
    stdout.writeln('- [ ] **${item['id']}**: ${item['check']}');
  }
}
