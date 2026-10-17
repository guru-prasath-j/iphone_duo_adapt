# flutter_iphone_duo_adapt

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Make an existing Flutter app **iPhone Duo ready**, without rewriting it.

The iPhone Duo changes screen size while your app runs (466 pt closed, 890 pt
open), ignores orientation locks on the inner display, puts a crease down the
middle when bent, and moves tab bars to a vertical side bar. This package
handles all of it:

| Layer | What you get |
|---|---|
| **Native bridge** (iOS 27.1) | Real hinge status, hinge angle, fold and camera regions from `UIHingeInteraction` and `reservedRegions`, fed into Flutter today. |
| **One-line wrapper** | `DuoAdapt.builder()` makes fold data available everywhere; Flutter's own dialogs, sheets and menus then stay off the fold. |
| **Retrofits** | `DuoAdaptiveScaffold` (bottom bar → side rail), `DuoCupertinoTabScaffold`, `DuoListDetail` (list + detail side by side). |
| **Fold-aware building blocks** | `DuoSplit`, `DuoArrangement` (like Apple's `ArrangementView`), `DuoFoldAvoid`, `DuoConstrained`, `DuoLayoutSwitcher`, `DuoSlot`. |
| **Events** | `DuoPostureObserver` (fold/unfold), `DuoHingeListener` / `DuoHingeBuilder` (angle). |
| **Preview** | Every posture, hinge angle, Split View and text size on your desktop. |
| **Test kit** | `testDuoWidgets` runs a test in every Duo state; `expectClearOfFold`, `expectInsideSafeArea`, goldens. |
| **Audit** | `duo_audit` finds 20+ problems in Dart, iOS and Android files, with fixes. JSON, Markdown and GitHub output. |
| **Auto-migration** | `duo_migrate` applies the retrofit to your code. |

Everything is configurable through one `DuoAdaptConfig`, with per-widget
overrides and builder hooks. See [AGENTS.md](AGENTS.md) if you are an AI
agent (or want a deterministic recipe).

## Install

```sh
flutter pub add flutter_iphone_duo_adapt
```

## Retrofit an app in three commands

```sh
dart run flutter_iphone_duo_adapt:duo_audit              # what breaks, and where
dart run flutter_iphone_duo_adapt:duo_migrate --apply     # apply the safe fixes
dart format lib && flutter analyze && flutter test
```

`duo_migrate` adds `DuoAdapt` to your app widget, wraps scaffolds that have a
bottom bar, and swaps `CupertinoTabScaffold` for `DuoCupertinoTabScaffold`.
It shows a diff first and only writes with `--apply`. Then work through the
rest of the audit and `duo_audit --checklist`.

## By hand

### 1. The wrapper

```dart
MaterialApp(
  builder: DuoAdapt.builder(),          // keeps any builder you had: inner: ...
  home: const HomePage(),
)
```

### 2. Bottom bar → side rail

```dart
return DuoAdaptiveScaffold(
  scaffold: Scaffold(
    appBar: AppBar(title: const Text('Inbox'), actions: [...]),
    body: const InboxList(),
    bottomNavigationBar: BottomNavigationBar(...), // or NavigationBar
  ),
);
```

On compact screens nothing changes. From regular width the bar becomes a
`NavigationRail`. The body keeps its state; rail and body keep clear of the
camera cutout on both sides (LTR and RTL); extra destinations go into a
"More" menu; `moveAppBarActionsToRail: true` moves toolbar actions onto the
rail like iOS does. Replace the rail entirely with `railBuilder`.

Cupertino apps: rename `CupertinoTabScaffold` to `DuoCupertinoTabScaffold`.
Same constructor; each tab keeps its navigation stack.

### 3. List and detail

```dart
DuoListDetail<Message>(
  listBuilder: (context, selected, onSelect) =>
      MessageList(selected: selected, onTap: onSelect),
  detailBuilder: (context, message) => MessageView(message),
  emptyDetail: const Center(child: Text('Select a message')),
  controller: controller, // optional: select from a deep link or a test
)
```

Closed: tapping pushes a page. Open: side by side, split exactly at the fold
when bent. Unfolding with a page open turns it into the split with the same
item selected; the list keeps its scroll position.

### 4. Fold-aware layouts

```dart
DuoSplit(first: map, second: details)                 // two panes
DuoArrangement(primary: photo, secondary: info,
    style: DuoArrangementStyle.overlay)                // Apple's ArrangementView
DuoFoldAvoid(child: checkoutButton)                    // never on the crease
DuoConstrained(child: legacyScreen)                    // safe fallback
DuoLayoutSwitcher(compact: ..., regular: ..., book: ..., tabletop: ...)
DuoSlot(id: 'player', child: videoPlayer)              // keep state anywhere
```

Book pose (vertical fold) splits left/right; tabletop pose (horizontal fold)
splits top/bottom; interactive content goes to the end side (Apple's
guidance), configurable with `DuoAdaptConfig.foldSide`.

### 5. React to folding and the hinge

```dart
DuoPostureObserver(
  onChanged: (before, after) {
    if (before.isOpen != after.isOpen) camera.reselect(); // the Duo has 3
  },
  child: ...,
)

DuoHingeBuilder(
  builder: (context, hinge) => Transform.rotate(
    angle: (180 - (hinge?.angleDegrees ?? 180)) / 180 * 0.3,
    child: lid,
  ),
)
```

Apple advises using the hinge angle for effects only, never for layout.

## Configuration

```dart
DuoAdapt.builder(
  config: DuoAdaptConfig(
    regularWidthBreakpoint: 600,   // rail + two panes from here
    compactHeightBreakpoint: 480,
    splitRatio: 0.4,
    minPaneExtent: 280,
    foldSide: DuoFoldSide.end,
    railLabelType: NavigationRailLabelType.all,
    railMaxDestinations: 7,
    moveAppBarActionsToRail: false,
    transitionDuration: Duration(milliseconds: 200),
    useNativeBridge: true,
    deviceSpec: DuoDeviceSpec.iPhoneDuo,
    layoutResolver: null,          // replace the detection entirely
    debugLog: kDebugMode,          // logs every posture change as JSON
  ),
)
```

Every widget takes overrides (`ratio:`, `side:`, `showRail:`, `splitWhen:`,
`railBuilder:`, ...). `DuoLayoutInfo` is a plain value with a public
constructor and `toJson()`, so a custom resolver can return anything.

## Where the fold data comes from

| Source | Status |
|---|---|
| iOS 27.1 native bridge (this package) | Live when the app is built with Xcode 27.1. Built with an older Xcode it compiles to a stub and reports `supported: false`. |
| Flutter engine on iOS | Coming with [flutter/flutter#193025](https://github.com/flutter/flutter/pull/193025). The bridge then steps aside automatically (no doubled folds). |
| Android foldables | Works today through Flutter's `displayFeatures`. |
| Your own source | `featureSource:` and `hingeSource:` on `DuoAdapt`. |
| Previews and tests | `DuoPreview`, `DuoSimulation`, `pumpDuo`. |

Without any fold data, a screen whose shortest side is at least 560 pt is
treated as the open inner display, so bars and panes adapt regardless.

## Preview

```dart
void main() => runApp(DuoPreview(enabled: kDebugMode, child: const MyApp()));
```

Run on macOS, Windows, Linux or web: switch postures, drag the hinge angle,
try Split View and large text, and open the live `DuoLayoutInfo` panel.

## Testing

```dart
import 'package:flutter_iphone_duo_adapt/testing.dart';

testDuoWidgets('pay button is always usable', (tester, scenario) async {
  await pumpDuo(tester, const MyApp(), scenario: scenario);
  expectClearOfFold(tester, find.text('Pay'));
  expectInsideSafeArea(tester, find.text('Pay'), scenario);
  await expectDuoGolden(tester, 'checkout-${scenario.name}'); // optional
}, scenarios: DuoScenario.all);
```

Scenarios: `closedPortrait`, `closedLandscape`, `openWide`, `openTall`,
`book`, `tabletop`, `splitView`, `largeText`.

## Audit

```sh
dart run flutter_iphone_duo_adapt:duo_audit [paths] [--format=text|json|markdown|github] [--fail-on=warning]
dart run flutter_iphone_duo_adapt:duo_audit --rules       # list rules
dart run flutter_iphone_duo_adapt:duo_audit --checklist   # what a scan cannot see
```

Scans `lib/`, native iOS sources, `ios/Runner/Info.plist` and the Android
manifest. Rules cover raw screen reads, cached sizes, orientation locks and
branches, exact iPhone widths, width-based scaling (screenutil, sizer),
width-based fonts, device-type branching, phone aspect ratios, bottom bars,
`CupertinoTabScaffold`, `cameras.first`, "Face ID" in UI text (the Duo uses
Touch ID), `UIScreen.main`, native orientation and idiom checks,
`UIRequiresFullScreen`, missing UIScene manifest, portrait-only plists,
and Android orientation locks and non-resizeable activities.

Customise with `iphone_duo_adapt.yaml` in your project root:

```yaml
duo_audit:
  exclude:
    - lib/generated/**
  rules:
    bottom-bar: off
    orientation-lock: error
  custom_rules:
    - id: no-legacy-sizer
      severity: warning
      pattern: "LegacySizer\\("
      message: LegacySizer scales with screen width.
      fix: Use DuoLayoutBuilder.
```

Silence a line with `// duo-ignore: <rule-id>`, a file with
`// duo-ignore-file: <rule-id>`.

## Coverage

[doc/coverage.md](doc/coverage.md) maps every item in Apple's iPhone Duo
guidance to the part of this package that handles it, and lists what is
out of scope for a Flutter package.

## License

MIT
