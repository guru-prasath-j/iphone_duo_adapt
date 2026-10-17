import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const DuoDeviceSpec _spec = DuoDeviceSpec.iPhoneDuo;

/// Pumps [child] as if running on a Duo in [posture].
Future<void> _pumpOn(
  WidgetTester tester,
  Widget child, {
  required DuoPosture posture,
  DuoHingeState hinge = DuoHingeState.flat,
}) async {
  final size = _spec.sizeFor(posture);
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        final data = _spec.mediaQueryFor(
          MediaQuery.of(context),
          posture,
          hinge,
        );
        return MediaQuery(
          data: data,
          child: MaterialApp(builder: DuoAdapt.builder(), home: child),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

Scaffold _legacyScaffold(ValueChanged<int> onTap) => Scaffold(
      appBar: AppBar(title: const Text('Legacy')),
      body: const Center(child: Text('body')),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: onTap,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );

void main() {
  testWidgets('scaffold keeps its bottom bar when closed', (tester) async {
    await _pumpOn(
      tester,
      DuoAdaptiveScaffold(scaffold: _legacyScaffold((_) {})),
      posture: DuoPosture.closedPortrait,
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('scaffold moves the bar to a rail when open', (tester) async {
    int? tapped;
    await _pumpOn(
      tester,
      DuoAdaptiveScaffold(scaffold: _legacyScaffold((i) => tapped = i)),
      posture: DuoPosture.openWide,
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1);
    expect(rail.destinations, hasLength(3));
    expect(find.text('body'), findsOneWidget);
    expect(find.text('Legacy'), findsOneWidget);
    await tester.tap(find.text('Me'));
    expect(tapped, 2);
  });

  testWidgets('rail layout keeps the body clear of the far-edge cutout', (
    tester,
  ) async {
    // Regression: in landscape the body ran under the camera cutout on the
    // side opposite the rail.
    tester.view.physicalSize = const Size(874, 402) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(left: 62, right: 62),
            viewPadding: const EdgeInsets.only(left: 62, right: 62),
          ),
          child: MaterialApp(
            home: DuoAdaptiveScaffold(
              scaffold: Scaffold(
                body: const SizedBox.expand(key: Key('body')),
                bottomNavigationBar: BottomNavigationBar(
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.inbox),
                      label: 'A',
                    ),
                    BottomNavigationBarItem(icon: Icon(Icons.info), label: 'B'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final body = tester.getRect(find.byKey(const Key('body')));
    expect(body.right, lessThanOrEqualTo(874 - 62));
    final rail = tester.getRect(find.byType(NavigationRail));
    expect(rail.left, greaterThanOrEqualTo(62));
  });

  testWidgets('NavigationBar is retrofitted too', (tester) async {
    await _pumpOn(
      tester,
      DuoAdaptiveScaffold(
        scaffold: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const <Widget>[
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
            ],
          ),
        ),
      ),
      posture: DuoPosture.openTall,
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  Widget listDetail() => Scaffold(
        body: DuoListDetail<int>(
          emptyDetail: const Text('pick one'),
          listBuilder: (context, selected, onSelect) => ListView(
            children: <Widget>[
              for (var i = 0; i < 5; i++)
                ListTile(
                  title: Text('Item $i'),
                  selected: selected == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
          detailBuilder: (context, item) => Text('Detail $item'),
        ),
      );

  testWidgets('list/detail pushes a route when closed', (tester) async {
    await _pumpOn(tester, listDetail(), posture: DuoPosture.closedPortrait);
    expect(find.text('pick one'), findsNothing);
    await tester.tap(find.text('Item 2'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 2'), findsOneWidget);
    expect(find.text('Item 2'), findsNothing);
  });

  testWidgets('list/detail splits when open', (tester) async {
    await _pumpOn(tester, listDetail(), posture: DuoPosture.openWide);
    expect(find.text('pick one'), findsOneWidget);
    await tester.tap(find.text('Item 3'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);
    expect(find.text('Item 3'), findsOneWidget);
  });

  testWidgets('unfolding with a detail page open shows the split', (
    tester,
  ) async {
    // Regression: the scaffold used to re-parent its body on unfold, which
    // reset DuoListDetail and left the pushed page on screen.
    final posture = ValueNotifier<DuoPosture>(DuoPosture.closedPortrait);
    tester.view.physicalSize = const Size(890, 890) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ValueListenableBuilder<DuoPosture>(
        valueListenable: posture,
        builder: (context, p, _) => MediaQuery(
          data: _spec.mediaQueryFor(
            MediaQuery.of(context),
            p,
            DuoHingeState.flat,
          ),
          child: MaterialApp(
            builder: DuoAdapt.builder(),
            home: DuoAdaptiveScaffold(
              scaffold: Scaffold(
                body: listDetail(),
                bottomNavigationBar: BottomNavigationBar(
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.inbox),
                      label: 'A',
                    ),
                    BottomNavigationBarItem(icon: Icon(Icons.info), label: 'B'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item 3'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);
    expect(find.text('Item 3'), findsNothing);

    posture.value = DuoPosture.openWide;
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Item 3'), findsOneWidget);
    expect(find.text('Detail 3'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('split panes sit either side of a bent fold', (tester) async {
    await _pumpOn(
      tester,
      const DuoSplit(
        first: ColoredBox(color: Colors.red, key: Key('a')),
        second: ColoredBox(color: Colors.blue, key: Key('b')),
      ),
      posture: DuoPosture.openWide,
      hinge: DuoHingeState.halfOpened,
    );
    await tester.pump();
    final info = DuoLayoutInfo.fromMediaQuery(
      _spec.mediaQueryFor(
        const MediaQueryData(),
        DuoPosture.openWide,
        DuoHingeState.halfOpened,
      ),
    );
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    expect(a.right, moreOrLessEquals(info.fold!.left));
    expect(b.left, moreOrLessEquals(info.fold!.right));
  });

  testWidgets('simulation injects a fold into MediaQuery', (tester) async {
    late MediaQueryData seen;
    tester.view.physicalSize = const Size(890, 626) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DuoAdapt(
        simulation: const DuoSimulation(),
        child: Builder(
          builder: (context) {
            seen = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.displayFeatures, hasLength(1));
    expect(DuoLayoutInfo.fromMediaQuery(seen).isSeparated, isTrue);
  });

  testWidgets('preview switches postures and keeps app state', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DuoPreview(
        initialPosture: DuoPosture.closedPortrait,
        child: MaterialApp(
          home: DuoAdaptiveScaffold(scaffold: _legacyScaffold((_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.tap(find.text('Open, wide'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
