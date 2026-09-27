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
