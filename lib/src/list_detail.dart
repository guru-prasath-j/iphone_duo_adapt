import 'package:flutter/material.dart';

import 'layout_info.dart';
import 'split.dart';

/// Builds the list pane. Call [onSelect] when the user picks an item.
typedef DuoListBuilder<T> = Widget Function(
  BuildContext context,
  T? selected,
  ValueChanged<T> onSelect,
);

/// Builds the detail pane for [item].
typedef DuoDetailBuilder<T> = Widget Function(BuildContext context, T item);

/// Turns a list-then-detail flow into side-by-side panes on wide screens.
///
/// On a compact screen tapping an item pushes the detail as a new route,
/// just like most apps do today. On a regular-width screen, or whenever a
/// fold divides the screen, the list stays on one side and the detail
/// shows on the other. If the user unfolds the phone while a pushed detail
/// is open, the route is closed and the same item shows in the split view.
class DuoListDetail<T extends Object> extends StatefulWidget {
  /// Creates the list/detail layout.
  const DuoListDetail({
    super.key,
    required this.listBuilder,
    required this.detailBuilder,
    this.emptyDetail,
    this.initialSelection,
    this.ratio = 0.4,
    this.compactRouteBuilder,
  });

  /// Builds the list.
  final DuoListBuilder<T> listBuilder;

  /// Builds a detail page body.
  final DuoDetailBuilder<T> detailBuilder;

  /// Shown in the detail pane before anything is selected.
  final Widget? emptyDetail;

  /// Item selected at start.
  final T? initialSelection;

  /// Share of the width given to the list when there is no fold.
  final double ratio;

  /// Wraps the detail in a route on compact screens. Defaults to a
  /// [MaterialPageRoute] with a plain [Scaffold] and back button.
  final Route<void> Function(BuildContext context, Widget detail)?
      compactRouteBuilder;

  @override
  State<DuoListDetail<T>> createState() => _DuoListDetailState<T>();
}

class _DuoListDetailState<T extends Object> extends State<DuoListDetail<T>> {
  T? _selected;
  Route<void>? _pushed;
  // Keeps the list's state (scroll position) when it moves into the split.
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  bool _isSplit(DuoLayoutInfo info) =>
      info.isSeparated || info.widthClass == DuoSizeClass.regular;

  void _select(T item) {
    setState(() => _selected = item);
    if (_isSplit(DuoLayoutInfo.of(context))) return;
    final detail = Builder(builder: (c) => widget.detailBuilder(c, item));
    final route = widget.compactRouteBuilder?.call(context, detail) ??
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(appBar: AppBar(), body: detail),
        );
    _pushed = route;
    Navigator.of(context).push(route).then((_) {
      if (_pushed == route) _pushed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = DuoLayoutInfo.of(context);
    final split = _isSplit(info);
    final pushed = _pushed;
    if (split && pushed != null && pushed.isActive) {
      // Unfolded while a compact detail route was open: fold it into the
      // split view instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pushed.isActive) {
          Navigator.of(context).removeRoute(pushed);
        }
      });
      _pushed = null;
    }
    final list = KeyedSubtree(
      key: _listKey,
      child: widget.listBuilder(context, split ? _selected : null, _select),
    );
    if (!split) return list;
    final selected = _selected;
    final detail = selected == null
        ? (widget.emptyDetail ?? const SizedBox.shrink())
        : KeyedSubtree(
            key: ValueKey<T>(selected),
            child: widget.detailBuilder(context, selected),
          );
    return DuoSplit(
      ratio: widget.ratio,
      divider: const VerticalDivider(width: 1, thickness: 1),
      first: list,
      second: detail,
    );
  }
}
