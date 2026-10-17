## 0.2.2

### Changed
* Swift Package Manager support: the iOS plugin now lives in
  `ios/flutter_iphone_duo_adapt/Package.swift` (product
  `flutter-iphone-duo-adapt`), matching the package name, so Flutter's SPM
  integration picks it up. CocoaPods keeps working through
  `ios/flutter_iphone_duo_adapt.podspec`.
* README, `llms.txt` and the `duo_audit` / `duo_migrate` help text use the
  published name: `flutter pub add flutter_iphone_duo_adapt` and
  `dart run flutter_iphone_duo_adapt:duo_audit`.
* `duo_migrate` detects the package in `pubspec.yaml` under its published
  name.

## 0.2.1

### Fixes
* `package:iphone_duo_adapt/testing.dart` did not compile: the
  `DuoScenario.splitView` constant clashed with the instance field of the
  same name. The field is now `DuoScenario.isSplitView` (constructor
  parameter `isSplitView:`); `DuoScenario.splitView`, `core` and `all` are
  unchanged. This also restores the static analysis, platform support and
  dependency-lower-bound pub points lost in 0.2.0.
* `duo_migrate`: when a file starts directly with a wrapped `Scaffold`, the
  import was inserted inside `DuoAdaptiveScaffold(scaffold: ...` and a second
  run wrapped the scaffold again. The import now always goes first, so
  migration is idempotent.

### Tests
* New tests for the test kit: every `DuoScenario` (Split View width, text
  scale, hinge readings) and a `testDuoWidgets` / `pumpDuo` /
  `expectInsideSafeArea` smoke test across the core scenarios.

## 0.2.0

Full iPhone Duo coverage. See doc/coverage.md for the mapping to Apple's
guidance.

### Runtime
* **Native iOS bridge**: reads `UIHingeInteraction` (status and angle) and
  `UIView` reserved regions (fold and camera) on iOS 27.1 and merges them
  into `MediaQuery.displayFeatures`. Compiles to a stub with older Xcode.
  Steps aside automatically once the Flutter engine reports folds itself.
* `DuoAdaptConfig`: every setting in one place, shared through `DuoAdapt`,
  with per-widget overrides and a custom `layoutResolver`.
* `DuoLayoutInfo`: adds height class, fold pose (book / tabletop), hinge
  angle, padding, `canSplit`, `areaFor`, `copyWith`, `toJson`.
* New widgets: `DuoCupertinoTabScaffold`, `DuoArrangement` (Apple's
  `ArrangementView`), `DuoFoldAvoid`, `DuoConstrained`, `DuoLayoutSwitcher`,
  `DuoLayoutBuilder`, `DuoSlot`, `DuoPostureObserver`, `DuoHingeBuilder`,
  `DuoHingeListener`.
* `DuoAdaptiveScaffold`: overflow "More" menu, app bar actions on the rail,
  RTL, custom `railBuilder`, extended rail, both edges clear of cutouts, body
  state kept across layout switches.
* `DuoListDetail`: controller, selection callback, tabletop and RTL splits,
  back-to-list when folding.
* `DuoSplit`: tabletop (top/bottom) splits, RTL, vertical axis, minimum pane
  size, pane state kept.
* `DuoPreview`: hinge angle slider, Split View, text size, info panel.
* Debug logging of layout changes as JSON.

### Tooling
* `package:iphone_duo_adapt/testing.dart`: `pumpDuo`, `testDuoWidgets`,
  `DuoScenario` (8 states), `expectClearOfFold`, `expectInsideSafeArea`,
  `expectDuoGolden`.
* `duo_audit`: 22 rules across Dart, native iOS, Info.plist and the Android
  manifest; `iphone_duo_adapt.yaml` config (severities, excludes, custom
  rules); text, JSON, Markdown and GitHub formats; `--checklist`.
* `duo_migrate`: adds `DuoAdapt`, wraps scaffolds, swaps Cupertino tab
  scaffolds; dry run by default; JSON output.
* `AGENTS.md` and `llms.txt` for AI agents.

### Fixes
* Rotating or unfolding with a detail page open now shows the split view
  (the scaffold used to reset its body).
* The body no longer runs under the camera cutout opposite the rail.

## 0.1.0

First release.

* `DuoAdapt` wrapper and `DuoAdapt.builder()` for `MaterialApp.builder`.
* `DuoLayoutInfo`: posture, size class, hinge state, folds and occlusions,
  derived from `MediaQuery.displayFeatures`.
* `DuoAdaptiveScaffold`: moves an existing `BottomNavigationBar`,
  `NavigationBar` or `CupertinoTabBar` to a side rail on wide screens.
* `DuoListDetail` and `DuoSplit`: fold-aware two-pane layouts.
* `DuoPreview`: simulate all four iPhone Duo postures and hinge states.
* `DuoSimulation` and `featureSource` for testing and native bridges.
* `duo_audit` CLI with 8 rules for code that breaks on foldables.
