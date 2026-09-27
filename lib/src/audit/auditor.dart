/// Static checks for code and project settings that break on iPhone Duo and
/// other foldables.
///
/// Pure Dart (no Flutter import) so it runs from the command line with
/// `dart run iphone_duo_adapt:duo_audit`, and from your own tools.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

import '../tooling/dart_mask.dart';

/// How serious a finding is.
enum DuoSeverity {
  /// A hint: fine today, worth adapting.
  info,

  /// Likely to look wrong on a foldable.
  warning,

  /// Very likely broken on a foldable.
  error,
}

/// Kind of file a rule looks at.
enum DuoFileKind {
  /// `.dart`
  dart,

  /// `.swift`, `.m`, `.mm`, `.h` under `ios/`
  iosSource,

  /// `ios/Runner/Info.plist`
  infoPlist,

  /// `android/app/src/main/AndroidManifest.xml`
  androidManifest,
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
    this.kind = DuoFileKind.dart,
    this.matchInStrings = false,
    this.autofix,
  });

  /// Stable identifier, usable in `// duo-ignore: <id>` comments and the
  /// config file.
  final String id;

  /// Default severity (the config file can change it).
  final DuoSeverity severity;

  /// Regular expression matched against each line.
  final RegExp pattern;

  /// What is wrong.
  final String message;

  /// How to fix it.
  final String fix;

  /// Files this rule applies to.
  final DuoFileKind kind;

  /// Match inside string literals too (for user-facing text checks).
  /// Otherwise comments and strings are masked before matching.
  final bool matchInStrings;

  /// Name of the `duo_migrate` step that fixes this automatically, if any.
  final String? autofix;

  /// Copy with a different severity.
  DuoRule withSeverity(DuoSeverity s) => DuoRule(
        id: id,
        severity: s,
        pattern: pattern,
        message: message,
        fix: fix,
        kind: kind,
        matchInStrings: matchInStrings,
        autofix: autofix,
      );

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'severity': severity.name,
        'kind': kind.name,
        'message': message,
        'fix': fix,
        'autofix': autofix,
      };
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

  /// JSON form for tooling and AI agents.
  Map<String, Object?> toJson() => <String, Object?>{
        'rule': rule.id,
        'severity': rule.severity.name,
        'path': path,
        'line': line,
        'column': column,
        'message': rule.message,
        'fix': rule.fix,
        'autofix': rule.autofix,
        'source': source,
      };

  @override
  String toString() =>
      '$path:$line:$column ${rule.severity.name} [${rule.id}] '
      '${rule.message}\n    fix: ${rule.fix}'
      '${rule.autofix == null ? '' : '\n    auto: dart run iphone_duo_adapt:duo_migrate --only=${rule.autofix}'}';
}

const String _migrateHint = 'dart run iphone_duo_adapt:duo_migrate';

