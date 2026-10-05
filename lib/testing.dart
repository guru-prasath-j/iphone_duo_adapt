/// Test helpers: run widget tests in every iPhone Duo state and check that
/// nothing sits on the fold or outside the safe area.
///
/// ```dart
/// import 'package:iphone_duo_adapt/testing.dart';
///
/// void main() {
///   testDuoWidgets('checkout button stays usable', (tester, scenario) async {
///     await pumpDuo(tester, const MyApp(), scenario: scenario);
///     expectClearOfFold(tester, find.text('Pay now'));
///     expectInsideSafeArea(tester, find.text('Pay now'), scenario);
///   });
/// }
/// ```
///
/// Import this only from tests: it depends on `flutter_test`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'iphone_duo_adapt.dart';

/// One device state to test in.
@immutable
class DuoScenario {
  /// Creates a scenario.
  const DuoScenario(
    this.name,
    this.posture, {
    this.hinge = DuoHingeState.flat,
    this.isSplitView = false,
    this.textScale = 1,
  });

  /// Outer display, upright.
  static const DuoScenario closedPortrait = DuoScenario(
      'closed-portrait', DuoPosture.closedPortrait,
      hinge: DuoHingeState.closed);

  /// Outer display, sideways.
  static const DuoScenario closedLandscape = DuoScenario(
      'closed-landscape', DuoPosture.closedLandscape,
      hinge: DuoHingeState.closed);

  /// Inner display, flat, wide.
  static const DuoScenario openWide =
      DuoScenario('open-wide', DuoPosture.openWide);

  /// Inner display, flat, tall.
  static const DuoScenario openTall =
      DuoScenario('open-tall', DuoPosture.openTall);

  /// Inner display bent like a book (vertical fold).
  static const DuoScenario book = DuoScenario('book', DuoPosture.openWide,
      hinge: DuoHingeState.halfOpened);

  /// Inner display bent on a table (horizontal fold).
  static const DuoScenario tabletop = DuoScenario(
      'tabletop', DuoPosture.openTall,
      hinge: DuoHingeState.halfOpened);

  /// Half of the inner display, beside another app.
  static const DuoScenario splitView =
      DuoScenario('split-view', DuoPosture.openWide, isSplitView: true);

  /// Outer display with 2x text.
  static const DuoScenario largeText = DuoScenario(
      'large-text', DuoPosture.closedPortrait,
      hinge: DuoHingeState.closed, textScale: 2);

  /// The six postures and hinge states.
  static const List<DuoScenario> core = <DuoScenario>[
    closedPortrait,
    closedLandscape,
    openWide,
    openTall,
    book,
    tabletop,
  ];

  /// Everything, including Split View and large text.
  static const List<DuoScenario> all = <DuoScenario>[
    ...core,
    splitView,
    largeText,
  ];

  /// File-safe name.
  final String name;

  /// Posture.
  final DuoPosture posture;

  /// Hinge state (only [DuoHingeState.halfOpened] adds a fold).
  final DuoHingeState hinge;

  /// App on half the inner display, beside another app.
  final bool isSplitView;

  /// Text scale factor.
  final double textScale;

  /// Hinge reading this scenario reports.
  DuoHingeReading get hingeReading => DuoHingeReading(
        state: hinge,
        angleDegrees: switch (hinge) {
          DuoHingeState.closed => 0,
          DuoHingeState.halfOpened => 110,
          DuoHingeState.flat => 180,
        },
      );

  /// Screen metrics for this scenario.
  MediaQueryData mediaQuery({
    DuoDeviceSpec spec = DuoDeviceSpec.iPhoneDuo,
    MediaQueryData base = const MediaQueryData(),
  }) {
    var data = spec.mediaQueryFor(base, posture, hinge);
    if (isSplitView) {
      final full = data.size;
      data = data.copyWith(
        size: posture == DuoPosture.openWide
            ? Size(full.width / 2 - 4, full.height)
            : Size(full.width, full.height / 2 - 4),
        displayFeatures: const [],
      );
    }
    return data.copyWith(textScaler: TextScaler.linear(textScale));
  }

