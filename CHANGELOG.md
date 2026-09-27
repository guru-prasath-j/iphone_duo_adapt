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
