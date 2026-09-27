import 'package:flutter/material.dart';

import 'device_spec.dart';
import 'layout_info.dart';
import 'scope.dart';

/// Which half of the screen fold-avoiding content moves to.
enum DuoFoldSide {
  /// Before the fold: left in book pose (right in RTL), top in tabletop.
  start,

  /// After the fold: right in book pose (left in RTL), bottom in tabletop.
  /// This is what Apple recommends for controls.
  end,
}

/// Replaces the built-in layout detection. Return your own [DuoLayoutInfo]
/// to change how postures and size classes are worked out.
typedef DuoLayoutResolver = DuoLayoutInfo Function(
  MediaQueryData data,
  DuoAdaptConfig config,
  DuoHingeReading? hinge,
);

/// Receives debug log lines when [DuoAdaptConfig.debugLog] is on.
typedef DuoLogger = void Function(String message);

/// Every setting the package uses, in one place.
///
/// Pass it to `DuoAdapt(config: ...)`. Every `Duo*` widget below reads it
/// with [DuoAdaptConfig.of], and most also accept per-widget overrides.
///
/// ```dart
/// DuoAdapt.builder(
///   config: const DuoAdaptConfig(
///     regularWidthBreakpoint: 700,
///     splitRatio: 0.35,
///     foldSide: DuoFoldSide.end,
///   ),
/// )
/// ```
@immutable
class DuoAdaptConfig {
  /// Creates a config. Every value has a default that matches Apple's
  /// guidance for iPhone Duo.
  const DuoAdaptConfig({
    this.regularWidthBreakpoint = 600,
    this.compactHeightBreakpoint = 480,
    this.openShortestSide = 560,
    this.splitRatio = 0.4,
    this.minPaneExtent = 280,
    this.foldSide = DuoFoldSide.end,
    this.railLabelType = NavigationRailLabelType.all,
    this.railMaxDestinations = 7,
    this.moveAppBarActionsToRail = false,
    this.transitionDuration = Duration.zero,
    this.transitionCurve = Curves.easeInOut,
    this.useNativeBridge = true,
    this.deviceSpec = DuoDeviceSpec.iPhoneDuo,
    this.layoutResolver,
    this.debugLog = false,
    this.logger,
  });

  /// Width (points) from which the layout counts as regular: side rail,
  /// two panes. Apple reports regular width only on the inner display, which
  /// is 626 pt or wider.
  final double regularWidthBreakpoint;

  /// Height below which the layout counts as compact height (the outer
  /// display held sideways).
  final double compactHeightBreakpoint;

  /// Shortest side from which a screen counts as the opened inner display
  /// when the platform reports no hinge.
  final double openShortestSide;

  /// Share of the width given to the first pane when no fold decides it.
  final double splitRatio;

  /// Smallest width (or height) a pane may get. Below it a split falls back
  /// to one pane.
  final double minPaneExtent;

  /// Where fold-avoiding content goes when the device is bent.
  final DuoFoldSide foldSide;

  /// Label style of the side rail.
  final NavigationRailLabelType railLabelType;

  /// Destinations shown on the rail before the rest go into a "More" menu.
  final int railMaxDestinations;

  /// Move `AppBar.actions` into the rail on regular width, like iOS moves
  /// toolbar items into the vertical bar.
  final bool moveAppBarActionsToRail;

  /// Animation when switching between compact and regular layouts.
  /// [Duration.zero] switches instantly.
  final Duration transitionDuration;

  /// Curve for [transitionDuration].
  final Curve transitionCurve;

  /// On iOS, read the hinge and fold straight from UIKit (iOS 27.1+).
  final bool useNativeBridge;

  /// Screen geometry for previews and tests.
  final DuoDeviceSpec deviceSpec;

  /// Custom detection, replacing the built-in rules.
  final DuoLayoutResolver? layoutResolver;

  /// Log posture and layout changes.
  final bool debugLog;

  /// Where logs go. Defaults to `debugPrint`.
  final DuoLogger? logger;

  /// The config from the nearest `DuoAdapt`, or the defaults.
  static DuoAdaptConfig of(BuildContext context) =>
      DuoScope.maybeOf(context)?.config ?? const DuoAdaptConfig();