/// The built-in rules.
final List<DuoRule> duoRules = <DuoRule>[
  // ---- Dart: screen size and orientation --------------------------------
  DuoRule(
    id: 'physical-size',
    severity: DuoSeverity.error,
    pattern: RegExp(r'\bphysicalSize\b|\bwindow\.(physicalSize|devicePixelRatio)|'
        r'\bviews\.first\b|\bWidgetsBinding\.instance\.window\b'),
    message: 'Reads the raw screen. On a foldable the screen changes size '
        'while the app runs (466 pt closed to 890 pt open), so a value read '
        'once goes stale.',
    fix: 'Use MediaQuery.sizeOf(context) or LayoutBuilder so the widget '
        'rebuilds when the device folds.',
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
  DuoRule(
    id: 'orientation-lock',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'setPreferredOrientations\s*\('),
    message: 'Orientation lock. The iPhone Duo inner display ignores '
        'supported orientations, so the app is shown in orientations it '
        'was locked out of.',
    fix: 'Make the layout work at any aspect ratio. Keep locks only for '
        'games, and only on compact width.',
  ),
  DuoRule(
    id: 'orientation-branch',
    severity: DuoSeverity.info,
    pattern: RegExp(r'\borientationOf\s*\(|\.orientation\b|'
        r'\bOrientation\.(portrait|landscape)\b|\bOrientationBuilder\s*\(|'
        r'\bsize\.width\s*>\s*\w*\.?size\.height\b'),
    message: 'Layout chosen by orientation. The unfolded Duo is nearly square '
        'and can be "portrait" while having tablet width.',
    fix: 'Branch on available width (LayoutBuilder, MediaQuery.sizeOf, or '
        'DuoLayoutInfo.of(context).widthClass).',
  ),
  DuoRule(
    id: 'device-width-constant',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'((width|Width|shortestSide)\s*(==|!=|<=|>=|<|>)\s*|'
        r'\bwidth\s*:\s*)(320|375|390|393|402|414|428|430|440)(\.0)?\b'),
    message: 'Uses a specific iPhone width. The Duo adds two new widths '
        '(466 and 890 pt) and a near-square shape.',
    fix: 'Use flexible layout (Expanded, FractionallySizedBox, maxWidth) '
        'or a breakpoint range such as 600 instead of exact device sizes.',
  ),
  DuoRule(
    id: 'screen-util-design-size',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'\bScreenUtilInit\s*\(|\bdesignSize\s*:|'
        r'\bSizer\s*\(|\bResponsiveSizer\s*\('),
    message: 'Width-based scaling (flutter_screenutil, sizer). On the 890 pt '
        'inner display every size and font grows about 2x.',
    fix: 'Set a max scale (e.g. ScreenUtilInit(minTextAdapt: true) with '
        'clamped values) or stop scaling on regular width: check '
        'DuoLayoutInfo.of(context).widthClass.',
  ),
  DuoRule(
    id: 'width-scaled-font',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'fontSize\s*:[^,;\n]*(size\.width|sizeOf\([^)]*\)\.width|'
        r'\.sw\b|\.w\b|screenWidth)'),
    message: 'Font size derived from screen width. Text becomes huge on the '
        'unfolded display.',
    fix: 'Use theme text styles and let the user text size apply; clamp '
        'any width-based factor.',
  ),
  DuoRule(
    id: 'device-type-branch',
    severity: DuoSeverity.info,
    pattern: RegExp(r'\bis(Tablet|IPad|Ipad|Phone)\b|model[^;\n]*iPad|'
        r'shortestSide\s*(>=|>)\s*600'),
    message: 'Branches on device type. The unfolded Duo is tablet-sized but '
        'is an iPhone, and Split View makes an iPad phone-sized.',
    fix: 'Decide layout from available size (DuoLayoutInfo.widthClass), not '
        'from what the device is.',
  ),
  DuoRule(
    id: 'phone-aspect-ratio',
    severity: DuoSeverity.info,
    pattern: RegExp(r'aspectRatio\s*:\s*(9\s*/\s*(16|19\.5|19|20)|0\.4[0-9]|0\.5[0-6])'),
    message: 'Assumes a tall phone aspect ratio. Both Duo displays are about '
        '1.4:1.',
    fix: 'Size media from constraints (LayoutBuilder) or allow letterboxing.',
  ),
  // ---- Dart: navigation and layout --------------------------------------
  DuoRule(
    id: 'bottom-bar',
    severity: DuoSeverity.info,
    pattern:
        RegExp(r'\b(BottomNavigationBar|NavigationBar|CupertinoTabBar)\s*\('),
    message: 'Bottom navigation bar. On the unfolded Duo, iOS 27.1 moves tab '
        'bars to a vertical side bar.',
    fix: 'Wrap the Scaffold in DuoAdaptiveScaffold(scaffold: ...).',
    autofix: 'scaffold',
  ),
  DuoRule(
    id: 'cupertino-tab-scaffold',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'(?<!Duo)\bCupertinoTabScaffold\s*\('),
    message: 'CupertinoTabScaffold always draws its tab bar at the bottom.',
    fix: 'Rename to DuoCupertinoTabScaffold (same constructor).',
    autofix: 'cupertino-tabs',
  ),
  DuoRule(
    id: 'first-camera',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'\bcameras\s*(\.first\b|\[\s*[01]\s*\])'),
    message: 'Picks a camera by position in the list. The Duo has outer, '
        'inner and rear cameras, and which faces the user depends on fold '
        'state.',
    fix: 'Select by CameraDescription.lensDirection and re-select in a '
        'DuoPostureObserver when the device folds or unfolds.',
  ),
  DuoRule(
    id: 'face-id-text',
    severity: DuoSeverity.warning,
    pattern: RegExp(r'''['"][^'"\n]*\bFace ?ID\b''', caseSensitive: false),
    matchInStrings: true,
    message: 'Mentions Face ID in user-facing text. iPhone Duo uses Touch ID.',
    fix: 'Read the biometric type at runtime (local_auth '
        'getAvailableBiometrics) and name it accordingly.',
  ),
  // ---- iOS native --------------------------------------------------------
  DuoRule(
    id: 'ios-uiscreen-main',
    severity: DuoSeverity.warning,
    kind: DuoFileKind.iosSource,
    pattern: RegExp(r'\bUIScreen\.main\b|\[UIScreen\s+mainScreen\]'),
    message: 'UIScreen.main does not describe the display the app is on.',
    fix: 'Use view.window?.windowScene?.effectiveGeometry (iOS 26+) or the '
        "view's trait collection.",
  ),
  DuoRule(
    id: 'ios-device-orientation',
    severity: DuoSeverity.warning,
    kind: DuoFileKind.iosSource,
    pattern: RegExp(r'UIDevice\.current\.orientation|currentDevice\]\s*orientation|'
        r'\bstatusBarOrientation\b|\binterfaceOrientation\b'),
    message: 'Native code reads the device orientation, which does not '
        'decide layout on the inner display.',
    fix: 'Use size classes (traitCollection.horizontalSizeClass).',
  ),
  DuoRule(
    id: 'ios-idiom',
    severity: DuoSeverity.info,
    kind: DuoFileKind.iosSource,
    pattern: RegExp(r'\buserInterfaceIdiom\b'),
    message: 'Branches on device idiom. The unfolded Duo is an iPhone with '
        'regular width.',
    fix: 'Use size classes instead.',
  ),
  DuoRule(
    id: 'ios-requires-full-screen',
    severity: DuoSeverity.warning,
    kind: DuoFileKind.infoPlist,
    pattern: RegExp(r'<key>UIRequiresFullScreen</key>'),
    message: 'UIRequiresFullScreen is deprecated and does not stop the Duo '
        'from resizing the app.',
    fix: 'Remove it; use UISceneSizeRestrictions if you need a minimum size.',
  ),
  // ---- Android native ----------------------------------------------------
  DuoRule(
    id: 'android-orientation-lock',
    severity: DuoSeverity.warning,
    kind: DuoFileKind.androidManifest,
    pattern: RegExp(r'android:screenOrientation\s*=\s*"(portrait|landscape|'
        r'sensorPortrait|sensorLandscape|userPortrait|userLandscape|'
        r'reversePortrait|reverseLandscape|nosensor|locked)"'),
    message: 'Orientation lock on Android. Foldables letterbox locked apps '
        'on the inner screen.',
    fix: 'Remove android:screenOrientation, or use "unspecified".',
  ),
  DuoRule(
    id: 'android-not-resizeable',
    severity: DuoSeverity.warning,
    kind: DuoFileKind.androidManifest,
    pattern: RegExp(r'android:resizeableActivity\s*=\s*"false"'),
    message: 'Non-resizeable activity. Android foldables letterbox it when '
        'unfolded.',
    fix: 'Remove android:resizeableActivity="false".',
  ),
];

