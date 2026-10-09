## 0.3.0

A repair release. `package:iphone_duo_adapt/testing.dart` did not compile in
0.2.0, which cost the package its static-analysis, platform-support and
dependency-lower-bound pub points. Minor rather than patch because the fix
renames a public field.

### Breaking
* `DuoScenario.splitView` the *constant* and `DuoScenario.splitView` the
  *instance field* had the same name, which Dart does not allow: the class
  did not compile, so nothing in `testing.dart` could be used. The field and
  its constructor parameter are now `isSplitView`. The constants
  (`DuoScenario.splitView`, `.core`, `.all`, ...) keep their names, so test
  code that only names scenarios needs no change; code that passed
  `splitView:` to the `DuoScenario` constructor or read `scenario.splitView`
  should use `isSplitView`. In practice nothing could have depended on the
  old spelling, because the library never compiled.

### Fixes
* `duo_migrate`: when a file started directly with a wrapped `Scaffold`, the
  `package:iphone_duo_adapt` import was inserted inside
  `DuoAdaptiveScaffold(scaffold: ...`, and a second run wrapped the scaffold
  again. The import now always goes first, so migration is idempotent.
* CI never actually ran. `.github/workflows/ci.yml` had a YAML syntax error
  on the `duo_migrate` step (an unquoted `: ` inside a plain scalar), so
  GitHub Actions rejected the whole workflow and every push reported a
  failure without running `flutter analyze` or `flutter test`. That is how
  0.2.0 shipped with a library that does not compile. The step now uses a
  block scalar.

### Tooling
* CI additionally runs `dart format --output=none --set-exit-if-changed .`,
  resolves the example before analyzing, and has a second `downgrade` job
  that runs `flutter pub downgrade` and then analyzes and tests — the same
  check pub.dev scores for dependency lower bounds.
* The iOS podspec version follows the package version again.

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
