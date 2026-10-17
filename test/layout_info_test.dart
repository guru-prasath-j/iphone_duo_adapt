import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';

MediaQueryData _mq(Size size, [List<DisplayFeature> f = const []]) =>
    MediaQueryData(size: size, displayFeatures: f);

void main() {
  const spec = DuoDeviceSpec.iPhoneDuo;

  test('closed outer display is compact, portrait, not open', () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(spec.outerPortrait));
    expect(info.widthClass, DuoSizeClass.compact);
    expect(info.heightClass, DuoSizeClass.regular);
    expect(info.posture, DuoPosture.closedPortrait);
    expect(info.isOpen, isFalse);
    expect(info.isOuterDisplay, isTrue);
    expect(info.panes(), isNull);
  });

  test('closed sideways: regular width, compact height, still closed', () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(spec.outerPortrait.flipped));
    expect(info.posture, DuoPosture.closedLandscape);
    expect(info.widthClass, DuoSizeClass.regular);
    expect(info.heightClass, DuoSizeClass.compact);
    expect(info.isOpen, isFalse);
  });

  test('inner display without features is treated as open and flat', () {
    final info = DuoLayoutInfo.fromMediaQuery(_mq(spec.innerWide));
    expect(info.isOpen, isTrue);
    expect(info.hingeState, DuoHingeState.flat);
    expect(info.isSeparated, isFalse);
    expect(info.foldPose, DuoFoldPose.none);
    expect(info.posture, DuoPosture.openWide);
    final (a, b) = info.panes(ratio: 0.5)!;
    expect(a.width, spec.innerWide.width / 2);
    expect(b.left, a.right);
  });

  test('bent wide: book pose, panes either side of the fold', () {
    final data = spec.mediaQueryFor(
      const MediaQueryData(),
      DuoPosture.openWide,
      DuoHingeState.halfOpened,
    );
    final info = DuoLayoutInfo.fromMediaQuery(data);
    expect(info.hingeState, DuoHingeState.halfOpened);
    expect(info.foldAxis, Axis.vertical);
    expect(info.foldPose, DuoFoldPose.book);
    final (a, b) = info.panes()!;
    expect(a.right, info.fold!.left);
    expect(b.left, info.fold!.right);
  });

  test('bent tall: tabletop pose with a horizontal fold', () {
    final data = spec.mediaQueryFor(
      const MediaQueryData(),
      DuoPosture.openTall,
      DuoHingeState.halfOpened,
    );
    final info = DuoLayoutInfo.fromMediaQuery(data);
    expect(info.posture, DuoPosture.openTall);
    expect(info.foldAxis, Axis.horizontal);
    expect(info.foldPose, DuoFoldPose.tabletop);
    final (top, bottom) = info.panes()!;
    expect(top.bottom, info.fold!.top);
    expect(bottom.top, info.fold!.bottom);
  });

  test('areaFor picks the end side, mirrored in RTL for book pose', () {
    final data = spec.mediaQueryFor(
      const MediaQueryData(),
      DuoPosture.openWide,
      DuoHingeState.halfOpened,
    );
    final ltr = DuoLayoutInfo.fromMediaQuery(data);
    final rtl = DuoLayoutInfo.fromMediaQuery(
      data,
      textDirection: TextDirection.rtl,
    );
    expect(ltr.areaFor(DuoFoldSide.end).left, ltr.fold!.right);
    expect(ltr.areaFor(DuoFoldSide.start).right, ltr.fold!.left);
    expect(rtl.areaFor(DuoFoldSide.end).right, rtl.fold!.left);
    final flat = DuoLayoutInfo.fromMediaQuery(_mq(spec.innerWide));
    expect(flat.areaFor(DuoFoldSide.end), Offset.zero & spec.innerWide);
  });

  test(
    'flat fold does not separate, hinge always does, cutout is occlusion',
    () {
      final info = DuoLayoutInfo.fromMediaQuery(
        _mq(const Size(900, 700), [
          const DisplayFeature(
            bounds: Rect.fromLTWH(450, 0, 1, 700),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
          const DisplayFeature(
            bounds: Rect.fromLTWH(10, 10, 20, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ]),
      );
      expect(info.isSeparated, isFalse);
      expect(info.hingeState, DuoHingeState.flat);
      expect(info.occlusions, hasLength(1));

      final hinged = DuoLayoutInfo.fromMediaQuery(
        _mq(const Size(900, 700), [
          const DisplayFeature(
            bounds: Rect.fromLTWH(440, 0, 20, 700),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ]),
      );
      expect(hinged.isSeparated, isTrue);
    },
  );

  test('zero-width fold never splits the screen', () {
    final info = DuoLayoutInfo.fromMediaQuery(
      _mq(const Size(900, 700), [
        const DisplayFeature(
          bounds: Rect.fromLTWH(450, 0, 0, 700),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]),
    );
    expect(info.hingeState, DuoHingeState.halfOpened);
    expect(info.isSeparated, isFalse);
    // Pose still known from the aspect ratio.
    expect(info.foldPose, DuoFoldPose.book);
  });

  test('a native hinge reading wins over size heuristics', () {
    final closed = DuoLayoutInfo.fromMediaQuery(
      _mq(spec.innerWide),
      hinge: const DuoHingeReading(
        state: DuoHingeState.closed,
        source: DuoHingeSource.native,
      ),
    );
    expect(closed.isOpen, isFalse);
    // Split View on the inner display is narrow but still open.
    final split = DuoLayoutInfo.fromMediaQuery(
      _mq(const Size(441, 626)),
      hinge: const DuoHingeReading(
        state: DuoHingeState.flat,
        angleDegrees: 180,
      ),
    );
    expect(split.isOpen, isTrue);
    expect(split.widthClass, DuoSizeClass.compact);
    expect(split.hingeAngle, 180);
  });

  test('config breakpoints are honoured', () {
    const config = DuoAdaptConfig(regularWidthBreakpoint: 1000);
    final info = DuoLayoutInfo.fromMediaQuery(
      _mq(spec.innerWide),
      config: config,
    );
    expect(info.widthClass, DuoSizeClass.compact);
    expect(info.canSplit(), isFalse);
  });

  test('canSplit respects the minimum pane size', () {
    final tall = DuoLayoutInfo.fromMediaQuery(_mq(spec.innerWide.flipped));
    expect(tall.widthClass, DuoSizeClass.regular);
    expect(tall.canSplit(minPaneExtent: 280, ratio: 0.4), isFalse);
    expect(tall.canSplit(minPaneExtent: 200, ratio: 0.4), isTrue);
  });

  test('simulated flat hinge reports no fold (matches iOS)', () {
    expect(spec.featuresFor(DuoPosture.openWide, DuoHingeState.flat), isEmpty);
    expect(
      spec.featuresFor(DuoPosture.closedPortrait, DuoHingeState.halfOpened),
      isEmpty,
    );
  });

  test('toJson has everything an agent needs', () {
    final data = spec.mediaQueryFor(
      const MediaQueryData(),
      DuoPosture.openWide,
      DuoHingeState.halfOpened,
    );
    final json = DuoLayoutInfo.fromMediaQuery(data).toJson();
    expect(json['posture'], 'openWide');
    expect(json['foldPose'], 'book');
    expect(json['folds'], hasLength(1));
    expect(
      json.keys,
      containsAll(<String>[
        'widthClass',
        'heightClass',
        'hingeState',
        'size',
        'padding',
        'occlusions',
      ]),
    );
  });

  test('hinge reading from angle uses Apple-like thresholds', () {
    expect(DuoHingeReading.fromAngle(5).state, DuoHingeState.closed);
    expect(DuoHingeReading.fromAngle(90).state, DuoHingeState.halfOpened);
    expect(DuoHingeReading.fromAngle(175).state, DuoHingeState.flat);
  });

  test('config copyWith and equality', () {
    const a = DuoAdaptConfig();
    final b = a.copyWith(splitRatio: 0.5);
    expect(b.splitRatio, 0.5);
    expect(b == a, isFalse);
    expect(a.copyWith() == a, isTrue);
    expect(a.toJson()['regularWidthBreakpoint'], 600);
  });

  test('native state parses the bridge payload', () {
    final s = DuoNativeState.fromMap(<Object?, Object?>{
      'supported': true,
      'status': 'partiallyOpen',
      'angle': 1.5707963267948966,
      'folds': <Object?>[
        <Object?>[443, 0, 447, 626],
        <Object?>[1, 1, 1, 1], // zero size: dropped
      ],
      'occlusions': <Object?>[
        <Object?>[800, 10, 830, 40],
      ],
    });
    expect(s.supported, isTrue);
    expect(s.hinge!.state, DuoHingeState.halfOpened);
    expect(s.hinge!.angleDegrees, closeTo(90, 0.001));
    expect(s.hinge!.source, DuoHingeSource.native);
    expect(s.features, hasLength(2));
    expect(s.features.first.type, DisplayFeatureType.fold);
    expect(s.features.last.type, DisplayFeatureType.cutout);

    final none = DuoNativeState.fromMap(<Object?, Object?>{
      'supported': true,
      'status': null,
      'angle': null,
    });
    expect(none.hinge, isNull);
  });
}
