import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'layout_info.dart';

/// Forces a fold onto the current screen for testing on devices that do not
/// report one (an iPhone simulator, a desktop window, an Android tablet).
@immutable
class DuoSimulation {
  /// Creates a simulation.
  const DuoSimulation({
    this.hinge = DuoHingeState.halfOpened,
    this.foldThickness = 4,
  });

  /// Hinge state to pretend. Only [DuoHingeState.halfOpened] adds a fold.
  final DuoHingeState hinge;

  /// Width of the simulated fold strip in logical pixels.
  final double foldThickness;

  /// Fold feature for a screen of [size], or `null` if none applies.
  DisplayFeature? featureFor(Size size) {
    if (hinge != DuoHingeState.halfOpened) return null;
    final t = foldThickness;
    final bounds = size.width >= size.height
        ? Rect.fromLTWH(size.width / 2 - t / 2, 0, t, size.height)
        : Rect.fromLTWH(0, size.height / 2 - t / 2, size.width, t);
    return DisplayFeature(
      bounds: bounds,
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
  }
}

/// Makes an existing app fold-aware with one wrapper.
///
/// Put it above or inside your `MaterialApp` / `CupertinoApp`:
///
/// ```dart
/// MaterialApp(
///   builder: DuoAdapt.builder(),
///   home: const HomePage(),
/// )
/// ```
///
/// It does three things:
///
/// 1. Publishes settings (breakpoints) read by [DuoLayoutInfo.of] and the
///    other `Duo*` widgets.
/// 2. Merges fold data from [featureSource] into
///    [MediaQueryData.displayFeatures]. Anything Flutter already does with
///    display features, such as keeping `showDialog` off the fold, then
///    works with that data too. Use this to plug in a native bridge package
///    until the Flutter engine reports iPhone Duo folds itself.
/// 3. Optionally draws the fold ([showFoldOverlay]) and fakes one
///    ([simulation]) for testing without hardware.
class DuoAdapt extends StatelessWidget {
  /// Wraps [child].
  const DuoAdapt({
    super.key,
    required this.child,
    this.regularWidthBreakpoint = 600,
    this.openShortestSide = 560,
    this.featureSource,
    this.simulation,
    this.showFoldOverlay = false,
  });

  /// Returns a `builder` for `MaterialApp.builder` / `CupertinoApp.builder`.
  static TransitionBuilder builder({
    double regularWidthBreakpoint = 600,
    double openShortestSide = 560,
    ValueListenable<List<DisplayFeature>>? featureSource,
    DuoSimulation? simulation,
    bool showFoldOverlay = false,
  }) {
    return (BuildContext context, Widget? child) => DuoAdapt(
          regularWidthBreakpoint: regularWidthBreakpoint,
          openShortestSide: openShortestSide,
          featureSource: featureSource,
          simulation: simulation,
          showFoldOverlay: showFoldOverlay,
          child: child ?? const SizedBox.shrink(),
        );
  }

  /// The app.
  final Widget child;

  /// See [DuoLayoutInfo.regularWidthBreakpoint].
  final double regularWidthBreakpoint;

  /// See [DuoLayoutInfo.openShortestSide].
  final double openShortestSide;

  /// Extra display features, for example from a native iPhone Duo bridge.
  /// Merged with what the platform already reports.
  final ValueListenable<List<DisplayFeature>>? featureSource;

  /// Fake fold for testing. Leave `null` in release builds.
  final DuoSimulation? simulation;

  /// Draws a translucent strip over folds and occlusions.
  final bool showFoldOverlay;

  @override
  Widget build(BuildContext context) {
    final source = featureSource;
    if (source == null) return _build(context, const <DisplayFeature>[]);
    return ValueListenableBuilder<List<DisplayFeature>>(
      valueListenable: source,
      builder: (context, extra, _) => _build(context, extra),
    );
  }

  Widget _build(BuildContext context, List<DisplayFeature> extra) {
    final base = MediaQuery.of(context);
    final features = <DisplayFeature>[...base.displayFeatures, ...extra];
    final simulated = simulation?.featureFor(base.size);
    if (simulated != null &&
        !features.any((f) => f.type == DisplayFeatureType.fold ||
            f.type == DisplayFeatureType.hinge)) {
      features.add(simulated);
    }
    final data = features.length == base.displayFeatures.length
        ? base
        : base.copyWith(displayFeatures: features);

    Widget result = DuoScopeMarker(
      regularWidthBreakpoint: regularWidthBreakpoint,
      openShortestSide: openShortestSide,
      child: DuoScreenRoot(child: child),
    );
    if (showFoldOverlay) {
      result = Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          result,
          const Positioned.fill(child: IgnorePointer(child: DuoFoldOverlay())),
        ],
      );
    }
    return MediaQuery(data: data, child: result);
  }
}

/// Paints folds (red) and occlusions (amber) from the ambient [MediaQuery].
class DuoFoldOverlay extends StatelessWidget {
  /// Creates the overlay.
  const DuoFoldOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    return CustomPaint(painter: _FoldPainter(features));
  }
}

class _FoldPainter extends CustomPainter {
  _FoldPainter(this.features);

  final List<DisplayFeature> features;

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in features) {
      final isCutout = f.type == DisplayFeatureType.cutout;
      final paint = Paint()
        ..color = (isCutout ? const Color(0xFFFFB300) : const Color(0xFFE53935))
            .withValues(alpha: 0.45);
      final r = f.bounds.shortestSide == 0 ? f.bounds.inflate(1) : f.bounds;
      canvas.drawRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) =>
      !listEquals(oldDelegate.features, features);
}
