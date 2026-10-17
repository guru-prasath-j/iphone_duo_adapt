/// Source transformations that retrofit an existing app for iPhone Duo.
///
/// Pure Dart; used by `dart run flutter_iphone_duo_adapt:duo_migrate`. Every step is
/// conservative: it only rewrites code it fully understands, never touches
/// comments or strings, and leaves files that already use the package
/// alone. Run `dart format` afterwards.
library;

import '../tooling/dart_mask.dart';

/// Import line added to changed files.
const String duoImport =
    "import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';";

/// Migration steps, by id.
enum DuoMigrationStep {
  /// Add `builder: DuoAdapt.builder()` to MaterialApp / CupertinoApp /
  /// WidgetsApp (and their `.router` forms). An existing `builder:` is kept
  /// and passed as `inner:`.
  appBuilder('app-builder'),

  /// Wrap every `Scaffold(...)` that has a `bottomNavigationBar:` in
  /// `DuoAdaptiveScaffold(scaffold: ...)`.
  scaffold('scaffold'),

  /// Rename `CupertinoTabScaffold(` to `DuoCupertinoTabScaffold(`.
  cupertinoTabs('cupertino-tabs');

  const DuoMigrationStep(this.id);

  /// Stable id used on the command line (`--only=app-builder,scaffold`).
  final String id;

