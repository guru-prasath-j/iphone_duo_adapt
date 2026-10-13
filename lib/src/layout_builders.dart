import 'package:flutter/widgets.dart';

import 'config.dart';
import 'layout_info.dart';

/// Builds with the current [DuoLayoutInfo]. The general-purpose escape
/// hatch: any layout decision can be made in [builder].
class DuoLayoutBuilder extends StatelessWidget {
  /// Creates the builder.
  const DuoLayoutBuilder({super.key, required this.builder});

  /// Called with the current layout info.
  final Widget Function(BuildContext context, DuoLayoutInfo info) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context, DuoLayoutInfo.of(context));
}

/// Picks a builder per screen shape.
///
/// Resolution order: [tabletop] or [book] when bent (if given), then
/// [regular] for regular width, then [compact]. Only [compact] is required.
/// With `DuoAdaptConfig.transitionDuration` above zero, switches cross-fade.
class DuoLayoutSwitcher extends StatelessWidget {
  /// Creates the switcher.
  const DuoLayoutSwitcher({
    super.key,
    required this.compact,
    this.regular,
    this.book,
    this.tabletop,
    this.transitionDuration,
  });

  /// Narrow screens (outer display, Split View).
  final WidgetBuilder compact;

  /// Wide screens (inner display, landscape).
  final WidgetBuilder? regular;

  /// Bent with a vertical fold.
  final WidgetBuilder? book;

  /// Bent with a horizontal fold.
  final WidgetBuilder? tabletop;

  /// Overrides `DuoAdaptConfig.transitionDuration`.
  final Duration? transitionDuration;

  /// Which builder applies to [info]. Public so tests and tools can check
  /// the decision without building.
  String resolve(DuoLayoutInfo info) {
    if (info.foldPose == DuoFoldPose.tabletop && tabletop != null) {
      return 'tabletop';
    }
    if (info.foldPose == DuoFoldPose.book && book != null) return 'book';
    if (info.widthClass == DuoSizeClass.regular && regular != null) {
      return 'regular';
    }
    return 'compact';
  }

  @override
  Widget build(BuildContext context) {
    final info = DuoLayoutInfo.of(context);
    final which = resolve(info);
    final builder = switch (which) {
      'tabletop' => tabletop!,
      'book' => book!,
      'regular' => regular!,
      _ => compact,
    };
    final child = KeyedSubtree(
      key: ValueKey<String>(which),
      child: builder(context),
    );
    final config = DuoAdaptConfig.of(context);
    final duration = transitionDuration ?? config.transitionDuration;
    if (duration == Duration.zero) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: config.transitionCurve,
      switchOutCurve: config.transitionCurve,
      child: child,
    );
  }
}

/// Calls [onChanged] when the posture, size class or fold pose changes,
/// without rebuilding [child]. Use it to re-select a camera, pause video,
/// save a draft or log analytics when the device folds or unfolds.
class DuoPostureObserver extends StatefulWidget {
  /// Creates the observer.
  const DuoPostureObserver({
    super.key,
    required this.onChanged,
    required this.child,
    this.when,
  });

  /// Called with the previous and the new layout info.
  final void Function(DuoLayoutInfo previous, DuoLayoutInfo current) onChanged;

  /// Decides whether a change is worth reporting. Defaults to: posture,
  /// width class, height class, hinge state or fold pose changed.
  final bool Function(DuoLayoutInfo previous, DuoLayoutInfo current)? when;

  /// Subtree.
  final Widget child;

  @override
  State<DuoPostureObserver> createState() => _DuoPostureObserverState();
}

class _DuoPostureObserverState extends State<DuoPostureObserver> {
  DuoLayoutInfo? _last;

  static bool _defaultWhen(DuoLayoutInfo a, DuoLayoutInfo b) =>
      a.posture != b.posture ||
      a.widthClass != b.widthClass ||
      a.heightClass != b.heightClass ||
      a.hingeState != b.hingeState ||
      a.foldPose != b.foldPose;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = DuoLayoutInfo.of(context);
    final last = _last;
    if (last != null && (widget.when ?? _defaultWhen)(last, now)) {
      // After the frame, so the callback may call setState anywhere.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(last, now);
      });
    }
    _last = now;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
