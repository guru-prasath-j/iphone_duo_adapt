import 'package:flutter/widgets.dart';

import 'config.dart';
import 'layout_info.dart';

/// How [DuoSplit] arranges its panes when no fold decides it.
enum DuoSplitAxis {
  /// Side by side on regular width (the default).
  auto,

  /// Always side by side.
  horizontal,

  /// Always stacked.
  vertical,
}

/// Shows two widgets together: either side of the fold when there is one,
/// or split at [ratio] when both fit. Otherwise shows only [compactChild]
/// (defaults to [first]).
///
/// * Book pose (vertical fold): left/right halves, exactly at the fold.
/// * Tabletop pose (horizontal fold): top/bottom halves.
/// * Right-to-left locales: [first] goes on the right.
/// * Both panes keep their state when the arrangement changes.
///
/// The fold is mapped into this widget's own coordinates, so it lines up
/// even when the split does not start at the screen edge (for example next
/// to a navigation rail). The position is measured after layout, so a move
/// of the widget takes effect on the following frame.
class DuoSplit extends StatefulWidget {
  /// Creates a split.
  const DuoSplit({
    super.key,
    required this.first,
    required this.second,
    this.compactChild,
    this.ratio,
    this.minPaneExtent,
    this.axis = DuoSplitAxis.auto,
    this.divider,
    this.splitWhen,
  });

  /// Leading (or top) pane.
  final Widget first;

  /// Trailing (or bottom) pane.
  final Widget second;

  /// What to show when only one pane fits. Defaults to [first].
  final Widget? compactChild;

  /// Share given to [first] when there is no fold. Defaults to
  /// `DuoAdaptConfig.splitRatio`.
  final double? ratio;

  /// Smallest pane size before falling back to one pane. Defaults to
  /// `DuoAdaptConfig.minPaneExtent`.
  final double? minPaneExtent;

  /// Arrangement when no fold decides it.
  final DuoSplitAxis axis;

  /// Drawn between panes when there is no fold. With a fold, the fold
  /// itself is the gap.
  final Widget? divider;

  /// Decides when to split without a fold. Defaults to regular width with
  /// both panes at least [minPaneExtent].
  final bool Function(DuoLayoutInfo info)? splitWhen;

  @override
  State<DuoSplit> createState() => _DuoSplitState();
}

class _DuoSplitState extends State<DuoSplit> {
  Offset _origin = Offset.zero;
  final GlobalKey _firstKey = GlobalKey(debugLabel: 'DuoSplit.first');
  final GlobalKey _secondKey = GlobalKey(debugLabel: 'DuoSplit.second');

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
    final config = DuoAdaptConfig.of(context);
    final ratio = (widget.ratio ?? config.splitRatio).clamp(0.05, 0.95);
    final minExtent = widget.minPaneExtent ?? config.minPaneExtent;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final first = KeyedSubtree(key: _firstKey, child: widget.first);
    final second = KeyedSubtree(key: _secondKey, child: widget.second);

    return LayoutBuilder(
      builder: (context, constraints) {
        final local = Offset.zero & constraints.biggest;
        final fold = info.fold?.shift(-_origin);
        final axis = info.foldAxis;
        if (fold != null && axis != null && _inside(fold, local, axis)) {
          return _foldSplit(local, fold, axis, rtl, first, second);
        }

        final vertical = widget.axis == DuoSplitAxis.vertical;
        final extent = vertical ? constraints.maxHeight : constraints.maxWidth;
        final fits = extent.isFinite &&
            extent * ratio >= minExtent &&
            extent * (1 - ratio) >= minExtent;
        final wanted = widget.splitWhen?.call(info) ??
            (widget.axis != DuoSplitAxis.auto ||
                info.widthClass == DuoSizeClass.regular);
        if (wanted && fits) {
          final a = extent * ratio;
          final children = <Widget>[
            if (vertical)
              SizedBox(height: a, child: first)
            else
              SizedBox(width: a, child: first),
            if (widget.divider != null) widget.divider!,
            Expanded(child: second),
          ];
          return vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
        }
        return widget.compactChild ?? first;
      },
    );
  }

  // True when the fold cuts through this widget, leaving room on both sides.
  static bool _inside(Rect fold, Rect local, Axis axis) =>
      axis == Axis.vertical
          ? fold.left > 0 && fold.right < local.width
          : fold.top > 0 && fold.bottom < local.height;

  Widget _foldSplit(
    Rect local,
    Rect fold,
    Axis axis,
    bool rtl,
    Widget first,
    Widget second,
  ) {
    if (axis == Axis.vertical) {
      final left = fold.left.clamp(0.0, local.width);
      final gap = (fold.right - fold.left).clamp(0.0, local.width);
      final panes = rtl ? <Widget>[second, first] : <Widget>[first, second];
      return Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(width: left, child: panes[0]),
          SizedBox(width: gap),
          Expanded(child: panes[1]),
        ],
      );
    }
    final top = fold.top.clamp(0.0, local.height);
    final gap = (fold.bottom - fold.top).clamp(0.0, local.height);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: top, child: first),
        SizedBox(height: gap),
        Expanded(child: second),
      ],
    );
  }
}
