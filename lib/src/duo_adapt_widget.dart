import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'layout_info.dart';
import 'native_bridge.dart';
import 'scope.dart';

/// Forces a fold (and optionally a hinge angle) onto the current screen,
/// for testing on devices that do not report one.
@immutable
class DuoSimulation {
  /// Creates a simulation.
  const DuoSimulation({
    this.hinge = DuoHingeState.halfOpened,
    this.foldThickness = 4,
    this.angleDegrees,
  });

  /// Hinge state to pretend. Only [DuoHingeState.halfOpened] adds a fold.
  final DuoHingeState hinge;

  /// Width of the simulated fold strip in logical pixels.
  final double foldThickness;

  /// Hinge angle to report, in degrees.
  final double? angleDegrees;

  /// Fold feature for a screen of [size], or `null` if none applies. The
  /// fold runs top to bottom on wide screens (book) and left to right on
  /// tall ones (tabletop).
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

  /// The hinge reading this simulation reports.
  DuoHingeReading get reading => DuoHingeReading(
        state: hinge,
        angleDegrees: angleDegrees ??
            switch (hinge) {
              DuoHingeState.closed => 0,
              DuoHingeState.halfOpened => 110,
              DuoHingeState.flat => 180,
            },
      );
}

/// Makes an existing app fold-aware with one wrapper.
///
/// ```dart
/// MaterialApp(
///   builder: DuoAdapt.builder(),
///   home: const HomePage(),
/// )
/// ```
///
/// It:
///
/// 1. Shares a [DuoAdaptConfig] with every `Duo*` widget.
/// 2. On iOS 27.1+, starts the native bridge and merges the real fold and
///    camera regions into [MediaQueryData.displayFeatures], so Flutter's own
///    dialogs, bottom sheets and menus stay off the fold with no other
///    change. Also exposes the hinge angle.
/// 3. Merges any [featureSource] / [hingeSource] you provide (your own
///    bridge, a test) the same way.
/// 4. Optionally fakes a fold ([simulation]) and draws folds on screen
///    ([showFoldOverlay]) for debugging.
class DuoAdapt extends StatefulWidget {
  /// Wraps [child].
  const DuoAdapt({
    super.key,
    required this.child,
    this.config = const DuoAdaptConfig(),
    this.featureSource,
    this.hingeSource,
    this.hinge,
    this.simulation,
    this.showFoldOverlay = false,
  });

  /// Returns a `builder` for `MaterialApp.builder` / `CupertinoApp.builder`
  /// / `WidgetsApp.builder`.
  static TransitionBuilder builder({
    DuoAdaptConfig config = const DuoAdaptConfig(),
    ValueListenable<List<DisplayFeature>>? featureSource,
    ValueListenable<DuoHingeReading?>? hingeSource,
    DuoSimulation? simulation,
    bool showFoldOverlay = false,
    TransitionBuilder? inner,
  }) {
    return (BuildContext context, Widget? child) => DuoAdapt(
          config: config,
          featureSource: featureSource,
          hingeSource: hingeSource,
          simulation: simulation,
          showFoldOverlay: showFoldOverlay,
          child: inner != null
              ? inner(context, child)
              : child ?? const SizedBox.shrink(),
        );
  }

  /// The app.
  final Widget child;

  /// Settings for this package.
  final DuoAdaptConfig config;

  /// Extra display features, for example from your own native bridge.
  /// Merged with what the platform already reports.
  final ValueListenable<List<DisplayFeature>>? featureSource;

  /// Hinge readings from your own source. Wins over the native bridge.
  final ValueListenable<DuoHingeReading?>? hingeSource;

  /// A fixed hinge reading (used by previews and tests). Wins over
  /// [hingeSource] and the native bridge.
  final DuoHingeReading? hinge;

  /// Fake fold for testing. Leave `null` in release builds.
  final DuoSimulation? simulation;

  /// Draws a translucent strip over folds (red) and occlusions (amber).
  final bool showFoldOverlay;

  @override
  State<DuoAdapt> createState() => _DuoAdaptState();
}

class _DuoAdaptState extends State<DuoAdapt> {
  final DuoSlotRegistry _slots = DuoSlotRegistry();
  DuoLayoutInfo? _lastLogged;

  @override
  void initState() {
    super.initState();
    if (widget.config.useNativeBridge && DuoNativeBridge.platformHasBridge) {
      DuoNativeBridge.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      if (widget.config.useNativeBridge) DuoNativeBridge.instance.state,
      if (widget.featureSource != null) widget.featureSource!,
      if (widget.hingeSource != null) widget.hingeSource!,
    ];
    if (listenables.isEmpty) return _build(context);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final base = MediaQuery.of(context);
    final parent = DuoScope.maybeOf(context);
    final native = widget.config.useNativeBridge
        ? DuoNativeBridge.instance.state.value
        : null;

    final features = <DisplayFeature>[...base.displayFeatures];
    bool has(DisplayFeatureType t) => features.any((f) => f.type == t);

    // Native regions only fill gaps, so nothing is doubled once the engine
    // reports them itself.
    if (native != null && native.supported) {
      for (final f in native.features) {
        if (!has(f.type)) features.add(f);
      }
    }
    for (final f in widget.featureSource?.value ?? const <DisplayFeature>[]) {
      features.add(f);
    }
    final simulated = widget.simulation?.featureFor(base.size);
    if (simulated != null &&
        !has(DisplayFeatureType.fold) &&
        !has(DisplayFeatureType.hinge)) {
      features.add(simulated);
    }

    final hinge = widget.hinge ??
        widget.hingeSource?.value ??
        (native != null && native.supported ? native.hinge : null) ??
        widget.simulation?.reading ??
        parent?.hinge;

    final data = listEquals(features, base.displayFeatures)
        ? base
        : base.copyWith(displayFeatures: features);

    if (widget.config.debugLog) _log(data, hinge);

    Widget result = DuoScope(
      config: widget.config,
      hinge: hinge,
      slots: _slots,
      child: DuoScreenRoot(child: widget.child),
    );
    if (widget.showFoldOverlay) {
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

  void _log(MediaQueryData data, DuoHingeReading? hinge) {
    final info = widget.config.layoutResolver?.call(data, widget.config, hinge) ??
        DuoLayoutInfo.fromMediaQuery(data, config: widget.config, hinge: hinge);
    final last = _lastLogged;
    if (last == null ||
        last.posture != info.posture ||
        last.widthClass != info.widthClass ||
        last.hingeState != info.hingeState ||
        last.foldPose != info.foldPose) {
      widget.config.log('layout ${info.toJson()}');
    }
    _lastLogged = info;
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
