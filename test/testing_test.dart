import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:iphone_duo_adapt/testing.dart';

void main() {
  group('DuoScenario', () {
    test('lists every scenario once', () {
      expect(DuoScenario.core, hasLength(6));
      expect(DuoScenario.all, hasLength(8));
      expect(DuoScenario.all.map((s) => s.name).toSet(), hasLength(8));
    });

    test('only splitView is a Split View scenario', () {
      expect(DuoScenario.splitView.isSplitView, isTrue);
      for (final s in DuoScenario.core) {
        expect(s.isSplitView, isFalse, reason: s.name);
      }
    });

    test('splitView is narrower than the open display and has no fold', () {
      final split = DuoScenario.splitView.mediaQuery();
      final open = DuoScenario.openWide.mediaQuery();
      expect(split.size.width, lessThan(open.size.width));
      expect(split.displayFeatures, isEmpty);
    });

    test('largeText doubles the text scale', () {
      final data = DuoScenario.largeText.mediaQuery();
      expect(data.textScaler.scale(10), 20);
    });

    test('hinge readings follow the hinge state', () {
      expect(
        DuoScenario.closedPortrait.hingeReading.state,
        DuoHingeState.closed,
      );
      expect(DuoScenario.book.hingeReading.angleDegrees, 110);
      expect(DuoScenario.openWide.hingeReading.angleDegrees, 180);
    });
  });

  testDuoWidgets('centered content stays inside the safe area',
      (tester, scenario) async {
    await pumpDuo(
      tester,
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Hello'))),
      ),
      scenario: scenario,
    );
    expectInsideSafeArea(tester, find.text('Hello'), scenario);
  });
}
