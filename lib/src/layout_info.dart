import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'hinge.dart';
import 'scope.dart';

export 'hinge.dart' show DuoHingeReading, DuoHingeState;

/// Size bucket, mirroring iOS size classes.
enum DuoSizeClass {
  /// Narrow (width) or short (height).
  compact,

  /// Wide (width) or tall (height).
  regular,
}

/// The four ways an iPhone Duo (or any book-style foldable) can be held.
enum DuoPosture {
  /// Folded shut, outer screen, held upright.
  closedPortrait,

  /// Folded shut, outer screen, held sideways.
  closedLandscape,

  /// Opened, inner screen, taller than wide.
  openTall,

  /// Opened, inner screen, wider than tall.
  openWide,
}

/// How a bent device is being held.
enum DuoFoldPose {
  /// Not bent, or no fold.
  none,

  /// Bent with the fold running top to bottom, like an open book.
  book,

  /// Bent with the fold running left to right, bottom half on a table.
  tabletop,
}

/// Everything a layout needs to know about the current screen.
///
/// Built from [MediaQueryData.displayFeatures] (filled by Flutter on Android
/// foldables, by this package's native bridge on iOS 27.1, or by a preview
/// or simulation), an optional native hinge reading, and the screen size.
///
/// Read it with [DuoLayoutInfo.of]. Every field is public and the
/// constructor is open, so a custom `DuoAdaptConfig.layoutResolver` can
/// build any state it wants.
@immutable
class DuoLayoutInfo {
  /// Creates layout info from raw values.
  const DuoLayoutInfo({
    required this.size,
    this.padding = EdgeInsets.zero,
    this.folds = const <Rect>[],
    this.occlusions = const <Rect>[],
    this.hingeState = DuoHingeState.closed,
    this.hingeAngle,
    this.widthClass = DuoSizeClass.compact,
    this.heightClass = DuoSizeClass.regular,
    this.textDirection = TextDirection.ltr,
  });