/// Project-level checks that look at a whole file or the whole project.
class DuoProjectRule {
  /// Creates a project rule.
  const DuoProjectRule({
    required this.id,
    required this.severity,
    required this.message,
    required this.fix,
    this.autofix,
  });

  /// Stable identifier.
  final String id;

  /// Default severity.
  final DuoSeverity severity;

  /// What is wrong.
  final String message;

  /// How to fix it.
  final String fix;

  /// `duo_migrate` step that fixes it.
  final String? autofix;

  /// As a line rule, for reporting.
  DuoRule asRule([DuoSeverity? s]) => DuoRule(
        id: id,
        severity: s ?? severity,
        pattern: RegExp(r'$^'),
        message: message,
        fix: fix,
        autofix: autofix,
      );
}

/// Built-in project rules.
const List<DuoProjectRule> duoProjectRules = <DuoProjectRule>[
  DuoProjectRule(
    id: 'missing-duo-adapt',
    severity: DuoSeverity.warning,
    message: 'App widget without DuoAdapt. Fold data, the native hinge bridge '
        'and every Duo* widget setting depend on it.',
    fix: 'Add builder: DuoAdapt.builder() to MaterialApp / CupertinoApp.',
    autofix: 'app-builder',
  ),
  DuoProjectRule(
    id: 'ios-no-scene-manifest',
    severity: DuoSeverity.warning,
    message: 'Info.plist has no UIApplicationSceneManifest. Apps built with '
        'the iOS 27 SDK must use the UIScene lifecycle.',
    fix: "Follow Flutter's UIScene migration guide "
        '(docs.flutter.dev/release/breaking-changes/uiscenedelegate).',
  ),
  DuoProjectRule(
    id: 'ios-portrait-only',
    severity: DuoSeverity.info,
    message: 'iPhone orientations are portrait only. The inner display '
        'ignores this and shows the app in any orientation.',
    fix: 'Add landscape orientations and test the landscape layout.',
  ),
];

