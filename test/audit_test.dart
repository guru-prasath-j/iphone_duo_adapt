import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_duo_adapt/audit.dart';

List<String> _ids(String src, {DuoAuditConfig? config}) => DuoAuditor(
      config: config ?? const DuoAuditConfig(),
    ).auditSource('a.dart', src).map((f) => f.rule.id).toList();

void main() {
  test('flags orientation locks', () {
    expect(
      _ids(
        'SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);',
      ),
      contains('orientation-lock'),
    );
  });

  test('flags raw screen reads', () {
    expect(
      _ids('final s = View.of(context).physicalSize;'),
      contains('physical-size'),
    );
    expect(
      _ids('final v = PlatformDispatcher.instance.views.first;'),
      contains('physical-size'),
    );
  });

  test('flags exact device widths but not breakpoints', () {
    expect(
      _ids('if (size.width <= 375) compact();'),
      contains('device-width-constant'),
    );
    expect(
      _ids('SizedBox(width: 390, child: x)'),
      contains('device-width-constant'),
    );
    expect(_ids('if (size.width >= 600) wide();'), isEmpty);
  });

  test('flags bottom bars and orientation branches', () {
    expect(
      _ids('bottomNavigationBar: BottomNavigationBar(items: items),'),
      <String>['bottom-bar'],
    );
    expect(
      _ids('if (MediaQuery.orientationOf(context) == Orientation.portrait) {}'),
      <String>['orientation-branch'],
    );
  });

  test('flags cached screen size and first camera', () {
    expect(
      _ids('late final size = MediaQuery.sizeOf(context);'),
      contains('static-screen-size'),
    );
    expect(
      _ids('controller = CameraController(cameras.first, preset);'),
      contains('first-camera'),
    );
  });

  test('flags width-based scaling and fonts', () {
    expect(
      _ids('ScreenUtilInit(designSize: const Size(375, 812))'),
      contains('screen-util-design-size'),
    );
    expect(
      _ids('TextStyle(fontSize: MediaQuery.sizeOf(context).width * 0.05)'),
      contains('width-scaled-font'),
    );
    expect(
      _ids('TextStyle(fontSize: 16.sp)'),
      isNot(contains('width-scaled-font')),
    );
  });

  test('flags device-type branching and phone aspect ratios', () {
    expect(_ids('if (isTablet) twoPane();'), contains('device-type-branch'));
    expect(
      _ids('AspectRatio(aspectRatio: 9 / 19.5, child: c)'),
      contains('phone-aspect-ratio'),
    );
  });

  test('flags Face ID in user text, not in code', () {
    expect(_ids("Text('Unlock with Face ID')"), contains('face-id-text'));
    expect(_ids('// Face ID is handled by the plugin'), isEmpty);
    expect(_ids('final faceId = true;'), isEmpty);
  });

  test('CupertinoTabScaffold is flagged, DuoCupertinoTabScaffold is not', () {
    expect(
      _ids('CupertinoTabScaffold(tabBar: bar, tabBuilder: b)'),
      contains('cupertino-tab-scaffold'),
    );
    expect(
      _ids('DuoCupertinoTabScaffold(tabBar: bar, tabBuilder: b)'),
      isNot(contains('cupertino-tab-scaffold')),
    );
  });

  test('ignores comments, strings and duo-ignore', () {
    expect(_ids('// SystemChrome.setPreferredOrientations(x);'), isEmpty);
    expect(_ids("print('setPreferredOrientations(');"), isEmpty);
    expect(_ids('/* start\nsetPreferredOrientations(x);\nend */'), isEmpty);
    expect(
      _ids(
        'SystemChrome.setPreferredOrientations(x); '
        '// duo-ignore: orientation-lock',
      ),
      isEmpty,
    );
    expect(
      _ids(
        '// duo-ignore: orientation-lock\n'
        'SystemChrome.setPreferredOrientations(x);',
      ),
      isEmpty,
    );
    expect(
      _ids(
        '// duo-ignore-file: all\nSystemChrome.setPreferredOrientations(x);',
      ),
      isEmpty,
    );
  });

  test('column points at the match', () {
    final f = DuoAuditor()
        .auditSource('a.dart', "  foo('x'); BottomNavigationBar(items: i)")
        .single;
    expect(f.line, 1);
    expect(f.column, 13);
    expect(f.toJson()['autofix'], 'scaffold');
  });

  test('config changes severities, turns rules off, adds custom rules', () {
    final config = DuoAuditConfig.fromYaml('''
duo_audit:
  exclude:
    - lib/generated/**
  rules:
    bottom-bar: off
    orientation-lock: error
  custom_rules:
    - id: no-legacy-sizer
      severity: info
      pattern: "LegacySizer\\\\("
      message: LegacySizer scales with screen width.
      fix: Use DuoLayoutBuilder.
''');
    final auditor = DuoAuditor(config: config);
    final findings = auditor.auditSource(
      'a.dart',
      'BottomNavigationBar(items: i);\n'
          'SystemChrome.setPreferredOrientations(x);\n'
          'LegacySizer(child: c);',
    );
    expect(findings.map((f) => f.rule.id), <String>[
      'orientation-lock',
      'no-legacy-sizer',
    ]);
    expect(findings.first.rule.severity, DuoSeverity.error);
    expect(config.isExcluded('lib/generated/app.g.dart'), isTrue);
    expect(config.isExcluded('lib/main.dart'), isFalse);
    expect(
      () => DuoAuditConfig.fromYaml('duo_audit:\n  rules:\n    x: loud'),
      throwsFormatException,
    );
  });

  test('project audit covers Dart, Info.plist, native iOS and Android', () {
    final dir = Directory.systemTemp.createTempSync('duo_audit_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() => runApp(MaterialApp(home: Home()));');
    File('${dir.path}/ios/Runner/Info.plist')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<plist><dict>
<key>UIRequiresFullScreen</key><true/>
<key>UISupportedInterfaceOrientations</key>
<array><string>UIInterfaceOrientationPortrait</string></array>
</dict></plist>''');
    File('${dir.path}/ios/Runner/AppDelegate.swift')
      ..createSync(recursive: true)
      ..writeAsStringSync('let w = UIScreen.main.bounds.width');
    File('${dir.path}/android/app/src/main/AndroidManifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '<activity android:screenOrientation="portrait" '
        'android:resizeableActivity="false"/>',
      );

    final report = DuoAuditor().auditProject(dir.path);
    final ids = report.findings.map((f) => f.rule.id).toSet();
    expect(
      ids,
      containsAll(<String>[
        'missing-duo-adapt',
        'ios-requires-full-screen',
        'ios-no-scene-manifest',
        'ios-portrait-only',
        'ios-uiscreen-main',
        'android-orientation-lock',
        'android-not-resizeable',
      ]),
    );
    final json = report.toJson();
    expect(json['schema'], 'iphone_duo_adapt/audit@2');
    expect(json['manualChecklist'], isNotEmpty);

    // Adding DuoAdapt clears the app finding.
    File('${dir.path}/lib/main.dart').writeAsStringSync(
      'void main() => runApp(MaterialApp(builder: DuoAdapt.builder()));',
    );
    final again = DuoAuditor().auditProject(dir.path);
    expect(
      again.findings.map((f) => f.rule.id),
      isNot(contains('missing-duo-adapt')),
    );
  });
}