  /// Derives layout info from a [MediaQueryData] with the built-in rules.
  factory DuoLayoutInfo.fromMediaQuery(
    MediaQueryData data, {
    DuoAdaptConfig config = const DuoAdaptConfig(),
    DuoHingeReading? hinge,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final hinges = <Rect>[];
    final bentFolds = <Rect>[];
    final occlusions = <Rect>[];
    var state = DuoHingeState.closed;
    for (final DisplayFeature f in data.displayFeatures) {
      switch (f.type) {
        case DisplayFeatureType.fold:
        case DisplayFeatureType.hinge:
          if (f.state == DisplayFeatureState.postureHalfOpened) {
            state = DuoHingeState.halfOpened;
          } else if (state != DuoHingeState.halfOpened) {
            state = DuoHingeState.flat;
          }
          // A physical hinge (two separate panels) always splits the
          // screen. A fold only does while it is bent; a flat fold is one
          // continuous surface. Zero-size features never split (see
          // flutter/flutter#193025).
          if (f.bounds.width <= 0 || f.bounds.height <= 0) break;
          if (f.type == DisplayFeatureType.hinge) {
            hinges.add(f.bounds);
          } else if (f.state == DisplayFeatureState.postureHalfOpened) {
            bentFolds.add(f.bounds);
          }
        case DisplayFeatureType.cutout:
          occlusions.add(f.bounds);
        case DisplayFeatureType.unknown:
          break;
      }
    }
    // A native reading (UIHingeInteraction) is the most accurate source.
    if (hinge != null && hinge.state != null) {
      state = hinge.state!;
    } else if (state == DuoHingeState.closed &&
        data.size.shortestSide >= config.openShortestSide) {
      // No hinge data but the screen is tablet-shaped: the flat inner
      // display, as it looks before the engine reports features.
      state = DuoHingeState.flat;
    }
    final folds = <Rect>[
      ...hinges,
      if (state == DuoHingeState.halfOpened) ...bentFolds,
    ];
    return DuoLayoutInfo(
      size: data.size,
      padding: data.padding,
      folds: folds,
      occlusions: occlusions,
      hingeState: state,
      hingeAngle: hinge?.angleDegrees,
      widthClass: data.size.width >= config.regularWidthBreakpoint
          ? DuoSizeClass.regular
          : DuoSizeClass.compact,
      heightClass: data.size.height < config.compactHeightBreakpoint
          ? DuoSizeClass.compact
          : DuoSizeClass.regular,
      textDirection: textDirection,
    );
  }

  /// Current layout info, using the nearest `DuoAdapt` settings, native
  /// hinge reading and custom resolver. Works without `DuoAdapt` too.
  static DuoLayoutInfo of(BuildContext context) {
    final scope = DuoScope.maybeOf(context);
    final config = scope?.config ?? const DuoAdaptConfig();
    final data = MediaQuery.of(context);
    final hinge = scope?.hinge;
    final resolver = config.layoutResolver;
    if (resolver != null) return resolver(data, config, hinge);
    return DuoLayoutInfo.fromMediaQuery(
      data,
      config: config,
      hinge: hinge,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  /// Logical size of the area the app draws in.
  final Size size;

  /// Safe-area padding. Asymmetric on iPhone Duo: read each side separately.
  final EdgeInsets padding;

  /// Areas that currently split the screen (a bent fold or a hinge).
  final List<Rect> folds;

  /// Areas content should not sit under, such as the inner camera.
  final List<Rect> occlusions;

  /// Coarse hinge state.
  final DuoHingeState hingeState;

  /// Hinge angle in degrees (180 = flat), when a native source reports it.
  /// Apple advises using it for effects, not for layout.
  final double? hingeAngle;

  /// Width bucket.
  final DuoSizeClass widthClass;

  /// Height bucket.
  final DuoSizeClass heightClass;

  /// Reading direction, used to decide which side is "start".
  final TextDirection textDirection;

  /// Whether the device is open (inner display).
  bool get isOpen => hingeState != DuoHingeState.closed;

  /// Whether the app is on the outer display.
  bool get isOuterDisplay => !isOpen;

  /// Whether a fold currently divides the screen.
  bool get isSeparated => folds.isNotEmpty;

  /// The first dividing fold, if any.
  Rect? get fold => folds.isEmpty ? null : folds.first;

  /// Direction the fold line runs. [Axis.vertical] means left and right
  /// halves.
  Axis? get foldAxis {
    final f = fold;
    if (f == null) return null;
    return f.height >= f.width ? Axis.vertical : Axis.horizontal;
  }

  /// Book or tabletop, when bent.
  DuoFoldPose get foldPose {
    if (hingeState != DuoHingeState.halfOpened) return DuoFoldPose.none;
    final axis = foldAxis ??
        (size.width >= size.height ? Axis.vertical : Axis.horizontal);
    return axis == Axis.vertical ? DuoFoldPose.book : DuoFoldPose.tabletop;
  }

  /// Current posture, from open state and aspect ratio.
  DuoPosture get posture {
    final wide = size.width > size.height;
    if (isOpen) return wide ? DuoPosture.openWide : DuoPosture.openTall;
    return wide ? DuoPosture.closedLandscape : DuoPosture.closedPortrait;
  }

  /// Whether two panes fit: a fold divides the screen, or the width is
  /// regular and each pane gets at least [minPaneExtent].
  bool canSplit({double minPaneExtent = 280, double ratio = 0.4}) {
    if (isSeparated) return true;
    if (widthClass != DuoSizeClass.regular) return false;
    final r = ratio.clamp(0.0, 1.0);
    return size.width * r >= minPaneExtent &&
        size.width * (1 - r) >= minPaneExtent;
  }

  /// Splits the screen into two panes (in screen coordinates).
  ///
  /// With a fold, the panes sit either side of it: left/right in book pose,
  /// top/bottom in tabletop. Without one, the width is split at [ratio].
  /// Returns `null` when [canSplit] is false.
  (Rect, Rect)? panes({double ratio = 0.4, double minPaneExtent = 0}) {
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
    if (!canSplit(minPaneExtent: minPaneExtent, ratio: ratio)) return null;
    final split = size.width * ratio;
    return (
      Rect.fromLTRB(0, 0, split, size.height),
      Rect.fromLTRB(split, 0, size.width, size.height),
    );
  }

  /// The half of the screen that fold-avoiding content should use, or the
  /// whole screen when there is no fold.
  Rect areaFor(DuoFoldSide side) {
    final full = Offset.zero & size;
    final f = fold;
    if (f == null) return full;
    final (a, b) = panes()!;
    final rtl = textDirection == TextDirection.rtl;
    final useEnd = side == DuoFoldSide.end;
    if (foldAxis == Axis.vertical && rtl) return useEnd ? a : b;
    return useEnd ? b : a;
  }

  /// Returns a copy with the given values replaced.
  DuoLayoutInfo copyWith({
    Size? size,
    EdgeInsets? padding,
    List<Rect>? folds,
    List<Rect>? occlusions,
    DuoHingeState? hingeState,
    double? hingeAngle,
    DuoSizeClass? widthClass,
    DuoSizeClass? heightClass,
    TextDirection? textDirection,
  }) {
    return DuoLayoutInfo(
      size: size ?? this.size,
      padding: padding ?? this.padding,
      folds: folds ?? this.folds,
      occlusions: occlusions ?? this.occlusions,
      hingeState: hingeState ?? this.hingeState,
      hingeAngle: hingeAngle ?? this.hingeAngle,
      widthClass: widthClass ?? this.widthClass,
      heightClass: heightClass ?? this.heightClass,
      textDirection: textDirection ?? this.textDirection,
    );
  }

  /// JSON form, for logs, tests and AI agents.
  Map<String, Object?> toJson() {
    List<double> r(Rect x) => <double>[x.left, x.top, x.right, x.bottom];
    return <String, Object?>{
      'posture': posture.name,
      'widthClass': widthClass.name,
      'heightClass': heightClass.name,
      'hingeState': hingeState.name,
      'hingeAngle': hingeAngle,
      'foldPose': foldPose.name,
      'size': <double>[size.width, size.height],
      'padding': <double>[
        padding.left,
        padding.top,
        padding.right,
        padding.bottom,
      ],
      'folds': folds.map(r).toList(),
      'occlusions': occlusions.map(r).toList(),
      'textDirection': textDirection.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is DuoLayoutInfo &&
      other.size == size &&
      other.padding == padding &&
      other.hingeState == hingeState &&
      other.hingeAngle == hingeAngle &&
      other.widthClass == widthClass &&
      other.heightClass == heightClass &&
      other.textDirection == textDirection &&
      _listEq(other.folds, folds) &&
      _listEq(other.occlusions, occlusions);

  @override
  int get hashCode => Object.hash(
        size,
        padding,
        hingeState,
        hingeAngle,
        widthClass,
        heightClass,
        textDirection,
        Object.hashAll(folds),
        Object.hashAll(occlusions),
      );

  @override
  String toString() => 'DuoLayoutInfo(${posture.name}, '
      'width: ${widthClass.name}, height: ${heightClass.name}, '
      'hinge: ${hingeState.name}, pose: ${foldPose.name}, folds: $folds)';

  static bool _listEq(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
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

  /// [screenRect] (screen coordinates) mapped into [context]'s local
  /// coordinates. Returns `null` before the first layout.
  static Rect? toLocal(BuildContext context, Rect screenRect) {
    final origin = originOf(context);
    return origin == null ? null : screenRect.shift(-origin);
  }
}

/// Render object for [DuoScreenRoot].
class RenderDuoScreenRoot extends RenderProxyBox {}