  /// Returns a copy with the given values replaced.
  DuoAdaptConfig copyWith({
    double? regularWidthBreakpoint,
    double? compactHeightBreakpoint,
    double? openShortestSide,
    double? splitRatio,
    double? minPaneExtent,
    DuoFoldSide? foldSide,
    NavigationRailLabelType? railLabelType,
    int? railMaxDestinations,
    bool? moveAppBarActionsToRail,
    Duration? transitionDuration,
    Curve? transitionCurve,
    bool? useNativeBridge,
    DuoDeviceSpec? deviceSpec,
    DuoLayoutResolver? layoutResolver,
    bool? debugLog,
    DuoLogger? logger,
  }) {
    return DuoAdaptConfig(
      regularWidthBreakpoint:
          regularWidthBreakpoint ?? this.regularWidthBreakpoint,
      compactHeightBreakpoint:
          compactHeightBreakpoint ?? this.compactHeightBreakpoint,
      openShortestSide: openShortestSide ?? this.openShortestSide,
      splitRatio: splitRatio ?? this.splitRatio,
      minPaneExtent: minPaneExtent ?? this.minPaneExtent,
      foldSide: foldSide ?? this.foldSide,
      railLabelType: railLabelType ?? this.railLabelType,
      railMaxDestinations: railMaxDestinations ?? this.railMaxDestinations,
      moveAppBarActionsToRail:
          moveAppBarActionsToRail ?? this.moveAppBarActionsToRail,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
      useNativeBridge: useNativeBridge ?? this.useNativeBridge,
      deviceSpec: deviceSpec ?? this.deviceSpec,
      layoutResolver: layoutResolver ?? this.layoutResolver,
      debugLog: debugLog ?? this.debugLog,
      logger: logger ?? this.logger,
    );
  }

  /// Logs [message] if [debugLog] is on.
  void log(String message) {
    if (!debugLog) return;
    (logger ?? debugPrint)('[iphone_duo_adapt] $message');
  }

  /// JSON form, for logs and tooling.
  Map<String, Object?> toJson() => <String, Object?>{
        'regularWidthBreakpoint': regularWidthBreakpoint,
        'compactHeightBreakpoint': compactHeightBreakpoint,
        'openShortestSide': openShortestSide,
        'splitRatio': splitRatio,
        'minPaneExtent': minPaneExtent,
        'foldSide': foldSide.name,
        'railLabelType': railLabelType.name,
        'railMaxDestinations': railMaxDestinations,
        'moveAppBarActionsToRail': moveAppBarActionsToRail,
        'transitionMs': transitionDuration.inMilliseconds,
        'useNativeBridge': useNativeBridge,
        'deviceSpec': deviceSpec.name,
        'customResolver': layoutResolver != null,
      };

  @override
  bool operator ==(Object other) =>
      other is DuoAdaptConfig &&
      other.regularWidthBreakpoint == regularWidthBreakpoint &&
      other.compactHeightBreakpoint == compactHeightBreakpoint &&
      other.openShortestSide == openShortestSide &&
      other.splitRatio == splitRatio &&
      other.minPaneExtent == minPaneExtent &&
      other.foldSide == foldSide &&
      other.railLabelType == railLabelType &&
      other.railMaxDestinations == railMaxDestinations &&
      other.moveAppBarActionsToRail == moveAppBarActionsToRail &&
      other.transitionDuration == transitionDuration &&
      other.transitionCurve == transitionCurve &&
      other.useNativeBridge == useNativeBridge &&
      other.deviceSpec == deviceSpec &&
      other.layoutResolver == layoutResolver &&
      other.debugLog == debugLog &&
      other.logger == logger;

  @override
  int get hashCode => Object.hash(
        regularWidthBreakpoint,
        compactHeightBreakpoint,
        openShortestSide,
        splitRatio,
        minPaneExtent,
        foldSide,
        railLabelType,
        railMaxDestinations,
        moveAppBarActionsToRail,
        transitionDuration,
        transitionCurve,
        useNativeBridge,
        deviceSpec,
        layoutResolver,
        debugLog,
        logger,
      );
}
