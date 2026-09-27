# iPhone Duo coverage

Every item in Apple's iPhone Duo guidance (iOS 27 / 27.1 Tech Talks,
September 2026), and what in this package handles it.

Legend: **Runtime** = handled while the app runs · **Audit** = `duo_audit`
flags it · **Migrate** = `duo_migrate` fixes it · **Test** = test kit checks it.

## Layout and display

| Apple guidance | Handled by |
|---|---|
| Decide layout from size classes, not idiom or orientation | Runtime: `DuoLayoutInfo.widthClass` / `heightClass`. Audit: `orientation-branch`, `device-type-branch`, `ios-idiom`, `ios-device-orientation` |
| Screen size changes while the app runs (outer ↔ inner) | Runtime: state is kept by `DuoAdaptiveScaffold`, `DuoCupertinoTabScaffold`, `DuoListDetail`, `DuoSplit`, `DuoArrangement`, `DuoSlot`. Audit: `physical-size`, `static-screen-size`, `ios-uiscreen-main` |
| No fixed widths or phone aspect ratios | Audit: `device-width-constant`, `phone-aspect-ratio`, `screen-util-design-size`, `width-scaled-font` |
| Inner display ignores supported orientations | Audit: `orientation-lock`, `ios-portrait-only`, `android-orientation-lock`. Test: every scenario, including `openTall` and `closedLandscape` |
| Safe areas are asymmetric; handle each inset | Runtime: rail and body pad only their own edge, LTR and RTL; `DuoLayoutInfo.padding`. Test: `expectInsideSafeArea` |
| Edge-to-edge and vertical bars with the iOS 27.1 SDK | Runtime: `DuoAdaptiveScaffold` rail; `extendRailFrom`; SafeArea on the rail edge |

## The fold

| Apple guidance | Handled by |
|---|---|
| `.division` reserved region (the fold, active only while bent) | Runtime: native bridge (`reservedRegionsOfKind:`), merged into `MediaQuery.displayFeatures`; `DuoLayoutInfo.folds`, `foldPose` |
| `.occlusion` reserved region (inner camera) | Runtime: native bridge → `DisplayFeatureType.cutout` → `DuoLayoutInfo.occlusions`. Regions lie outside the safe area, so `SafeArea` already avoids them |
| Move interactive content off the fold: trailing in book pose, down in tabletop | Runtime: `DuoFoldAvoid`, `DuoConstrained`, `DuoAdaptConfig.foldSide` (default `end`). Test: `expectClearOfFold` |
| Leave scrolling content alone | Runtime: `DuoFoldAvoid` is opt-in per widget; lists are never moved |
| `ArrangementView` (`.split` / `.overlay`) | Runtime: `DuoArrangement` (`DuoArrangementStyle.split` / `.overlay`) |
| System displaces sheets, alerts, menus, popovers | Runtime: Flutter's `DisplayFeatureSubScreen` does this for `showDialog`, `showModalBottomSheet`, menus once fold data is in `MediaQuery`, which `DuoAdapt` ensures. Test: "Flutter dialogs stay off the fold" |
| Split view columns adjust around the fold | Runtime: `DuoSplit` and `DuoListDetail` split exactly at the fold |

## Hinge

| Apple guidance | Handled by |
|---|---|
| `UIHingeInteraction` / `onHingeChange`: status and continuous angle | Runtime: native bridge → `DuoHingeReading` (`state`, `angleDegrees`); `DuoHingeBuilder`, `DuoHingeListener`, `DuoLayoutInfo.hingeAngle` |
| Use the angle for effects, not layout | Docs; layout widgets use hinge *state*, never the angle |
| Hinge status is immediate, the region lags it | Runtime: bridge reports a fold only while status is partially open (same rule as flutter/flutter#193025) |

## Bars and navigation

| Apple guidance | Handled by |
|---|---|
| Tab bar and toolbar move to a vertical side strip | Runtime: `DuoAdaptiveScaffold` (Material), `DuoCupertinoTabScaffold` (Cupertino). Migrate: `scaffold`, `cupertino-tabs`. Audit: `bottom-bar`, `cupertino-tab-scaffold` |
| Hand-built bars are not moved by the system | Runtime: `DuoNavigation` + `navigation:` for custom bars; `railBuilder` |
| Toolbar items move into the vertical bar | Runtime: `moveAppBarActionsToRail` |
| Overflow menu (`ToolbarOverflowMenu`) | Runtime: destinations past `railMaxDestinations` go into a "More" menu; the selected one stays visible |
| Every item needs a title | `DuoDestination.label` is required and used in the overflow menu |
| `NavigationSplitView` stacks in compact, opens in regular | Runtime: `DuoListDetail` (push vs. side by side), `DuoListDetailController` |

## Multitasking and windows

| Apple guidance | Handled by |
|---|---|
| Work in narrow Split View next to another app | Runtime: width-based layout gives the compact layout; the native hinge keeps `isOpen` true. Test: `DuoScenario.splitView`. Preview: Split View toggle |
| Maintain context across configuration changes | Runtime: see "state is kept" above; `DuoPostureObserver` to save drafts, pause media |
| UIScene lifecycle required with the iOS 27 SDK | Audit: `ios-no-scene-manifest` |
| `UIRequiresFullScreen` deprecated, ignored | Audit: `ios-requires-full-screen` |

## Hardware

| Apple guidance | Handled by |
|---|---|
| Three cameras; the one facing the user depends on fold state | Audit: `first-camera`. Runtime: `DuoPostureObserver` to re-select |
| Touch ID, not Face ID | Audit: `face-id-text` |

## Testing

| Apple guidance | Handled by |
|---|---|
| Test closed portrait/landscape, open portrait/landscape, book, tabletop, Split View, large text, RTL | Test: `DuoScenario.all`, `testDuoWidgets`. Preview: all of them interactively. RTL: wrap in `Directionality` (see tests) |
| App Store screenshots for the Duo slots | Test: `expectDuoGolden` per scenario |
| What a scan cannot see | `duo_audit --checklist` (also in JSON output) |

## Out of scope for a Flutter package

- **Multiple windows of the same app**: Flutter on iOS runs one window per
  engine today.
- **Drag and drop between apps**: use `super_drag_and_drop`.
- **StandBy widgets, Apple Pencil**: native features, unrelated to layout.
- **Camera capture formats** (`AVCaptureDeviceDirectionCoordinator`, 4K/120
  on the outer camera): the `camera` plugin's job.
- **SwiftUI/UIKit toolbar APIs** (`toolbarVerticalBehavior`,
  `axisBehavior`, ...): only apply to native bars; Flutter draws its own.
