# AGENTS.md: using iphone_duo_adapt from an AI agent

Deterministic recipe for making a Flutter app iPhone Duo ready. Every step
has a machine-readable check. Run commands from the app's root folder.

## Recipe

1. **Add the package**
   ```sh
   flutter pub add iphone_duo_adapt
   ```
   Check: `pubspec.yaml` lists `iphone_duo_adapt`.

2. **Baseline audit**
   ```sh
   dart run iphone_duo_adapt:duo_audit --json > duo_audit_before.json
   ```
   Schema `iphone_duo_adapt/audit@2`: `findings[]` with `rule`, `severity`,
   `path`, `line`, `column`, `message`, `fix`, `autofix`, and
   `manualChecklist[]`.

3. **Automatic fixes** (findings whose `autofix` is not null)
   ```sh
   dart run iphone_duo_adapt:duo_migrate --json          # preview
   dart run iphone_duo_adapt:duo_migrate --apply --json  # write
   dart format lib
   ```
   Schema `iphone_duo_adapt/migrate@1`: `files[].edits[]` with `step`,
   `line`, `description`. Steps: `app-builder`, `scaffold`,
   `cupertino-tabs`. Idempotent: running twice changes nothing the second
   time.

4. **Manual fixes**: for each remaining finding, apply `fix`. Common ones:

   | rule | do this |
   |---|---|
   | `physical-size`, `static-screen-size` | Read `MediaQuery.sizeOf(context)` in `build`. |
   | `orientation-branch`, `device-type-branch` | Branch on `DuoLayoutInfo.of(context).widthClass`. |
   | `orientation-lock` | Delete the lock, or keep it only when `widthClass == compact`. |
   | `device-width-constant`, `phone-aspect-ratio` | Use `LayoutBuilder` / flexible widgets. |
   | `screen-util-design-size`, `width-scaled-font` | Clamp scaling; don't scale on regular width. |
   | `first-camera` | Pick by `lensDirection`; re-pick in `DuoPostureObserver`. |
   | `face-id-text` | Use the runtime biometric type. |
   | list screens that push a detail page | Replace with `DuoListDetail`. |
   | buttons/forms on full-width screens | Wrap in `DuoFoldAvoid` (or `DuoConstrained`). |
   | `ios-*`, `android-*` | Edit the named native file as `fix` says. |

   Silence a deliberate exception with `// duo-ignore: <rule-id>` on or
   above the line, never by deleting code.

5. **Verify**
   ```sh
   flutter analyze
   flutter test
   dart run iphone_duo_adapt:duo_audit --fail-on=warning
   ```
   Add a scenario test for the main screens (template below); it must pass
   in every scenario.

6. **Report** the `manualChecklist` items to the human: they need a device
   or a person.

## Scenario test template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_duo_adapt/testing.dart';
import 'package:my_app/main.dart';

void main() {
  testDuoWidgets('home screen works on iPhone Duo', (tester, scenario) async {
    await pumpDuo(tester, const MyApp(), scenario: scenario);
    expect(tester.takeException(), isNull);
    // Replace with the app's primary actions:
    // expectClearOfFold(tester, find.text('Checkout'));
    // expectInsideSafeArea(tester, find.text('Checkout'), scenario);
  }, scenarios: DuoScenario.all);
}
```

`pumpDuo` sets the screen size, safe areas, fold and hinge for the
scenario. `duoLayoutOf(tester, finder)` returns the `DuoLayoutInfo` a
widget sees; `toJson()` it to inspect.

## API map

| Need | Use |
|---|---|
| Fold data everywhere, native bridge | `MaterialApp(builder: DuoAdapt.builder(config: ...))` |
| Current layout | `DuoLayoutInfo.of(context)`: `posture`, `widthClass`, `heightClass`, `isOpen`, `hingeState`, `hingeAngle`, `foldPose`, `folds`, `occlusions`, `panes()`, `areaFor()`, `toJson()` |
| Settings | `DuoAdaptConfig` (see README); `DuoAdaptConfig.of(context)` |
| Bottom bar → rail | `DuoAdaptiveScaffold(scaffold: Scaffold(...))` |
| Cupertino tabs → rail | `DuoCupertinoTabScaffold` (same args as `CupertinoTabScaffold`) |
| List + detail | `DuoListDetail<T>` + `DuoListDetailController<T>` |
| Two panes | `DuoSplit`, `DuoArrangement` |
| Keep off the fold | `DuoFoldAvoid`, `DuoConstrained` |
| Per-state builders | `DuoLayoutSwitcher`, `DuoLayoutBuilder` |
| Keep state when moving a widget | `DuoSlot(id: ...)` |
| React to fold/unfold | `DuoPostureObserver(onChanged: ...)` |
| Hinge angle | `DuoHingeBuilder`, `DuoHingeListener` |
| Fake a fold | `DuoAdapt.builder(simulation: const DuoSimulation(), showFoldOverlay: true)` |
| Desktop preview | `DuoPreview(child: MyApp())` |
| Tooling in Dart | `package:iphone_duo_adapt/audit.dart`, `package:iphone_duo_adapt/migrate.dart` |

## Invariants

- Only one `DuoSlot` with a given `id` may be on screen at a time.
- `DuoAdaptiveScaffold` must wrap the `Scaffold` directly (it reads its
  fields).
- Do not use the hinge angle to choose layouts; use `hingeState` /
  `foldPose`.
- Layout decisions come from `widthClass`, never from `Platform` or device
  model.
- `package:iphone_duo_adapt/testing.dart` is for tests only.

## Runtime logs

`DuoAdaptConfig(debugLog: true)` prints one JSON line per layout change:

```
[iphone_duo_adapt] layout {posture: openWide, widthClass: regular, hingeState: halfOpened, foldPose: book, folds: [[443.0, 0.0, 447.0, 626.0]], ...}
```

Read these from `flutter run` output to confirm behaviour on a device.
