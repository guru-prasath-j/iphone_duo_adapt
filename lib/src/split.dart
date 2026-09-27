import 'package:flutter/widgets.dart';

import 'layout_info.dart';

/// Shows two widgets side by side, either side of the fold when there is
/// one, or split at [ratio] on a wide screen. On a compact screen with no
/// fold it shows only [compactChild] (defaults to [first]).
///
/// The fold is mapped into this widget's own coordinates, so it lines up
/// even when the split does not start at the screen edge (for example
/// next to a navigation rail). The position is measured after layout, so a
/// move of the widget takes effect on the following frame.
class DuoSplit extends StatefulWidget {
  /// Creates a split.
  const DuoSplit({
    super.key,
    required this.first,
    required this.second,
    this.compactChild,
    this.ratio = 0.4,
    this.divider,
  });

  /// Leading (or top) pane.
  final Widget first;

  /// Trailing (or bottom) pane.
  final Widget second;

  /// What to show when only one pane fits. Defaults to [first].
  final Widget? compactChild;

  /// Share of the width given to [first] when there is no fold.
  final double ratio;

  /// Drawn in the gap between panes when there is no fold. With a fold,
  /// the fold itself is the gap.
  final Widget? divider;

  @override
  State<DuoSplit> createState() => _DuoSplitState();
}

class _DuoSplitState extends State<DuoSplit> {
  Offset _origin = Offset.zero;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final local = Offset.zero & constraints.biggest;
        final fold = info.fold?.shift(-_origin);
        if (fold != null && _inside(fold, local, info.foldAxis!)) {
          return _foldSplit(local, fold, info.foldAxis!);
        }
        if (info.widthClass == DuoSizeClass.regular) {
          final w = constraints.maxWidth * widget.ratio;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: w, child: widget.first),
              if (widget.divider != null) widget.divider!,
              Expanded(child: widget.second),
            ],
          );
        }
        return widget.compactChild ?? widget.first;
      },
    );
  }

  // True when the fold cuts through this widget, leaving room on both sides.
  static bool _inside(Rect fold, Rect local, Axis axis) =>
      axis == Axis.vertical
          ? fold.left > 0 && fold.right < local.width
          : fold.top > 0 && fold.bottom < local.height;

  Widget _foldSplit(Rect local, Rect fold, Axis axis) {
    if (axis == Axis.vertical) {
      final a = fold.left.clamp(0.0, local.width);
      final b = fold.right.clamp(0.0, local.width);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(width: a, child: widget.first),
          SizedBox(width: b - a),
          Expanded(child: widget.second),
        ],
      );
    }
    final a = fold.top.clamp(0.0, local.height);
    final b = fold.bottom.clamp(0.0, local.height);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: a, child: widget.first),
        SizedBox(height: b - a),
        Expanded(child: widget.second),
      ],
    );
  }
}
