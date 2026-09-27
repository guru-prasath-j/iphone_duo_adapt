import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import 'layout_info.dart';

/// Logical screen geometry of a book-style foldable, used for previews and
/// simulation.
///
/// The [iPhoneDuo] values are derived from Apple's published pixel counts
/// (outer 1398 x 2034, inner 2670 x 1878) at a 3x scale factor. Treat them as
/// estimates until you can check them on hardware or in the Xcode 27.1
/// simulator, and pass your own spec if they differ.
@immutable
class DuoDeviceSpec {
  /// Creates a spec.
  const DuoDeviceSpec({
    required this.name,
    required this.outerPortrait,
    required this.innerWide,
    this.foldThickness = 4,
    this.outerPadding = const EdgeInsets.only(top: 59, bottom: 34),
    this.innerPadding = const EdgeInsets.only(top: 24, bottom: 20),
  });

  /// iPhone Duo (estimated points).
  static const DuoDeviceSpec iPhoneDuo = DuoDeviceSpec(
    name: 'iPhone Duo',
    outerPortrait: Size(466, 678),
    innerWide: Size(890, 626),
  );

  /// Display name.
  final String name;

  /// Outer display, held upright.
  final Size outerPortrait;

  /// Inner display, held wide (fold runs top to bottom).
  final Size innerWide;

  /// Width in points of the simulated fold strip.
  final double foldThickness;

  /// Safe-area padding on the outer display, held upright.
  final EdgeInsets outerPadding;

  /// Safe-area padding on the inner display, held wide.
  final EdgeInsets innerPadding;

  /// Screen size for a posture.
  Size sizeFor(DuoPosture posture) => switch (posture) {
        DuoPosture.closedPortrait => outerPortrait,
        DuoPosture.closedLandscape => outerPortrait.flipped,
        DuoPosture.openWide => innerWide,
        DuoPosture.openTall => innerWide.flipped,
      };

  /// Safe-area padding for a posture.
  EdgeInsets paddingFor(DuoPosture posture) => switch (posture) {
        DuoPosture.closedPortrait => outerPadding,
        DuoPosture.closedLandscape => EdgeInsets.only(
            left: outerPadding.top, right: outerPadding.top,
            bottom: outerPadding.bottom / 2),
        DuoPosture.openWide => innerPadding,
        DuoPosture.openTall => EdgeInsets.only(
            top: innerPadding.top, bottom: innerPadding.bottom),
      };

  /// Display features a posture reports. A fold only appears while the
  /// hinge is [DuoHingeState.halfOpened], matching the iOS behaviour where
  /// `.division` regions are active only when the device is bent.
  List<DisplayFeature> featuresFor(DuoPosture posture, DuoHingeState hinge) {
    final isOpen =
        posture == DuoPosture.openWide || posture == DuoPosture.openTall;
    if (!isOpen || hinge != DuoHingeState.halfOpened) {
      return const <DisplayFeature>[];
    }
    final size = sizeFor(posture);
    final t = foldThickness;
    final bounds = posture == DuoPosture.openWide
        ? Rect.fromLTWH(size.width / 2 - t / 2, 0, t, size.height)
        : Rect.fromLTWH(0, size.height / 2 - t / 2, size.width, t);
    return <DisplayFeature>[
      DisplayFeature(
        bounds: bounds,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];
  }

  /// A full [MediaQueryData] for a posture, based on [base].
  MediaQueryData mediaQueryFor(
    MediaQueryData base,
    DuoPosture posture,
    DuoHingeState hinge,
  ) {
    final padding = paddingFor(posture);
    return base.copyWith(
      size: sizeFor(posture),
      padding: padding,
      viewPadding: padding,
      viewInsets: EdgeInsets.zero,
      displayFeatures: featuresFor(posture, hinge),
    );
  }
}
