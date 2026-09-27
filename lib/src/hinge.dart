import 'package:flutter/widgets.dart';

import 'scope.dart';

/// Coarse hinge state, the same buckets `UIHingeInteraction` reports.
enum DuoHingeState {
  /// Folded shut (or not a foldable).
  closed,

  /// Partly open, like a book held in the hand or a laptop on a table.
  halfOpened,

  /// Fully open and flat.
  flat,
}

/// Where a hinge reading came from.
enum DuoHingeSource {
  /// UIKit's `UIHingeInteraction` through this package's iOS bridge.
  native,

  /// A preview slider, a test, or your own code.
  simulated,
}

/// One reading of the hinge.
@immutable
class DuoHingeReading {
  /// Creates a reading.
  const DuoHingeReading({
    this.state,
    this.angleDegrees,
    this.source = DuoHingeSource.simulated,
  });

  /// Builds a reading from an angle alone, with Apple-like thresholds:
  /// below [closedBelow] degrees is closed, at or above [flatFrom] is flat.
  factory DuoHingeReading.fromAngle(
    double degrees, {
    double closedBelow = 10,
    double flatFrom = 170,
    DuoHingeSource source = DuoHingeSource.simulated,
  }) {
    final state = degrees < closedBelow
        ? DuoHingeState.closed
        : degrees >= flatFrom
            ? DuoHingeState.flat
            : DuoHingeState.halfOpened;
    return DuoHingeReading(state: state, angleDegrees: degrees, source: source);
  }

  /// Coarse state, or `null` if the source does not know.
  final DuoHingeState? state;

  /// Angle between the two halves in degrees (0 shut, 180 flat), if known.
  final double? angleDegrees;

  /// Where the reading came from.
  final DuoHingeSource source;

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'state': state?.name,
        'angleDegrees': angleDegrees,
        'source': source.name,
      };

  @override
  bool operator ==(Object other) =>
      other is DuoHingeReading &&
      other.state == state &&
      other.angleDegrees == angleDegrees &&
      other.source == source;

  @override
  int get hashCode => Object.hash(state, angleDegrees, source);

  @override
  String toString() => 'DuoHingeReading(${state?.name}, $angleDegrees°)';
}

/// Rebuilds with the latest hinge reading (`null` when no source reports
/// one). Use it for effects that follow the hinge angle, such as a
/// parallax or a lid-closing animation. Apple advises against using the
/// angle for layout; use `DuoLayoutInfo` for that.
class DuoHingeBuilder extends StatelessWidget {
  /// Creates the builder.
  const DuoHingeBuilder({super.key, required this.builder});

  /// Called with the current reading.
  final Widget Function(BuildContext context, DuoHingeReading? hinge) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context, DuoScope.maybeOf(context)?.hinge);
}

/// Calls [onChanged] whenever the hinge reading changes, without
/// rebuilding [child]. The Flutter counterpart of SwiftUI's
/// `onHingeChange`.
class DuoHingeListener extends StatefulWidget {
  /// Creates the listener.
  const DuoHingeListener({
    super.key,
    required this.onChanged,
    required this.child,
  });

  /// Called with the previous and the new reading.
  final void Function(DuoHingeReading? previous, DuoHingeReading? current)
      onChanged;

  /// Subtree.
  final Widget child;

  @override
  State<DuoHingeListener> createState() => _DuoHingeListenerState();
}

class _DuoHingeListenerState extends State<DuoHingeListener> {
  DuoHingeReading? _last;
  bool _seen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = DuoScope.maybeOf(context)?.hinge;
    final last = _last;
    if (_seen && now != last) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(last, now);
      });
    }
    _seen = true;
    _last = now;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