/// Things a static scan cannot see. Printed with `--checklist` and included
/// in JSON output, so a person or an AI agent can verify them by hand.
const List<Map<String, String>> duoManualChecklist = <Map<String, String>>[
  {
    'id': 'fold-transition-state',
    'check': 'Fold and unfold on every screen: text fields, scroll position, '
        'selection, playing media and open sheets survive.',
  },
  {
    'id': 'bent-controls',
    'check': 'Bend the device (book and tabletop): no button, field or '
        'caption is cut by the crease.',
  },
  {
    'id': 'split-view',
    'check': 'Use the app in Split View on the inner display (narrow window): '
        'it gets the compact layout.',
  },
  {
    'id': 'cameras',
    'check': 'Camera screens pick the right camera after folding or unfolding '
        '(needs a device; the simulator has no cameras).',
  },
  {
    'id': 'keyboard',
    'check': 'Keyboard on both displays: fields stay visible, bottom bars do '
        'not jump over it.',
  },
  {
    'id': 'safe-areas',
    'check': 'Nothing under the camera cutout or rounded corners on either '
        'display, in both landscape directions.',
  },
  {
    'id': 'biometrics',
    'check': 'Sign-in and payment prompts say Touch ID on iPhone Duo.',
  },
  {
    'id': 'large-text',
    'check': 'Largest text size on the outer display: nothing clipped.',
  },
  {
    'id': 'rtl',
    'check': 'Right-to-left locale: rail, panes and fold-avoiding content '
        'mirror correctly.',
  },
  {
    'id': 'store-screenshots',
    'check': 'App Store screenshots for both iPhone Duo slots (outer and '
        'inner display), e.g. from DuoPreview or golden tests.',
  },
];

/// Settings from `iphone_duo_adapt.yaml` (section `duo_audit`).
class DuoAuditConfig {
  /// Creates a config.
  const DuoAuditConfig({
    this.severities = const <String, DuoSeverity?>{},
    this.exclude = const <String>[],
    this.customRules = const <DuoRule>[],
  });

  /// Rule id → new severity, or `null` to turn the rule off.
  final Map<String, DuoSeverity?> severities;

  /// Glob patterns (relative to the project root) to skip.
  final List<String> exclude;

  /// Extra rules.
  final List<DuoRule> customRules;

