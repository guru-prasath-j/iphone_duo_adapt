/// Static checks for code that breaks on iPhone Duo and other foldables.
///
/// Pure Dart (no Flutter import) so it runs from the command line with
/// `dart run iphone_duo_adapt:duo_audit`.
library;

/// How serious a finding is.
enum DuoSeverity {
  /// A hint: fine today, worth adapting.
  info,

  /// Likely to look wrong on a foldable.
  warning,

  /// Very likely broken on a foldable.
  error,
}

/// One check.
class DuoRule {
  /// Creates a rule.
  const DuoRule({
    required this.id,
    required this.severity,
    required this.pattern,
    required this.message,
    required this.fix,
  });

  /// Stable identifier, usable in `// duo-ignore: <id>` comments.
  final String id;

  /// Severity.
  final DuoSeverity severity;

  /// Regular expression matched against each line of code.
  final RegExp pattern;

  /// What is wrong.
  final String message;

  /// How to fix it.
  final String fix;
}

/// A match of a [DuoRule] in a file.
class DuoFinding {
  /// Creates a finding.
  const DuoFinding({
    required this.rule,
    required this.path,
    required this.line,
    required this.column,
    required this.source,
  });

  /// Rule that matched.
  final DuoRule rule;

  /// File path as given to the auditor.
  final String path;

  /// 1-based line.
  final int line;

  /// 1-based column.
  final int column;

  /// The trimmed source line.
  final String source;

  /// JSON form for tooling.
  Map<String, Object> toJson() => <String, Object>{
        'rule': rule.id,
        'severity': rule.severity.name,
        'path': path,
        'line': line,
        'column': column,
        'message': rule.message,
        'fix': rule.fix,
        'source': source,
      };

  @override
  String toString() =>
      '$path:$line:$column ${rule.severity.name} [${rule.id}] '
      '${rule.message}\n    fix: ${rule.fix}';
}

/// The built-in rules.
final List<DuoRule> duoRules = <DuoRule>[
  DuoRule(
    id: 'orientation-lock',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'setPreferredOrientations\s*\('),
    message: 'Orientation lock. The iPhone Duo inner display does not honour '
        'supported orientations, so the app will be shown in orientations '
        'it was locked out of.',
    fix: 'Make the layout work at any aspect ratio, or limit the lock to '
        'compact widths only.',
  ),
  DuoRule(
    id: 'orientation-branch',
    severity: DuoSeverity.info,
    pattern: RegExp(r'\borientationOf\s*\(|\.orientation\b|'
        r'\bOrientation\.(portrait|landscape)\b|\bOrientationBuilder\s*\('),
    message: 'Layout chosen by orientation. The unfolded Duo is nearly square '
        'and can be "portrait" while having tablet width.',
    fix: 'Branch on available width (LayoutBuilder, MediaQuery.sizeOf, or '
        'DuoLayoutInfo.of(context).widthClass).',
  ),
  DuoRule(
    id: 'physical-size',
    severity: DuoSeverity.error,
    pattern: RegExp(r'\bphysicalSize\b|\bwindow\.(physicalSize|devicePixelRatio)|'
        r'\bviews\.first\b|\bWidgetsBinding\.instance\.window\b'),
    message: 'Reads the raw screen. On a foldable the screen changes size at '
        'runtime (466 pt closed to 890 pt open), and a cached value goes stale.',
    fix: 'Use MediaQuery.sizeOf(context) or LayoutBuilder so the widget '
        'rebuilds when the device folds.',
  ),
  DuoRule(
    id: 'device-width-constant',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'(width|Width|shortestSide)\s*(==|!=|<=|>=|<|>)\s*'
        r'(320|375|390|393|402|414|428|430|440)(\.0)?\b'),
    message: 'Compares against a specific iPhone width. The Duo introduces '
        'two new widths and a near-square shape.',
    fix: 'Use a breakpoint range (for example 600 for tablet-like layouts) '
        'instead of exact device sizes.',
  ),
  DuoRule(
    id: 'bottom-bar',
    severity: DuoSeverity.info,
    pattern: RegExp(r'\b(BottomNavigationBar|NavigationBar|CupertinoTabBar)\s*\('),
    message: 'Bottom navigation bar. On the unfolded Duo, iOS 27.1 moves tab '
        'bars to a vertical side bar.',
    fix: 'Wrap the Scaffold in DuoAdaptiveScaffold(scaffold: ...) to move '
        'this bar to a NavigationRail on wide screens.',
  ),
  DuoRule(
    id: 'cupertino-tab-scaffold',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'\bCupertinoTabScaffold\s*\('),
    message: 'CupertinoTabScaffold always draws its tab bar at the bottom.',
    fix: 'Switch to a Scaffold with a bottom bar wrapped in '
        'DuoAdaptiveScaffold, or build a rail for wide widths.',
  ),
  DuoRule(
    id: 'first-camera',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'\bcameras\s*(\.first\b|\[\s*[01]\s*\])'),
    message: 'Picks a camera by position in the list. The Duo has outer, '
        'inner and rear cameras and which one faces the user depends on '
        'fold state.',
    fix: 'Select by CameraDescription.lensDirection and re-select when the '
        'device folds or unfolds.',
  ),
  DuoRule(
    id: 'static-screen-size',
    severity: DuoSeverity.error,
    pattern: RegExp(r'\b(static|late\s+final|final)\s+[\w<>?]*\s*\w+\s*=\s*'
        r'MediaQuery\.(of\s*\([^)]*\)\.size|sizeOf\s*\()'),
    message: 'Stores the screen size in a field. It will not update when the '
        'device folds or unfolds.',
    fix: 'Read MediaQuery.sizeOf(context) inside build instead of caching it.',
  ),
];

