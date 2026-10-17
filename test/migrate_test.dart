import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iphone_duo_adapt/migrate.dart';
import 'package:flutter_iphone_duo_adapt/src/tooling/dart_mask.dart';

String _run(String src, [Set<DuoMigrationStep>? steps]) =>
    DuoMigrator(steps: steps).migrate('a.dart', src).migrated;

void main() {
  group('mask', () {
    test('blanks comments and strings, keeps offsets', () {
      const src = "a('x(y') /* (z */ b // c(\n\"\"\"q(\"\"\" r'(' d";
      final m = maskDart(src);
      expect(m.length, src.length);
      expect(m.contains('('), isTrue);
      expect('('.allMatches(m).length, 1);
      expect(m.contains('d'), isTrue);
    });

    test('nested block comments', () {
      expect(maskDart('/* a /* b */ c */x').trim(), 'x');
    });

    test('named arguments at top level only', () {
      const src = 'F(a: 1, b: G(c: 2), d: [e ? f : g])';
      final args = namedArguments(maskDart(src), 1);
      expect(args.keys, <String>['a', 'b', 'd']);
    });
  });

  group('app-builder', () {
    test('adds the builder and the import', () {
      final out = _run(
        "import 'package:flutter/material.dart';\n\n"
        'void main() => runApp(MaterialApp(home: Home()));\n',
      );
      expect(out, contains('MaterialApp(builder: DuoAdapt.builder(), home:'));
      expect(out, contains(duoImport));
      expect(
        out.indexOf(duoImport),
        greaterThan(out.indexOf('package:flutter/material.dart')),
      );
    });

    test('wraps an existing builder', () {
      final out = _run(
        'MaterialApp(\n  builder: (c, w) => Theme(child: w!),\n'
        '  home: Home(),\n)',
      );
      expect(
        out,
        contains(
          'builder: DuoAdapt.builder(inner: (c, w) => Theme(child: w!)),',
        ),
      );
    });

    test('drops const and handles .router and CupertinoApp', () {
      expect(
        _run('const MaterialApp(home: Home())'),
        startsWith('$duoImport\n\nMaterialApp(builder: DuoAdapt.builder(), '),
      );
      expect(
        _run('MaterialApp.router(routerConfig: r)'),
        contains(
          'MaterialApp.router(builder: DuoAdapt.builder(), routerConfig',
        ),
      );
      expect(
        _run('CupertinoApp(home: H())'),
        contains('CupertinoApp(builder: DuoAdapt.builder(), home'),
      );
    });

    test('is idempotent', () {
      final once = _run('MaterialApp(home: Home())');
      expect(_run(once), once);
    });
  });

  group('scaffold', () {
    test('wraps a Scaffold with a bottom bar', () {
      final out = _run(
        'return Scaffold(\n  body: b,\n  bottomNavigationBar: NavigationBar(destinations: d),\n);',
        {DuoMigrationStep.scaffold},
      );
      expect(out, contains('return DuoAdaptiveScaffold(scaffold: Scaffold('));
      expect(out.trimRight(), endsWith('));'));
    });

    test('leaves other scaffolds, nested bars and wrapped ones alone', () {
      const plain = 'Scaffold(body: Column(children: [x]))';
      expect(_run(plain, {DuoMigrationStep.scaffold}), plain);
      const nested =
          'Scaffold(body: Foo(bottomNavigationBar: y))'; // not top level
      expect(_run(nested, {DuoMigrationStep.scaffold}), nested);
      final once = _run('Scaffold(bottomNavigationBar: b)', {
        DuoMigrationStep.scaffold,
      });
      expect(_run(once, {DuoMigrationStep.scaffold}), once);
    });

    test('moves const inside the wrapper', () {
      final out = _run('const Scaffold(bottomNavigationBar: b)', {
        DuoMigrationStep.scaffold,
      });
      expect(
        out,
        contains(
          'DuoAdaptiveScaffold(scaffold: const Scaffold(bottomNavigationBar: b))',
        ),
      );
    });

    test('does not touch CupertinoPageScaffold or strings', () {
      const src =
          "CupertinoPageScaffold(child: c); print('Scaffold(bottomNavigationBar: x)');";
      expect(_run(src, {DuoMigrationStep.scaffold}), src);
    });
  });

  group('cupertino-tabs', () {
    test('renames the constructor call only', () {
      final out = _run(
        '// CupertinoTabScaffold( in a comment\n'
        'return CupertinoTabScaffold(tabBar: t, tabBuilder: b);',
        {DuoMigrationStep.cupertinoTabs},
      );
      expect(out, contains('return DuoCupertinoTabScaffold(tabBar'));
      expect(out, contains('// CupertinoTabScaffold( in a comment'));
      expect(_run(out, {DuoMigrationStep.cupertinoTabs}), out);
    });
  });

  test('reports edits with lines', () {
    final r = DuoMigrator().migrate(
      'a.dart',
      'void main() {\n  runApp(MaterialApp(home: Scaffold(bottomNavigationBar: b)));\n}',
    );
    expect(r.changed, isTrue);
    expect(r.edits.map((e) => e.step), <DuoMigrationStep>[
      DuoMigrationStep.appBuilder,
      DuoMigrationStep.scaffold,
    ]);
    expect(r.edits.every((e) => e.line == 2), isTrue);
    expect(r.toJson()['changed'], isTrue);
  });
}
