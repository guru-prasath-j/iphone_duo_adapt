import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Width bucket used to pick a layout, mirroring iOS size classes.
enum DuoSizeClass {
  /// Narrow: phone-like. Bottom bars, single pane.
  compact,

  /// Wide: tablet-like. Side bars, two panes.
  regular,
}

/// The four ways an iPhone Duo (or any book-style foldable) can be held.
enum DuoPosture {
  /// Folded shut, outer screen, held upright.
  closedPortrait,

  /// Folded shut, outer screen, held sideways.
  closedLandscape,

  /// Opened, inner screen, held so it is taller than wide.
  openTall,

  /// Opened, inner screen, held so it is wider than tall.
  openWide,
}

/// Coarse hinge state, the same buckets `UIHingeInteraction` reports.
enum DuoHingeState {
  /// Folded shut (or not a foldable).
  closed,

  /// Partly open, like a laptop or a book on a table.
  halfOpened,

  /// Fully open and flat.
  flat,
}

/// Everything a layout needs to know about the current screen shape.
///
/// Built from [MediaQueryData.displayFeatures] (populated by Flutter on
/// Android foldables today and on iPhone Duo once flutter/flutter#193025
/// lands) plus the logical screen size. Use [DuoLayoutInfo.of] inside a
/// widget tree.
@immutable
class DuoLayoutInfo {
  /// Creates layout info from raw values. Prefer [DuoLayoutInfo.fromMediaQuery].
  const DuoLayoutInfo({
    required this.size,
    this.folds = const <Rect>[],
    this.occlusions = const <Rect>[],
    this.hingeState = DuoHingeState.closed,
    this.regularWidthBreakpoint = 600,
    this.openShortestSide = 560,
  });

  /// Derives layout info from a [MediaQueryData].
  factory DuoLayoutInfo.fromMediaQuery(
    MediaQueryData data, {
    double regularWidthBreakpoint = 600,
    double openShortestSide = 560,
  }) {
    final folds = <Rect>[];
    final occlusions = <Rect>[];
    var hinge = DuoHingeState.closed;
    for (final DisplayFeature f in data.displayFeatures) {
      switch (f.type) {
        case DisplayFeatureType.fold:
        case DisplayFeatureType.hinge:
          if (f.state == DisplayFeatureState.postureHalfOpened) {
            hinge = DuoHingeState.halfOpened;
          } else if (hinge != DuoHingeState.halfOpened) {
            hinge = DuoHingeState.flat;
          }
          // A physical hinge always splits the screen. A fold only does
          // while it is bent; a flat fold is one continuous surface.
          if (f.type == DisplayFeatureType.hinge ||
              f.state == DisplayFeatureState.postureHalfOpened) {
            folds.add(f.bounds);
          }
        case DisplayFeatureType.cutout:
          occlusions.add(f.bounds);
        case DisplayFeatureType.unknown:
          break;
      }
    }
    // No fold reported but the screen is tablet-shaped: treat it as the open,
    // flat inner display. This is what an iPhone Duo looks like to Flutter
    // before the engine reports display features.
    if (hinge == DuoHingeState.closed &&
        data.size.shortestSide >= openShortestSide) {
      hinge = DuoHingeState.flat;
    }
    return DuoLayoutInfo(
      size: data.size,
      folds: folds,
      occlusions: occlusions,
      hingeState: hinge,
      regularWidthBreakpoint: regularWidthBreakpoint,
      openShortestSide: openShortestSide,
    );
  }