  /// Parses YAML text.
  ///
  /// ```yaml
  /// duo_audit:
  ///   exclude:
  ///     - lib/generated/**
  ///   rules:
  ///     bottom-bar: off
  ///     orientation-lock: error
  ///   custom_rules:
  ///     - id: no-legacy-sizer
  ///       severity: warning
  ///       pattern: "LegacySizer\\("
  ///       message: LegacySizer scales with screen width.
  ///       fix: Use DuoLayoutBuilder.
  /// ```
  factory DuoAuditConfig.fromYaml(String text) {
    final doc = loadYaml(text);
    final root = doc is YamlMap ? doc['duo_audit'] : null;
    if (root is! YamlMap) return const DuoAuditConfig();
    final severities = <String, DuoSeverity?>{};
    final rules = root['rules'];
    if (rules is YamlMap) {
      rules.forEach((k, v) {
        final value = '$v'.toLowerCase();
        severities['$k'] = switch (value) {
          'off' || 'false' || 'ignore' => null,
          'info' => DuoSeverity.info,
          'warning' => DuoSeverity.warning,
          'error' => DuoSeverity.error,
          _ => throw FormatException('Unknown severity "$v" for rule $k'),
        };
      });
    }
    final exclude = <String>[
      if (root['exclude'] is YamlList)
        for (final e in root['exclude'] as YamlList) '$e',
    ];
    final custom = <DuoRule>[];
    final raw = root['custom_rules'];
    if (raw is YamlList) {
      for (final r in raw) {
        if (r is! YamlMap) continue;
        final kind = switch ('${r['files'] ?? 'dart'}') {
          'ios' => DuoFileKind.iosSource,
          'plist' => DuoFileKind.infoPlist,
          'android' => DuoFileKind.androidManifest,
          _ => DuoFileKind.dart,
        };
        custom.add(DuoRule(
          id: '${r['id']}',
          severity: DuoSeverity.values.byName('${r['severity'] ?? 'warning'}'),
          pattern: RegExp('${r['pattern']}'),
          message: '${r['message'] ?? r['id']}',
          fix: '${r['fix'] ?? ''}',
          kind: kind,
          matchInStrings: r['match_in_strings'] == true,
        ));
      }
    }
    return DuoAuditConfig(
      severities: severities,
      exclude: exclude,
      customRules: custom,
    );
  }

  /// Whether [relativePath] matches an [exclude] glob.
  bool isExcluded(String relativePath) {
    final p = relativePath.replaceAll(r'\', '/');
    return exclude.any((g) => _globToRegExp(g).hasMatch(p));
  }

  static RegExp _globToRegExp(String glob) {
    final b = StringBuffer('^');
    for (var i = 0; i < glob.length; i++) {
      final c = glob[i];
      if (c == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          b.write('.*');
          i++;
          if (i + 1 < glob.length && glob[i + 1] == '/') i++;
        } else {
          b.write('[^/]*');
        }
      } else if (c == '?') {
        b.write('[^/]');
      } else {
        b.write(RegExp.escape(c));
      }
    }
    b.write(r'$');
    return RegExp(b.toString());
  }
}

/// Result of a project audit.
class DuoAuditReport {
  /// Creates a report.
  const DuoAuditReport({required this.files, required this.findings});

  /// Number of files scanned.
  final int files;

  /// Findings, sorted by path and line.
  final List<DuoFinding> findings;

  /// Count per severity.
  Map<DuoSeverity, int> get counts => <DuoSeverity, int>{
        for (final s in DuoSeverity.values)
          s: findings.where((f) => f.rule.severity == s).length,
      };

  /// JSON form (schema version 2).
  Map<String, Object?> toJson({bool checklist = true}) => <String, Object?>{
        'schema': 'iphone_duo_adapt/audit@2',
        'files': files,
        'counts': {for (final e in counts.entries) e.key.name: e.value},
        'findings': findings.map((f) => f.toJson()).toList(),
        if (checklist) 'manualChecklist': duoManualChecklist,
      };
}

/// Runs rules over Dart source, native files, or a whole project.
class DuoAuditor {
  /// Creates an auditor.
  DuoAuditor({
    List<DuoRule>? rules,
    this.config = const DuoAuditConfig(),
  }) : _rules = _effective(rules ?? duoRules, config);

  /// Settings.
  final DuoAuditConfig config;

  final List<DuoRule> _rules;