/// Runs [rules] over Dart source files.
class DuoAuditor {
  /// Creates an auditor.
  DuoAuditor({List<DuoRule>? rules}) : rules = rules ?? duoRules;

  /// Rules to apply.
  final List<DuoRule> rules;

  static final RegExp _ignore = RegExp(r'//\s*duo-ignore:\s*([\w\-, ]+)');
  static final RegExp _ignoreFile =
      RegExp(r'//\s*duo-ignore-file:\s*([\w\-, ]+)');

  /// Audits one file's [source] and returns findings.
  List<DuoFinding> auditSource(String path, String source) {
    final lines = source.split('\n');
    final fileIgnores = <String>{};
    for (final m in _ignoreFile.allMatches(source)) {
      fileIgnores.addAll(_ids(m.group(1)!));
    }
    final findings = <DuoFinding>[];
    var inBlockComment = false;
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final code = _stripComments(raw, inBlockComment, (v) => inBlockComment = v);
      if (code.trim().isEmpty) continue;
      final lineIgnores = <String>{...fileIgnores};
      final here = _ignore.firstMatch(raw);
      if (here != null) lineIgnores.addAll(_ids(here.group(1)!));
      if (i > 0) {
        final above = _ignore.firstMatch(lines[i - 1]);
        if (above != null && lines[i - 1].trim().startsWith('//')) {
          lineIgnores.addAll(_ids(above.group(1)!));
        }
      }
      for (final rule in rules) {
        if (lineIgnores.contains(rule.id) || lineIgnores.contains('all')) {
          continue;
        }
        final m = rule.pattern.firstMatch(code);
        if (m == null) continue;
        findings.add(DuoFinding(
          rule: rule,
          path: path,
          line: i + 1,
          column: m.start + 1,
          source: raw.trim(),
        ));
      }
    }
    return findings;
  }

  static Iterable<String> _ids(String s) =>
      s.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty);

  /// Removes `//` and `/* */` comments and string contents from a line so
  /// that rules only see code. Removed text becomes spaces so columns stay
  /// accurate. Tracks block comments across lines.
  static String _stripComments(
    String line,
    bool inBlock,
    void Function(bool) setInBlock,
  ) {
    final out = StringBuffer();
    var i = 0;
    var block = inBlock;
    String? quote;
    while (i < line.length) {
      final c = line[i];
      final next = i + 1 < line.length ? line[i + 1] : '';
      if (block) {
        if (c == '*' && next == '/') {
          block = false;
          out.write('  ');
          i += 2;
          continue;
        }
        out.write(' ');
        i++;
        continue;
      }
      if (quote != null) {
        if (c == r'\') {
          out.write(next.isEmpty ? ' ' : '  ');
          i += 2;
          continue;
        }
        out.write(c == quote ? c : ' ');
        if (c == quote) quote = null;
        i++;
        continue;
      }
      if (c == '/' && next == '/') break;
      if (c == '/' && next == '*') {
        block = true;
        out.write('  ');
        i += 2;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        out.write(c);
        i++;
        continue;
      }
      out.write(c);
      i++;
    }
    setInBlock(block);
    return out.toString();
  }
}