  /// Reads layout info honouring the nearest `DuoAdapt` settings, or builds it straight
  /// from [MediaQuery] when there is no scope.
  static DuoLayoutInfo of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DuoScopeMarker>();
    final data = MediaQuery.of(context);
    return DuoLayoutInfo.fromMediaQuery(
      data,
      regularWidthBreakpoint: scope?.regularWidthBreakpoint ?? 600,
      openShortestSide: scope?.openShortestSide ?? 560,
    );
  }

  /// Logical size of the area the app draws in.
  final Size size;

  /// Areas that split the screen: a bent fold or a physical hinge.
  final List<Rect> folds;

  /// Areas content should not sit under, such as an inner camera.
  final List<Rect> occlusions;

  /// Coarse hinge state.
  final DuoHingeState hingeState;

  /// Width at or above which [widthClass] is [DuoSizeClass.regular].
  final double regularWidthBreakpoint;

  /// Shortest side at or above which a screen counts as an opened foldable
  /// when the platform reports no display features.
  final double openShortestSide;

  /// Width bucket for choosing bars and pane counts.
  DuoSizeClass get widthClass => size.width >= regularWidthBreakpoint
      ? DuoSizeClass.regular
      : DuoSizeClass.compact;

  /// Whether the device is open (inner display).
  bool get isOpen => hingeState != DuoHingeState.closed;

  /// Whether a fold or hinge currently divides the screen.
  bool get isSeparated => folds.isNotEmpty;

  /// The first dividing fold, if any.
  Rect? get fold => folds.isEmpty ? null : folds.first;

  /// Direction the fold line runs. [Axis.vertical] means it splits the
  /// screen into left and right halves.
  Axis? get foldAxis {
    final f = fold;
    if (f == null) return null;
    return f.height >= f.width ? Axis.vertical : Axis.horizontal;
  }

  /// Current posture, derived from open state and aspect ratio.
  DuoPosture get posture {
    final wide = size.width > size.height;
    if (isOpen) return wide ? DuoPosture.openWide : DuoPosture.openTall;
    return wide ? DuoPosture.closedLandscape : DuoPosture.closedPortrait;
  }

  /// Splits the screen into two panes.
  ///
  /// If a fold divides the screen, the panes sit either side of it. If not,
  /// the screen is split along its long side at [ratio] (share given to the
  /// first pane). Returns `null` when the width class is compact and there is
  /// no fold, meaning a single pane is the right call.
  (Rect, Rect)? panes({double ratio = 0.4}) {
    final full = Offset.zero & size;
    final f = fold;
    if (f != null) {
      if (foldAxis == Axis.vertical) {
        return (
          Rect.fromLTRB(0, 0, f.left, size.height),
          Rect.fromLTRB(f.right, 0, size.width, size.height),
        );
      }
      return (
        Rect.fromLTRB(0, 0, size.width, f.top),
        Rect.fromLTRB(0, f.bottom, size.width, size.height),
      );
    }
    if (widthClass == DuoSizeClass.compact) return null;
    final split = full.width * ratio;
    return (
      Rect.fromLTRB(0, 0, split, size.height),
      Rect.fromLTRB(split, 0, size.width, size.height),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoLayoutInfo &&
      other.size == size &&
      other.hingeState == hingeState &&
      other.regularWidthBreakpoint == regularWidthBreakpoint &&
      other.openShortestSide == openShortestSide &&
      _listEq(other.folds, folds) &&
      _listEq(other.occlusions, occlusions);

  @override
  int get hashCode => Object.hash(size, hingeState, regularWidthBreakpoint,
      openShortestSide, Object.hashAll(folds), Object.hashAll(occlusions));

  @override
  String toString() =>
      'DuoLayoutInfo($posture, $widthClass, hinge: $hingeState, folds: $folds)';

  static bool _listEq(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Carries [DuoAdapt] settings down the tree. Internal; use [DuoAdapt].
class DuoScopeMarker extends InheritedWidget {
  /// Creates the marker.
  const DuoScopeMarker({
    super.key,
    required this.regularWidthBreakpoint,
    required this.openShortestSide,
    required super.child,
  });

  /// See [DuoLayoutInfo.regularWidthBreakpoint].
  final double regularWidthBreakpoint;

  /// See [DuoLayoutInfo.openShortestSide].
  final double openShortestSide;

  @override
  bool updateShouldNotify(DuoScopeMarker oldWidget) =>
      oldWidget.regularWidthBreakpoint != regularWidthBreakpoint ||
      oldWidget.openShortestSide != openShortestSide;
}

/// Marks the widget that fills the (real or simulated) screen, so fold
/// rectangles can be mapped into local coordinates even inside a scaled
/// preview. `DuoAdapt` and `DuoPreview` insert it for you.
class DuoScreenRoot extends SingleChildRenderObjectWidget {
  /// Creates the marker.
  const DuoScreenRoot({super.key, super.child});

  @override
  RenderDuoScreenRoot createRenderObject(BuildContext context) =>
      RenderDuoScreenRoot();

  /// Offset of [context]'s render box from the nearest [DuoScreenRoot]
  /// (or the window when there is none). Only valid after layout.
  static Offset? originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final root = context.findAncestorRenderObjectOfType<RenderDuoScreenRoot>();
    return box.localToGlobal(Offset.zero, ancestor: root);
  }
}

/// Render object for [DuoScreenRoot].
class RenderDuoScreenRoot extends RenderProxyBox {}