  /// Step for [id], or `null`.
  static DuoMigrationStep? byId(String id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// One change made by the migrator.
class DuoEdit {
  /// Creates an edit record.
  const DuoEdit({
    required this.step,
    required this.line,
    required this.description,
  });

  /// Step that made it.
  final DuoMigrationStep step;

  /// 1-based line in the original file.
  final int line;

  /// What changed.
  final String description;

  /// JSON form.
  Map<String, Object> toJson() => <String, Object>{
        'step': step.id,
        'line': line,
        'description': description,
      };
}

/// Result of migrating one file.
class DuoMigrationResult {
  /// Creates a result.
  const DuoMigrationResult({
    required this.path,
    required this.original,
    required this.migrated,
    required this.edits,
  });

  /// File path.
  final String path;

  /// Source before.
  final String original;

  /// Source after.
  final String migrated;

  /// Changes made.
  final List<DuoEdit> edits;

  /// Whether anything changed.
  bool get changed => original != migrated;

  /// JSON form.
  Map<String, Object> toJson() => <String, Object>{
        'path': path,
        'changed': changed,
        'edits': edits.map((e) => e.toJson()).toList(),
      };
}

class _Insert {
  _Insert(this.offset, this.text, {this.removeLength = 0});
  final int offset;
  final String text;
  final int removeLength;
}

/// Applies [DuoMigrationStep]s to Dart source.
class DuoMigrator {
  /// Creates a migrator running [steps] (all by default).
  DuoMigrator({Set<DuoMigrationStep>? steps})
      : steps = steps ?? DuoMigrationStep.values.toSet();

  /// Steps to run.
  final Set<DuoMigrationStep> steps;

  /// Migrates one file.
  DuoMigrationResult migrate(String path, String source) {
    final masked = maskDart(source);
    final inserts = <_Insert>[];
    final edits = <DuoEdit>[];

    int line(int offset) => lineColumn(source, offset).$1;

    if (steps.contains(DuoMigrationStep.appBuilder) &&
        !RegExp(r'\bDuoAdapt\b').hasMatch(masked)) {
      final re = RegExp(
        r'\b(MaterialApp|CupertinoApp|WidgetsApp)(\.router)?\s*\(',
      );
      for (final m in re.allMatches(masked)) {
        if (_precededByIdentChar(masked, m.start)) continue;
        final open = m.end - 1;
        final close = matchingBracket(masked, open);
        if (close < 0) continue;
        final args = namedArguments(masked, open);
        final name = '${m.group(1)}${m.group(2) ?? ''}';
        // DuoAdapt.builder() is not const: drop a `const` on the app widget.
        final constMatch = RegExp(
          r'\bconst\s+$',
        ).firstMatch(masked.substring(0, m.start));
        if (constMatch != null) {
          inserts.add(
            _Insert(
              constMatch.start,
              '',
              removeLength: m.start - constMatch.start,
            ),
          );
        }
        if (args.containsKey('builder')) {
          final at = args['builder']!;
          final colon = masked.indexOf(':', at);
          final valueStart = _skipSpace(masked, colon + 1);
          final valueEnd = _argEnd(masked, valueStart, close);
          final value = source.substring(valueStart, valueEnd).trim();
          inserts.add(
            _Insert(
              valueStart,
              'DuoAdapt.builder(inner: $value)',
              removeLength: valueEnd - valueStart,
            ),
          );
          edits.add(
            DuoEdit(
              step: DuoMigrationStep.appBuilder,
              line: line(at),
              description: '$name: wrapped existing builder in '
                  'DuoAdapt.builder(inner: ...)',
            ),
          );
        } else {
          inserts.add(_Insert(open + 1, 'builder: DuoAdapt.builder(), '));
          edits.add(
            DuoEdit(
              step: DuoMigrationStep.appBuilder,
              line: line(m.start),
              description: '$name: added builder: DuoAdapt.builder()',
            ),
          );
        }
      }
    }

    if (steps.contains(DuoMigrationStep.scaffold)) {
      final re = RegExp(r'(\bconst\s+)?\bScaffold\s*\(');
      for (final m in re.allMatches(masked)) {
        final scaffoldAt = m.start + (m.group(1)?.length ?? 0);
        if (_precededByIdentChar(masked, scaffoldAt)) continue;
        final before = masked.substring(0, m.start).trimRight();
        if (before.endsWith('scaffold:')) continue; // Already wrapped.
        final open = m.end - 1;
        final close = matchingBracket(masked, open);
        if (close < 0) continue;
        final args = namedArguments(masked, open);
        if (!args.containsKey('bottomNavigationBar')) continue;
        inserts
          ..add(_Insert(scaffoldAt, 'DuoAdaptiveScaffold(scaffold: '))
          ..add(_Insert(close + 1, ')'));
        if (m.group(1) != null) {
          // `const Scaffold(` → `DuoAdaptiveScaffold(scaffold: const Scaffold(`
          inserts.add(_Insert(m.start, '', removeLength: m.group(1)!.length));
          inserts.add(_Insert(scaffoldAt, 'const '));
        }
        edits.add(
          DuoEdit(
            step: DuoMigrationStep.scaffold,
            line: line(scaffoldAt),
            description: 'wrapped Scaffold with bottomNavigationBar in '
                'DuoAdaptiveScaffold',
          ),
        );
      }
    }

    if (steps.contains(DuoMigrationStep.cupertinoTabs)) {
      final re = RegExp(r'(?<![\w$])CupertinoTabScaffold(?=\s*\()');
      for (final m in re.allMatches(masked)) {
        inserts.add(_Insert(m.start, 'Duo'));
        edits.add(
          DuoEdit(
            step: DuoMigrationStep.cupertinoTabs,
            line: line(m.start),
            description: 'CupertinoTabScaffold → DuoCupertinoTabScaffold',
          ),
        );
      }
    }

    if (inserts.isEmpty) {
      return DuoMigrationResult(
        path: path,
        original: source,
        migrated: source,
        edits: edits,
      );
    }

    // Import.
    if (!source.contains(duoImport)) {
      final imports = RegExp(
        r'^import\s+[^;]+;[^\n]*$',
        multiLine: true,
      ).allMatches(masked).toList();
      // Added first so that, at an equal offset (code at the very start of
      // the file), the import lands before any wrapper text.
      if (imports.isNotEmpty) {
        inserts.insert(0, _Insert(imports.last.end, '\n$duoImport'));
      } else {
        final lib = RegExp(
          r'^library[^;]*;[^\n]*$',
          multiLine: true,
        ).firstMatch(masked);
        final text = lib != null ? '\n\n$duoImport' : '$duoImport\n\n';
        inserts.insert(0, _Insert(lib?.end ?? 0, text));
      }
    }

    // Apply from the end so offsets stay valid. At equal offsets, removals
    // run first (on the original text), then insertions in reverse order so
    // earlier-added text ends up first.
    final indexed = inserts.asMap().entries.toList()
      ..sort((a, b) {
        final c = b.value.offset.compareTo(a.value.offset);
        if (c != 0) return c;
        final ra = a.value.removeLength > 0 ? 0 : 1;
        final rb = b.value.removeLength > 0 ? 0 : 1;
        if (ra != rb) return ra.compareTo(rb);
        return b.key.compareTo(a.key);
      });
    var out = source;
    for (final e in indexed) {
      final ins = e.value;
      out = out.replaceRange(
        ins.offset,
        ins.offset + ins.removeLength,
        ins.text,
      );
    }
    return DuoMigrationResult(
      path: path,
      original: source,
      migrated: out,
      edits: edits,
    );
  }

  static bool _precededByIdentChar(String s, int i) {
    if (i == 0) return false;
    final c = s[i - 1];
    return RegExp(r'[\w$.]').hasMatch(c);
  }

  static int _skipSpace(String s, int i) {
    while (i < s.length && s[i].trim().isEmpty) {
      i++;
    }
    return i;
  }

  // End of the argument value starting at [start]: the next top-level comma
  // or the call's closing paren.
  static int _argEnd(String masked, int start, int close) {
    var depth = 0;
    for (var i = start; i < close; i++) {
      final c = masked[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (c == ',' && depth == 0) {
        // Trim trailing whitespace before the comma.
        var end = i;
        while (end > start && masked[end - 1].trim().isEmpty) {
          end--;
        }
        return end;
      }
    }
    var end = close;
    while (end > start && masked[end - 1].trim().isEmpty) {
      end--;
    }
    return end;
  }
}
