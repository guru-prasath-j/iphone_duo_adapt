import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:iphone_duo_adapt_example/main.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MailApp());
    await tester.pumpAndSettle();
  }

  testWidgets('closed: bottom bar, tap opens a page', (tester) async {
    await pumpAt(tester, DuoDeviceSpec.iPhoneDuo.outerPortrait);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Message 2'));
    await tester.pumpAndSettle();
    expect(find.text('Message 1'), findsNothing);
  });

  testWidgets('open: side rail with list and message together',
      (tester) async {
    await pumpAt(tester, DuoDeviceSpec.iPhoneDuo.innerWide);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Select a message'), findsOneWidget);
    await tester.tap(find.text('Message 2'));
    await tester.pumpAndSettle();
    expect(find.text('Message 1'), findsOneWidget);
    expect(find.text('Message 2'), findsNWidgets(2));
  });
}
