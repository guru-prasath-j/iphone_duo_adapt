import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'hinge.dart';

/// What the iOS bridge reports.
@immutable
class DuoNativeState {
  /// Creates a state.
  const DuoNativeState({
    required this.supported,
    this.hinge,
    this.features = const <DisplayFeature>[],
  });

  /// State for platforms and SDKs without hinge support.
  static const DuoNativeState unsupported = DuoNativeState(supported: false);

  /// Parses the map sent over the event channel.
  factory DuoNativeState.fromMap(Map<Object?, Object?> map) {
    final supported = map['supported'] == true;
    final status = map['status'];
    final angle = map['angle'];
    DuoHingeState? state;
    switch (status) {
      case 'closed':
        state = DuoHingeState.closed;
      case 'partiallyOpen':
        state = DuoHingeState.halfOpened;
      case 'fullyOpen':
        state = DuoHingeState.flat;
    }
    final features = <DisplayFeature>[
      for (final r in _rects(map['folds']))
        DisplayFeature(
          bounds: r,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      for (final r in _rects(map['occlusions']))
        DisplayFeature(
          bounds: r,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
    ];
    final hasHinge = state != null || angle is num;
    return DuoNativeState(
      supported: supported,
      hinge: hasHinge
          ? DuoHingeReading(
              state: state,
              // UIHinge.angle is in radians.
              angleDegrees:
                  angle is num ? angle.toDouble() * 180 / math.pi : null,
              source: DuoHingeSource.native,
            )
          : null,
      features: features,
    );
  }

  /// Whether this OS and SDK can report the hinge (iOS 27.1+ built with the
  /// iOS 27.1 SDK, on a device that has one).
  final bool supported;

  /// Latest hinge reading.
  final DuoHingeReading? hinge;

  /// Fold and camera regions, in logical pixels of the Flutter view.
  final List<DisplayFeature> features;

  static Iterable<Rect> _rects(Object? raw) sync* {
    if (raw is! List) return;
    for (final r in raw) {
      if (r is List && r.length == 4 && r.every((v) => v is num)) {
        final v = r.cast<num>();
        final rect = Rect.fromLTRB(
            v[0].toDouble(), v[1].toDouble(), v[2].toDouble(), v[3].toDouble());
        if (rect.width > 0 && rect.height > 0) yield rect;
      }
    }
  }

  @override
  String toString() =>
      'DuoNativeState(supported: $supported, $hinge, $features)';
}

/// Reads the hinge and fold regions from UIKit on iOS 27.1+
/// (`UIHingeInteraction` and `UIView.reservedRegions`), so apps get real
/// fold data before the Flutter engine reports it.
///
/// `DuoAdapt` starts it for you when `DuoAdaptConfig.useNativeBridge` is on.
/// On other platforms, older iOS versions, or apps built with an older
/// Xcode, [state] reports `supported: false` and nothing else happens.
class DuoNativeBridge {
  DuoNativeBridge._();

  /// The shared bridge.
  static final DuoNativeBridge instance = DuoNativeBridge._();

  static const MethodChannel _methods = MethodChannel('iphone_duo_adapt');
  static const EventChannel _events = EventChannel('iphone_duo_adapt/events');

  /// Latest state; `null` until the bridge has answered.
  final ValueNotifier<DuoNativeState?> state =
      ValueNotifier<DuoNativeState?>(null);

  StreamSubscription<Object?>? _sub;
  bool _starting = false;

  /// Whether the current platform can have a native bridge at all.
  static bool get platformHasBridge =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Starts listening. Safe to call many times.
  Future<void> start() async {
    if (_sub != null || _starting) return;
    if (!platformHasBridge) {
      state.value = DuoNativeState.unsupported;
      return;
    }
    _starting = true;
    try {
      final caps = await _methods.invokeMapMethod<Object?, Object?>(
          'getCapabilities');
      if (caps == null || caps['supported'] != true) {
        state.value = DuoNativeState.unsupported;
        return;
      }
      _sub = _events.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            state.value = DuoNativeState.fromMap(event.cast<Object?, Object?>());
          }
        },
        onError: (Object _) => state.value = DuoNativeState.unsupported,
      );
    } on MissingPluginException {
      // Plugin not registered (tests, or an add-to-app host without it).
      state.value = DuoNativeState.unsupported;
    } on PlatformException {
      state.value = DuoNativeState.unsupported;
    } finally {
      _starting = false;
    }
  }

  /// Stops listening.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Replaces the state, for tests and demos.
  @visibleForTesting
  void debugSetState(DuoNativeState? value) => state.value = value;
}