  @override
  String toString() => 'DuoScenario($name)';
}

/// Pumps [app] as if running on an iPhone Duo in [scenario].
///
/// [app] is usually your `MaterialApp` / `CupertinoApp`. It is wrapped in a
/// `DuoAdapt` that reports the scenario's hinge, so it works whether or not
/// the app adds its own `DuoAdapt`.
Future<void> pumpDuo(
  WidgetTester tester,
  Widget app, {
  DuoScenario scenario = DuoScenario.openWide,
  DuoDeviceSpec spec = DuoDeviceSpec.iPhoneDuo,
  DuoAdaptConfig config = const DuoAdaptConfig(useNativeBridge: false),
  bool settle = true,
}) async {
  final data = scenario.mediaQuery(spec: spec);
  tester.view.physicalSize = data.size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: scenario.mediaQuery(
        spec: spec,
        base: MediaQueryData.fromView(tester.view),
      ),
      child: DuoAdapt(
        config: config,
        hinge: scenario.hingeReading,
        child: app,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  // DuoSplit and DuoFoldAvoid measure their position after the first frame.
  await tester.pump();
}

/// Registers one `testWidgets` per scenario, named
/// `'<description> [<scenario>]'`.
void testDuoWidgets(
  String description,
  Future<void> Function(WidgetTester tester, DuoScenario scenario) body, {
  List<DuoScenario> scenarios = DuoScenario.core,
  bool? skip,
  Object? tags,
}) {
  for (final s in scenarios) {
    testWidgets('$description [${s.name}]', (tester) => body(tester, s),
        skip: skip, tags: tags);
  }
}

/// Layout info as seen by the first widget [finder] matches.
DuoLayoutInfo duoLayoutOf(WidgetTester tester, Finder finder) =>
    DuoLayoutInfo.of(tester.element(finder.first));

/// Fails if any widget [finder] matches overlaps a fold (tolerance
/// [tolerance] logical pixels). Passes trivially when there is no fold.
void expectClearOfFold(
  WidgetTester tester,
  Finder finder, {
  double tolerance = 0.5,
  String? reason,
}) {
  expect(finder, findsWidgets, reason: 'nothing to check: $finder');
  for (final element in finder.evaluate()) {
    final folds = DuoLayoutInfo.of(element).folds;
    final rect = _globalRect(element).deflate(tolerance);
    for (final fold in folds) {
      expect(
        rect.overlaps(fold),
        isFalse,
        reason: reason ??
            '${element.widget.runtimeType} at $rect overlaps the fold at '
                '$fold',
      );
    }
  }
}

/// Fails if any widget [finder] matches lies outside the safe area of
/// [scenario] (camera cutout, rounded corners, home indicator).
void expectInsideSafeArea(
  WidgetTester tester,
  Finder finder,
  DuoScenario scenario, {
  DuoDeviceSpec spec = DuoDeviceSpec.iPhoneDuo,
  double tolerance = 0.5,
  String? reason,
}) {
  expect(finder, findsWidgets, reason: 'nothing to check: $finder');
  final data = scenario.mediaQuery(spec: spec);
  final safe = data.padding.deflateRect(Offset.zero & data.size);
  for (final element in finder.evaluate()) {
    final rect = _globalRect(element).deflate(tolerance);
    final inside = rect.left >= safe.left &&
        rect.top >= safe.top &&
        rect.right <= safe.right &&
        rect.bottom <= safe.bottom;
    expect(
      inside,
      isTrue,
      reason: reason ??
          '${element.widget.runtimeType} at $rect is outside the safe area '
              '$safe in ${scenario.name}',
    );
  }
}

/// Compares the whole screen against `goldens/<name>.png`. Use
/// `'<test>-${scenario.name}'` for [name] to get one image per scenario.
Future<void> expectDuoGolden(WidgetTester tester, String name) {
  return expectLater(
    find.byType(DuoAdapt).first,
    matchesGoldenFile('goldens/$name.png'),
  );
}

Rect _globalRect(Element element) {
  final box = element.renderObject;
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