  /// Rules in effect after the config is applied.
  List<DuoRule> get rules => _rules;

  static List<DuoRule> _effective(List<DuoRule> base, DuoAuditConfig c) {
    final out = <DuoRule>[];
    for (final r in <DuoRule>[...base, ...c.customRules]) {
      if (c.severities.containsKey(r.id)) {
        final s = c.severities[r.id];
        if (s != null) out.add(r.withSeverity(s));
      } else {
        out.add(r);
      }
    }
    return out;
  }

  DuoSeverity? _projectSeverity(DuoProjectRule r) =>
      config.severities.containsKey(r.id)
          ? config.severities[r.id]
          : r.severity;

  static final RegExp _ignore = RegExp(r'duo-ignore:\s*([\w\-, ]+)');
  static final RegExp _ignoreFile = RegExp(r'duo-ignore-file:\s*([\w\-, ]+)');

  /// Audits one Dart file's [source].
  List<DuoFinding> auditSource(String path, String source) =>
      auditFile(path, source, DuoFileKind.dart);

  /// Audits one file of [kind].
  List<DuoFinding> auditFile(String path, String source, DuoFileKind kind) {
    final rules = _rules.where((r) => r.kind == kind).toList();
    if (rules.isEmpty) return const <DuoFinding>[];
    final lines = source.split('\n');
    final masked = kind == DuoFileKind.dart ||
            kind == DuoFileKind.iosSource
        ? maskDart(source).split('\n')
        : lines;
    final fileIgnores = <String>{};
    for (final m in _ignoreFile.allMatches(source)) {
      fileIgnores.addAll(_ids(m.group(1)!));
    }
    final findings = <DuoFinding>[];
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final code = i < masked.length ? masked[i] : raw;
      final ignores = <String>{...fileIgnores};
      final here = _ignore.firstMatch(raw);
      if (here != null) ignores.addAll(_ids(here.group(1)!));
      if (i > 0 && lines[i - 1].trim().startsWith('//')) {
        final above = _ignore.firstMatch(lines[i - 1]);
        if (above != null) ignores.addAll(_ids(above.group(1)!));
      }
      for (final rule in rules) {
        if (ignores.contains(rule.id) || ignores.contains('all')) continue;
        final text = rule.matchInStrings ? _stripComment(raw) : code;
        if (text.trim().isEmpty) continue;
        final m = rule.pattern.firstMatch(text);
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

  /// Project-level checks for one Dart file.
  List<DuoFinding> auditDartProjectRules(String path, String source) {
    final findings = <DuoFinding>[];
    final rule = duoProjectRules.firstWhere((r) => r.id == 'missing-duo-adapt');
    final severity = _projectSeverity(rule);
    if (severity == null || _ignoredInFile(source, rule.id)) return findings;
    final masked = maskDart(source);
    final app = RegExp(r'\b(MaterialApp|CupertinoApp|WidgetsApp)(\.router)?\s*\(')
        .firstMatch(masked);
    if (app != null && !RegExp(r'\bDuoAdapt\b').hasMatch(masked)) {
      final (line, col) = lineColumn(source, app.start);
      findings.add(DuoFinding(
        rule: rule.asRule(severity),
        path: path,
        line: line,
        column: col,
        source: source.split('\n')[line - 1].trim(),
      ));
    }
    return findings;
  }

  /// Project-level checks for `Info.plist`.
  List<DuoFinding> auditInfoPlist(String path, String source) {
    final findings = <DuoFinding>[...auditFile(path, source, DuoFileKind.infoPlist)];
    final scene = duoProjectRules.firstWhere((r) => r.id == 'ios-no-scene-manifest');
    final sceneSeverity = _projectSeverity(scene);
    if (sceneSeverity != null &&
        !source.contains('<key>UIApplicationSceneManifest</key>')) {
      findings.add(DuoFinding(
        rule: scene.asRule(sceneSeverity),
        path: path,
        line: 1,
        column: 1,
        source: '',
      ));
    }
    final portrait = duoProjectRules.firstWhere((r) => r.id == 'ios-portrait-only');
    final portraitSeverity = _projectSeverity(portrait);
    final m = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(source);
    if (portraitSeverity != null &&
        m != null &&
        !m.group(1)!.contains('Landscape')) {
      final (line, col) = lineColumn(source, m.start);
      findings.add(DuoFinding(
        rule: portrait.asRule(portraitSeverity),
        path: path,
        line: line,
        column: col,
        source: '<key>UISupportedInterfaceOrientations</key>',
      ));
    }
    return findings;
  }

  /// Audits a Flutter project at [root]: `lib/` (or [dartPaths]), native
  /// iOS sources, `Info.plist` and the Android manifest.
  DuoAuditReport auditProject(String root, {List<String>? dartPaths}) {
    final findings = <DuoFinding>[];
    var files = 0;
    String rel(String p) {
      final r = p.startsWith(root) ? p.substring(root.length) : p;
      return r.startsWith(Platform.pathSeparator) ? r.substring(1) : r;
    }

    Iterable<File> walk(String dir, bool Function(String) want) sync* {
      final d = Directory(dir);
      if (!d.existsSync()) return;
      final entries = d.listSync(recursive: true, followLinks: false)
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final e in entries) {
        if (e is! File) continue;
        final p = e.path.replaceAll(r'\', '/');
        if (p.contains('/.dart_tool/') ||
            p.contains('/build/') ||
            p.contains('/Pods/') ||
            p.contains('/ephemeral/') ||
            p.contains('/.symlinks/')) {
          continue;
        }
        if (!want(p)) continue;
        if (config.isExcluded(rel(e.path))) continue;
        yield e;
      }
    }

    final dartRoots = dartPaths ?? <String>['$root/lib'];
    for (final dir in dartRoots) {
      final type = FileSystemEntity.typeSync(dir);
      final list = type == FileSystemEntityType.file
          ? <File>[File(dir)]
          : walk(dir, (p) =>
              p.endsWith('.dart') &&
              !p.endsWith('.g.dart') &&
              !p.endsWith('.freezed.dart'));
      for (final f in list) {
        if (!f.path.endsWith('.dart')) continue;
        files++;
        final src = f.readAsStringSync();
        findings
          ..addAll(auditSource(rel(f.path), src))
          ..addAll(auditDartProjectRules(rel(f.path), src));
      }
    }
    for (final f in walk('$root/ios', (p) =>
        (p.endsWith('.swift') ||
            p.endsWith('.m') ||
            p.endsWith('.mm') ||
            p.endsWith('.h')) &&
        !p.contains('GeneratedPluginRegistrant'))) {
      files++;
      findings.addAll(
          auditFile(rel(f.path), f.readAsStringSync(), DuoFileKind.iosSource));
    }
    final plist = File('$root/ios/Runner/Info.plist');
    if (plist.existsSync()) {
      files++;
      findings.addAll(auditInfoPlist(rel(plist.path), plist.readAsStringSync()));
    }
    final manifest = File('$root/android/app/src/main/AndroidManifest.xml');
    if (manifest.existsSync()) {
      files++;
      findings.addAll(auditFile(rel(manifest.path), manifest.readAsStringSync(),
          DuoFileKind.androidManifest));
    }
    findings.sort((a, b) {
      final p = a.path.compareTo(b.path);
      return p != 0 ? p : a.line.compareTo(b.line);
    });
    return DuoAuditReport(files: files, findings: findings);
  }

  bool _ignoredInFile(String source, String id) {
    for (final m in _ignoreFile.allMatches(source)) {
      final ids = _ids(m.group(1)!).toSet();
      if (ids.contains(id) || ids.contains('all')) return true;
    }
    return false;
  }

  static Iterable<String> _ids(String s) =>
      s.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty);

  // Drops a trailing // comment that is not inside a string.
  static String _stripComment(String line) {
    final masked = maskDart(line);
    final i = masked.indexOf('//');
    return i < 0 ? line : line.substring(0, i);
  }
}

/// Hint printed at the end of a text report.
const String duoMigrateHint =
    'Findings marked "auto" can be fixed with: $_migrateHint';
