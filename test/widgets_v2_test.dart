import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:flutter_iphone_duo_adapt/testing.dart';

Widget _app(Widget home, {DuoAdaptConfig? config}) => MaterialApp(
      builder: DuoAdapt.builder(
        config: config ?? const DuoAdaptConfig(useNativeBridge: false),
      ),
      home: home,
    );

List<BottomNavigationBarItem> _items(int n) => <BottomNavigationBarItem>[
      for (var i = 0; i < n; i++)
        BottomNavigationBarItem(
            icon: const Icon(Icons.circle), label: 'Tab $i'),
    ];

void main() {
  group('DuoAdaptiveScaffold', () {
    testWidgets('overflow goes into a More menu, selection stays visible', (
      tester,
    ) async {
      int? tapped;
      await pumpDuo(
        tester,
        _app(
          DuoAdaptiveScaffold(
            maxDestinations: 5,
            scaffold: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: 7,
                onTap: (i) => tapped = i,
                items: _items(9),
              ),
            ),
          ),
        ),
        scenario: DuoScenario.openWide,
      );
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(4));
      expect(find.text('Tab 7'), findsOneWidget, reason: 'selected kept');
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab 8').last);
      await tester.pumpAndSettle();
      expect(tapped, 8);
    });

    testWidgets('app bar actions move to the rail when enabled', (
      tester,
    ) async {
      await pumpDuo(
        tester,
        _app(
          DuoAdaptiveScaffold(
            moveAppBarActionsToRail: true,
            scaffold: Scaffold(
              appBar: AppBar(
                title: const Text('Mail'),
                actions: <Widget>[
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                ],
              ),
              body: const SizedBox.expand(),
              bottomNavigationBar: BottomNavigationBar(items: _items(2)),
            ),
          ),
        ),
        scenario: DuoScenario.openWide,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.search),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.search),
        ),
        findsNothing,
      );
    });

    testWidgets('rail sits on the right in RTL', (tester) async {
      await pumpDuo(
        tester,
        MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: DuoAdapt(child: child!),
          ),
          home: DuoAdaptiveScaffold(
            scaffold: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: BottomNavigationBar(items: _items(3)),
            ),
          ),
        ),
        scenario: DuoScenario.openWide,
      );
      final rail = tester.getRect(find.byType(NavigationRail));
      expect(rail.left, greaterThan(400));
    });

    testWidgets('custom rail builder replaces the rail', (tester) async {
      await pumpDuo(
        tester,
        _app(
          DuoAdaptiveScaffold(
            railBuilder: (context, data) =>
                Text('custom ${data.navigation.destinations.length}'),
            scaffold: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: BottomNavigationBar(items: _items(3)),
            ),
          ),
        ),
        scenario: DuoScenario.openWide,
      );
      expect(find.text('custom 3'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('DuoCupertinoTabScaffold', () {
    Widget cupertinoApp() => CupertinoApp(
          builder: DuoAdapt.builder(
            config: const DuoAdaptConfig(useNativeBridge: false),
          ),
          home: DuoCupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.settings),
                  label: 'Settings',
                ),
              ],
            ),
            tabBuilder: (context, i) => Center(child: Text('Page $i')),
          ),
        );

    testWidgets('tab bar when closed, rail when open', (tester) async {
      await pumpDuo(
        tester,
        cupertinoApp(),
        scenario: DuoScenario.closedPortrait,
      );
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);

      await pumpDuo(tester, cupertinoApp(), scenario: DuoScenario.openWide);
      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
    });
  });

  group('fold-aware layouts', () {
    testWidgets('DuoFoldAvoid keeps content on the end side in book pose', (
      tester,
    ) async {
      await pumpDuo(
        tester,
        _app(
          const DuoFoldAvoid(
            child: ColoredBox(
              color: Colors.red,
              child: SizedBox.expand(key: Key('c')),
            ),
          ),
        ),
        scenario: DuoScenario.book,
      );
      final info = duoLayoutOf(tester, find.byKey(const Key('c')));
      final rect = tester.getRect(find.byKey(const Key('c')));
      expect(rect.left, greaterThanOrEqualTo(info.fold!.right - 0.5));
      expectClearOfFold(tester, find.byKey(const Key('c')));
    });

    testWidgets('DuoFoldAvoid moves to the bottom half in tabletop pose', (
      tester,
    ) async {
      await pumpDuo(
        tester,
        _app(const DuoFoldAvoid(child: SizedBox.expand(key: Key('c')))),
        scenario: DuoScenario.tabletop,
      );
      final info = duoLayoutOf(tester, find.byKey(const Key('c')));
      expect(
        tester.getRect(find.byKey(const Key('c'))).top,
        greaterThanOrEqualTo(info.fold!.bottom - 0.5),
      );
    });

    testWidgets(
      'DuoArrangement overlay floats when compact, splits when open',
      (tester) async {
        Widget build() => _app(
              const DuoArrangement(
                style: DuoArrangementStyle.overlay,
                primary: SizedBox.expand(key: Key('p')),
                secondary: SizedBox(key: Key('s'), height: 100, width: 200),
              ),
            );
        await pumpDuo(tester, build(), scenario: DuoScenario.closedPortrait);
        final p = tester.getRect(find.byKey(const Key('p')));
        final s = tester.getRect(find.byKey(const Key('s')));
        expect(p.overlaps(s), isTrue);

        await pumpDuo(tester, build(), scenario: DuoScenario.openWide);
        final p2 = tester.getRect(find.byKey(const Key('p')));
        final s2 = tester.getRect(find.byKey(const Key('s')));
        expect(s2.left, greaterThanOrEqualTo(p2.right - 0.5));
      },
    );

    testWidgets('Flutter dialogs stay off the fold', (tester) async {
      await pumpDuo(
        tester,
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Delete?'),
                    content: Text('Really delete it?'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        scenario: DuoScenario.book,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectClearOfFold(tester, find.byType(AlertDialog));
    });

    testWidgets('DuoLayoutSwitcher picks the right builder', (tester) async {
      Widget build() => _app(
            DuoLayoutSwitcher(
              compact: (_) => const Text('compact'),
              regular: (_) => const Text('regular'),
              book: (_) => const Text('book'),
              tabletop: (_) => const Text('tabletop'),
            ),
          );
      for (final (scenario, expected) in <(DuoScenario, String)>[
        (DuoScenario.closedPortrait, 'compact'),
        (DuoScenario.openWide, 'regular'),
        (DuoScenario.book, 'book'),
        (DuoScenario.tabletop, 'tabletop'),
        (DuoScenario.splitView, 'compact'),
      ]) {
        await pumpDuo(tester, build(), scenario: scenario);
        expect(find.text(expected), findsOneWidget, reason: scenario.name);
      }
    });
  });

  group('state and events', () {
    testWidgets('DuoSlot keeps state when the layout moves it', (tester) async {
      final wide = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: wide,
            builder: (context, w, _) {
              const counter = DuoSlot(id: 'counter', child: _Counter());
              return w
                  ? const Row(children: <Widget>[counter, Text('side')])
                  : const Column(children: <Widget>[counter]);
            },
          ),
        ),
      );
      await tester.tap(find.byType(_Counter));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      wide.value = true;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('DuoPostureObserver reports fold and unfold', (tester) async {
      final events = <String>[];
      final posture = ValueNotifier<DuoScenario>(DuoScenario.closedPortrait);
      await tester.pumpWidget(
        ValueListenableBuilder<DuoScenario>(
          valueListenable: posture,
          builder: (context, s, _) => MediaQuery(
            data: s.mediaQuery(),
            child: DuoAdapt(
              config: const DuoAdaptConfig(useNativeBridge: false),
              hinge: s.hingeReading,
              child: DuoPostureObserver(
                onChanged: (a, b) =>
                    events.add('${a.posture.name}>${b.posture.name}'),
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      posture.value = DuoScenario.openWide;
      await tester.pump();
      await tester.pump();
      posture.value = DuoScenario.closedPortrait;
      await tester.pump();
      await tester.pump();
      expect(events, <String>[
        'closedPortrait>openWide',
        'openWide>closedPortrait',
      ]);
    });

    testWidgets('hinge builder and listener see readings', (tester) async {
      final angle = ValueNotifier<DuoHingeReading?>(
        DuoHingeReading.fromAngle(100),
      );
      final seen = <double?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DuoAdapt(
            config: const DuoAdaptConfig(useNativeBridge: false),
            hingeSource: angle,
            child: DuoHingeListener(
              onChanged: (_, now) => seen.add(now?.angleDegrees),
              child: DuoHingeBuilder(
                builder: (context, h) => Text('${h?.angleDegrees?.round()}'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('100'), findsOneWidget);
      angle.value = DuoHingeReading.fromAngle(150);
      await tester.pump();
      await tester.pump();
      expect(find.text('150'), findsOneWidget);
      expect(seen, <double?>[150]);
    });

    testWidgets('native bridge features are merged into MediaQuery', (
      tester,
    ) async {
      addTearDown(() => DuoNativeBridge.instance.debugSetState(null));
      late MediaQueryData seen;
      late DuoLayoutInfo info;
      tester.view.physicalSize = const Size(890, 626) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      DuoNativeBridge.instance.debugSetState(
        const DuoNativeState(
          supported: true,
          hinge: DuoHingeReading(
            state: DuoHingeState.halfOpened,
            angleDegrees: 95,
            source: DuoHingeSource.native,
          ),
          features: <DisplayFeature>[
            DisplayFeature(
              bounds: Rect.fromLTWH(425, 0, 40, 626),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        DuoAdapt(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              info = DuoLayoutInfo.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.displayFeatures, hasLength(1));
      expect(info.foldPose, DuoFoldPose.book);
      expect(info.hingeAngle, 95);
    });

    testWidgets('DuoListDetailController selects from outside', (tester) async {
      final controller = DuoListDetailController<int>();
      final changes = <int?>[];
      await pumpDuo(
        tester,
        _app(
          Scaffold(
            body: DuoListDetail<int>(
              controller: controller,
              onSelectionChanged: changes.add,
              listBuilder: (context, selected, onSelect) =>
                  Text('list $selected'),
              detailBuilder: (context, item) => Text('detail $item'),
            ),
          ),
        ),
        scenario: DuoScenario.openWide,
      );
      controller.select(4);
      await tester.pumpAndSettle();
      expect(find.text('detail 4'), findsOneWidget);
      expect(find.text('list 4'), findsOneWidget);
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.text('detail 4'), findsNothing);
      expect(changes, <int?>[4, null]);
    });
  });

  group('testing kit', () {
    testDuoWidgets(
      'safe-area check catches content under the cutout',
      (tester, scenario) async {
        await pumpDuo(
          tester,
          _app(
            const Scaffold(
              body: SafeArea(
                child: Center(child: Text('safe', key: Key('t'))),
              ),
            ),
          ),
          scenario: scenario,
        );
        expectInsideSafeArea(tester, find.byKey(const Key('t')), scenario);
        expectClearOfFold(tester, find.byKey(const Key('t')));
      },
      scenarios: const <DuoScenario>[
        DuoScenario.closedPortrait,
        DuoScenario.closedLandscape,
        DuoScenario.openWide,
      ],
    );
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: () => setState(() => _n++), child: Text('$_n'));
}
