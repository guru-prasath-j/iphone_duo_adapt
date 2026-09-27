# iphone_duo_adapt

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Get your existing Flutter app ready for **iPhone Duo** (and Android foldables)
without rewriting it.

Other foldable packages give you raw hinge data and leave the layout work
to you. `iphone_duo_adapt` is a **retrofit layer**: wrap what you already have and
it adapts.

| You have | Add | On the unfolded Duo you get |
|---|---|---|
| `MaterialApp(...)` | `builder: DuoAdapt.builder()` | Fold data everywhere, dialogs and sheets that stay off the fold |
| `Scaffold(bottomNavigationBar: ...)` | wrap in `DuoAdaptiveScaffold` | The bottom bar becomes a side rail, like iOS 27.1 tab bars |
| A list that pushes a detail page | `DuoListDetail` | List and detail side by side, split at the fold |
| No Duo to test on | `DuoPreview` | All four postures and hinge states on your desktop |
| A codebase you don't know yet | `dart run iphone_duo_adapt:duo_audit` | A list of lines that will break, with fixes |

## Install

```yaml
dependencies:
  iphone_duo_adapt: ^0.1.0
```

## 1. Make the app fold-aware (one line)

```dart
MaterialApp(
  builder: DuoAdapt.builder(),
  home: const HomePage(),
)
```

`DuoAdapt` reads `MediaQuery.displayFeatures`, the same fold data Flutter
already reports on Android foldables. Flutter's own `showDialog` and
`showModalBottomSheet` use that data to stay on one side of a bent fold, so
they start behaving correctly with no other change.

## 2. Move bottom bars to the side

```dart
return DuoAdaptiveScaffold(
  scaffold: Scaffold(
    appBar: AppBar(title: const Text('Inbox')),
    body: const InboxList(),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: tab,
      onTap: (i) => setState(() => tab = i),
      items: items,
    ),
  ),
);
```

On a narrow screen your scaffold is returned untouched. From 600 pt wide
(the unfolded Duo, a sideways phone, a tablet) the bar's items, selection
and tap handler move to a `NavigationRail`. `BottomNavigationBar`,
`NavigationBar` and `CupertinoTabBar` are read automatically. For anything
else, pass `navigation: DuoNavigation(...)`.

## 3. Show list and detail together

```dart
DuoListDetail<Message>(
  listBuilder: (context, selected, onSelect) => MessageList(
    selected: selected,
    onTap: onSelect,
  ),
  detailBuilder: (context, message) => MessageView(message),
  emptyDetail: const Center(child: Text('Select a message')),
)
```

* **Closed:** tapping pushes the detail as a normal page.
* **Open, flat:** list 40% / detail 60%.
* **Open, bent:** the split lines up exactly with the fold.
* Unfold while a detail page is open, and the page closes and the same item
  shows in the split. The list keeps its scroll position.

For any two widgets, use `DuoSplit(first: ..., second: ...)`.

## 4. Preview without a Duo

```dart
void main() => runApp(
      DuoPreview(enabled: kDebugMode, child: const MyApp()),
    );
```

Run on macOS, Windows, Linux or web and switch between **Closed**,
**Closed sideways**, **Open tall** and **Open wide**, and between a **bent**
and **flat** hinge. The fold is drawn in red.

## 5. Audit your code

```sh
dart run iphone_duo_adapt:duo_audit lib
```

```
lib/main.dart:12:3 warning [orientation-lock] Orientation lock. The iPhone
Duo inner display does not honour supported orientations...
    fix: Make the layout work at any aspect ratio...
```

| Rule | Severity | Catches |
|---|---|---|
| `physical-size` | error | `window.physicalSize`, `views.first`: stale when the device folds |
| `static-screen-size` | error | `MediaQuery...size` cached in a field |
| `orientation-lock` | warning | `setPreferredOrientations`: ignored on the inner display |
| `device-width-constant` | warning | `width <= 375` and other exact iPhone widths |
| `cupertino-tab-scaffold` | warning | tab bar that can only live at the bottom |
| `first-camera` | warning | `cameras.first`: the Duo has three cameras |
| `bottom-bar` | info | bottom bars that `DuoAdaptiveScaffold` can move |
| `orientation-branch` | info | layouts chosen by portrait/landscape instead of width |

Flags: `--json`, `--fail-on=info|warning|error|none` (default `error`),
`--rules`. Silence a line with `// duo-ignore: <rule-id>` or a file with
`// duo-ignore-file: <rule-id>`.

## Where the fold data comes from

| Platform | Status |
|---|---|
| Android foldables | Works today. Flutter reports folds and hinges. |
| iPhone Duo | Size, safe areas and open/closed work today. The fold rectangle arrives once [flutter/flutter#193025](https://github.com/flutter/flutter/pull/193025) lands. |

Until then, feed fold data from a native bridge (for example
[`foldable`](https://github.com/berkaycatak/foldable) or
[`nitro_fold_duo`](https://github.com/Shreemanarjun/nitro_fold_duo)) through
`featureSource`:

```dart
final folds = ValueNotifier<List<DisplayFeature>>(const []);
// Update `folds.value` from your bridge's stream.

MaterialApp(builder: DuoAdapt.builder(featureSource: folds), ...)
```

Everything in this package, and Flutter's own dialogs, then uses it.

Without fold data, the package still treats a screen whose shortest side is
at least 560 pt as the open inner display, so bars and panes adapt on day one.

## API at a glance

```dart
final info = DuoLayoutInfo.of(context);
info.posture;     // closedPortrait, closedLandscape, openTall, openWide
info.widthClass;  // compact, regular
info.hingeState;  // closed, halfOpened, flat
info.fold;        // Rect? dividing the screen
info.foldAxis;    // Axis.vertical = left/right halves
info.panes();     // (Rect, Rect)? either side of the fold
```

Test with a fake fold on any device:

```dart
DuoAdapt.builder(simulation: const DuoSimulation(), showFoldOverlay: true)
```

## Notes

* Screen sizes for the preview (outer 466 x 678 pt, inner 890 x 626 pt) are
  worked out from Apple's published pixel counts at 3x. Check them against
  the Xcode 27.1 simulator and pass your own `DuoDeviceSpec` if they differ.
* `DuoAdaptiveScaffold` moves the body into a new parent when the layout
  switches. Keep important state above the scaffold or keyed.
* The example app in `example/` has no platform folders. Run
  `flutter create .` inside it first.

## License

MIT
