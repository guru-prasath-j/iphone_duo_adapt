import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

MediaQueryData _mq(Size size, [List<DisplayFeature> f = const []]) =>
    MediaQueryData(size: size, displayFeatures: f);

void main() {
  const spec = DuoDeviceSpec.iPhoneDuo;

  test('closed outer display is compact, portrait, not open', () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(spec.outerPortrait));
    expect(info.widthClass, DuoSizeClass.compact);
    expect(info.posture, DuoPosture.closedPortrait);
    expect(info.isOpen, isFalse);
    expect(info.panes(), isNull);
  });

  test('closed sideways is regular width but still closed', () {
    final info =
        DuoLayoutInfo.fromMediaQuery(_mq(spec.outerPortrait.flipped));
    expect(info.posture, DuoPosture.closedLandscape);
    expect(info.widthClass, DuoSizeClass.regular);
    expect(info.isOpen, isFalse);
  });

  test('inner display without features is treated as open and flat', () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(spec.innerWide));
    expect(info.isOpen, isTrue);
    expect(info.hingeState, DuoHingeState.flat);
    expect(info.isSeparated, isFalse);
    expect(info.posture, DuoPosture.openWide);
    final (a, b) = info.panes(ratio: 0.5)!;
    expect(a.width, spec.innerWide.width / 2);
    expect(b.left, a.right);
  });

  test('bent fold splits the screen either side of it', () {
    final data = spec.mediaQueryFor(
        const MediaQueryData(), DuoPosture.openWide, DuoHingeState.halfOpened);
    final info = DuoLayoutInfo.fromMediaQuery(data);
    expect(info.hingeState, DuoHingeState.halfOpened);
    expect(info.foldAxis, Axis.vertical);
    final (a, b) = info.panes()!;
    expect(a.right, info.fold!.left);
    expect(b.left, info.fold!.right);
  });

  test('open tall posture has a horizontal fold', () {
    final data = spec.mediaQueryFor(
        const MediaQueryData(), DuoPosture.openTall, DuoHingeState.halfOpened);
    final info = DuoLayoutInfo.fromMediaQuery(data);
    expect(info.posture, DuoPosture.openTall);
    expect(info.foldAxis, Axis.horizontal);
  });

  test('flat fold does not separate, hinge always does, cutout is occlusion',
      () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(const Size(900, 700), [
      const DisplayFeature(
        bounds: Rect.fromLTWH(450, 0, 0, 700),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      ),
      const DisplayFeature(
        bounds: Rect.fromLTWH(10, 10, 20, 20),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ]));
    expect(info.isSeparated, isFalse);
    expect(info.hingeState, DuoHingeState.flat);
    expect(info.occlusions, hasLength(1));

    final hinged = DuoLayoutInfo.fromMediaQuery(_mq(const Size(900, 700), [
      const DisplayFeature(
        bounds: Rect.fromLTWH(440, 0, 20, 700),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    ]));
    expect(hinged.isSeparated, isTrue);
  });

  test('simulated flat hinge reports no fold (matches iOS)', () {
    expect(spec.featuresFor(DuoPosture.openWide, DuoHingeState.flat), isEmpty);
    expect(spec.featuresFor(DuoPosture.closedPortrait, DuoHingeState.halfOpened),
        isEmpty);
  });
}
