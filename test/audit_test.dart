import 'package:iphone_duo_adapt/audit.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(String src) =>
    DuoAuditor().auditSource('a.dart', src).map((f) => f.rule.id).toList();

void main() {
  test('flags orientation locks', () {
    expect(_ids('SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);'),
        contains('orientation-lock'));
  });

  test('flags raw screen reads', () {
    expect(_ids('final s = View.of(context).physicalSize;'),
        contains('physical-size'));
    expect(_ids('final v = PlatformDispatcher.instance.views.first;'),
        contains('physical-size'));
  });

  test('flags exact device widths but not breakpoints', () {
    expect(_ids('if (size.width <= 375) compact();'),
        contains('device-width-constant'));
    expect(_ids('if (size.width >= 600) wide();'), isEmpty);
  });

  test('flags bottom bars and orientation branches', () {
    expect(_ids('bottomNavigationBar: BottomNavigationBar(items: items),'),
        ['bottom-bar']);
    expect(_ids('if (MediaQuery.orientationOf(context) == Orientation.portrait) {}'),
        ['orientation-branch']);
  });

  test('flags cached screen size and first camera', () {
    expect(_ids('late final size = MediaQuery.sizeOf(context);'),
        contains('static-screen-size'));
    expect(_ids('controller = CameraController(cameras.first, preset);'),
        contains('first-camera'));
  });

  test('ignores comments, strings and duo-ignore', () {
    expect(_ids('// SystemChrome.setPreferredOrientations(x);'), isEmpty);
    expect(_ids("print('setPreferredOrientations(');"), isEmpty);
    expect(_ids('/* start\nsetPreferredOrientations(x);\nend */'), isEmpty);
    expect(
        _ids('SystemChrome.setPreferredOrientations(x); '
            '// duo-ignore: orientation-lock'),
        isEmpty);
    expect(
        _ids('// duo-ignore: orientation-lock\n'
            'SystemChrome.setPreferredOrientations(x);'),
        isEmpty);
    expect(
        _ids('// duo-ignore-file: all\nSystemChrome.setPreferredOrientations(x);'),
        isEmpty);
  });

  test('column points at the match', () {
    final f = DuoAuditor()
        .auditSource('a.dart', "  foo('x'); BottomNavigationBar(items: i)")
        .single;
    expect(f.line, 1);
    expect(f.column, 13);
  });
}
