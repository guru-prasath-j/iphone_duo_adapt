import 'package:flutter/widgets.dart';

import 'config.dart';
import 'layout_info.dart';
import 'split.dart';

/// How [DuoArrangement] lays out its views on a compact screen.
enum DuoArrangementStyle {
  /// Stacked (primary above secondary) when compact, side by side when
  /// there is room or a fold.
  split,

  /// Secondary floats over primary when compact, side by side when there
  /// is room or a fold.
  overlay,
}

/// Flutter counterpart of Apple's `ArrangementView`: a primary and a
/// secondary view that reflow for every posture.
///
/// ```dart
/// DuoArrangement(
///   primary: const PhotoViewer(),
///   secondary: const PhotoInfo(),
///   style: DuoArrangementStyle.overlay,
///   showSecondary: infoVisible,
/// )
/// ```
///
/// Both views keep their state across changes.
class DuoArrangement extends StatefulWidget {
  /// Creates an arrangement.
  const DuoArrangement({
    super.key,
    required this.primary,
    required this.secondary,
    this.style = DuoArrangementStyle.split,
    this.showSecondary = true,
    this.ratio,
    this.compactSecondaryFlex = 1,
    this.compactPrimaryFlex = 2,
    this.overlayAlignment = Alignment.bottomCenter,
    this.divider,
  });

  /// Main content.
  final Widget primary;

  /// Supporting content.
  final Widget secondary;

  /// Compact behaviour.
  final DuoArrangementStyle style;

  /// Whether the secondary view shows on compact screens (it always shows
  /// when side by side).
  final bool showSecondary;

  /// Share for [primary] when side by side. Defaults to
  /// `1 - DuoAdaptConfig.splitRatio`.
  final double? ratio;

  /// Flex of [secondary] when stacked.
  final int compactSecondaryFlex;

  /// Flex of [primary] when stacked.
  final int compactPrimaryFlex;

  /// Where [secondary] floats in [DuoArrangementStyle.overlay].
  final AlignmentGeometry overlayAlignment;

  /// Between the views when side by side without a fold.
  final Widget? divider;

  @override
  State<DuoArrangement> createState() => _DuoArrangementState();
}

class _DuoArrangementState extends State<DuoArrangement> {
  final GlobalKey _primary = GlobalKey(debugLabel: 'DuoArrangement.primary');
  final GlobalKey _secondary =
      GlobalKey(debugLabel: 'DuoArrangement.secondary');

  @override
  Widget build(BuildContext context) {
    final info = DuoLayoutInfo.of(context);
    final config = DuoAdaptConfig.of(context);
    final ratio = widget.ratio ?? (1 - config.splitRatio);
    final primary = KeyedSubtree(key: _primary, child: widget.primary);
    final secondary = KeyedSubtree(key: _secondary, child: widget.secondary);
    final sideBySide = info.canSplit(
      minPaneExtent: config.minPaneExtent,
      ratio: ratio,
    );
    if (sideBySide) {
      return DuoSplit(
        ratio: ratio,
        minPaneExtent: 0,
        splitWhen: (_) => true,
        divider: widget.divider,
        first: primary,
        second: secondary,
      );
    }
    switch (widget.style) {
      case DuoArrangementStyle.split:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: widget.compactPrimaryFlex, child: primary),
            if (widget.showSecondary)
              Expanded(flex: widget.compactSecondaryFlex, child: secondary),
          ],
        );
      case DuoArrangementStyle.overlay:
        return Stack(
          children: <Widget>[
            Positioned.fill(child: primary),
            if (widget.showSecondary)
              Align(alignment: widget.overlayAlignment, child: secondary),
          ],
        );
    }
  }
}

/// Keeps [child] on one side of a bent fold, so buttons and forms are never
/// cut in half by the crease. Without a fold, [child] fills the space as
/// usual.
///
/// Apple's guidance: move interactive content toward the end (trailing
/// half in book pose, bottom half in tabletop pose) and leave scrolling
/// content alone. That is the default; see `DuoAdaptConfig.foldSide`.
class DuoFoldAvoid extends StatefulWidget {
  /// Creates the widget.
  const DuoFoldAvoid({super.key, required this.child, this.side});

  /// Content to keep off the fold.
  final Widget child;

  /// Which side of the fold. Defaults to `DuoAdaptConfig.foldSide`.
  final DuoFoldSide? side;

  @override
  State<DuoFoldAvoid> createState() => _DuoFoldAvoidState();
}

class _DuoFoldAvoidState extends State<DuoFoldAvoid> {
  Offset _origin = Offset.zero;
  final GlobalKey _childKey = GlobalKey(debugLabel: 'DuoFoldAvoid.child');

  void _measure(Duration _) {
    if (!mounted) return;
    final origin = DuoScreenRoot.originOf(context);
    if (origin == null) return;
    if ((origin - _origin).distance > 0.5) setState(() => _origin = origin);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final info = DuoLayoutInfo.of(context);
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    if (!info.isSeparated) return child;
    final side = widget.side ?? DuoAdaptConfig.of(context).foldSide;
    return LayoutBuilder(builder: (context, constraints) {
      final local = Offset.zero & constraints.biggest;
      final area = info.areaFor(side).shift(-_origin).intersect(local);
      if (area.isEmpty || area.width <= 0 || area.height <= 0) return child;
      return Stack(
        children: <Widget>[Positioned.fromRect(rect: area, child: child)],
      );
    });
  }
}

/// A safe fallback for screens you have not adapted yet.
///
/// On wide screens it centres [child] at phone width instead of stretching
/// it across the unfolded display; when bent it keeps [child] on one side
/// of the fold. Wrap a route's body in it and the screen looks deliberate
/// on iPhone Duo while you work on a proper layout.
class DuoConstrained extends StatelessWidget {
  /// Creates the widget.
  const DuoConstrained({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.avoidFold = true,
    this.alignment = Alignment.topCenter,
    this.side,
  });

  /// Screen content.
  final Widget child;

  /// Widest [child] may get.
  final double maxWidth;

  /// Keep [child] off a bent fold.
  final bool avoidFold;

  /// Placement within the available space.
  final AlignmentGeometry alignment;

  /// Side of the fold, when avoiding it.
  final DuoFoldSide? side;

  @override
  Widget build(BuildContext context) {
    final constrained = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
    if (!avoidFold) return constrained;
    return DuoFoldAvoid(side: side, child: constrained);
  }
}
