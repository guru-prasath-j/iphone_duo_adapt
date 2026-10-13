import 'package:flutter/material.dart';

import 'config.dart';
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

/// Controls a [DuoListDetail] from outside: select or clear an item from a
/// deep link, a notification, a test or an AI agent.
class DuoListDetailController<T extends Object> extends ChangeNotifier {
  /// Creates a controller.
  DuoListDetailController({T? initialSelection}) : _selected = initialSelection;

  T? _selected;

  /// Selected item.
  T? get selected => _selected;

  /// Selects [item] (opens its page on compact screens).
  void select(T item) {
    _selected = item;
    notifyListeners();
  }

  /// Clears the selection (closes the page on compact screens).
  void clear() {
    _selected = null;
    notifyListeners();
  }
}

/// Turns a list-then-detail flow into side-by-side panes on wide screens.
///
/// * Compact (outer display, Split View): tapping pushes the detail as a
///   new route, like most phone apps do.
/// * Regular width, or whenever a fold divides the screen: list on one side,
///   detail on the other, split exactly at the fold when bent.
/// * Unfolding with a pushed detail open closes the route and shows the
///   same item in the split. Folding with an item selected keeps the list
///   (set [openDetailOnFold] to push it instead).
/// * The list keeps its scroll position across every switch.
class DuoListDetail<T extends Object> extends StatefulWidget {
  /// Creates the list/detail layout.
  const DuoListDetail({
    super.key,
    required this.listBuilder,
    required this.detailBuilder,
    this.emptyDetail,
    this.initialSelection,
    this.controller,
    this.onSelectionChanged,
    this.ratio,
    this.minPaneExtent,
    this.compactRouteBuilder,
    this.divider,
    this.openDetailOnFold = false,
    this.splitWhen,
  });

  /// Builds the list.
  final DuoListBuilder<T> listBuilder;

  /// Builds a detail page body.
  final DuoDetailBuilder<T> detailBuilder;

  /// Shown in the detail pane before anything is selected.
  final Widget? emptyDetail;

  /// Item selected at start (ignored when [controller] is given).
  final T? initialSelection;

  /// External control of the selection.
  final DuoListDetailController<T>? controller;

  /// Called whenever the selection changes.
  final ValueChanged<T?>? onSelectionChanged;

  /// Share of the width for the list when there is no fold. Defaults to
  /// `DuoAdaptConfig.splitRatio`.
  final double? ratio;

  /// Smallest pane width before falling back to one pane. Defaults to
  /// `DuoAdaptConfig.minPaneExtent`.
  final double? minPaneExtent;

  /// Wraps the detail in a route on compact screens. Defaults to a
  /// [MaterialPageRoute] with a plain [Scaffold] and back button.
  final Route<void> Function(BuildContext context, Widget detail)?
      compactRouteBuilder;

  /// Between the panes when there is no fold.
  final Widget? divider;

  /// When the device folds with an item selected, push its detail page.
  final bool openDetailOnFold;

  /// Decides when to split. Defaults to a fold being present or both panes
  /// fitting at regular width.
  final bool Function(DuoLayoutInfo info)? splitWhen;

  @override
  State<DuoListDetail<T>> createState() => _DuoListDetailState<T>();
}

class _DuoListDetailState<T extends Object> extends State<DuoListDetail<T>> {
  DuoListDetailController<T>? _own;
  Route<void>? _pushed;
  bool? _wasSplit;
  // Keeps the list's state (scroll position) when it moves into the split.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'DuoListDetail.list');

  DuoListDetailController<T> get _controller =>
      widget.controller ??
      (_own ??= DuoListDetailController<T>(
        initialSelection: widget.initialSelection,
      ));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(DuoListDetail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  T? _lastReported;

  void _changed() {
    final selected = _controller.selected;
    if (selected != _lastReported) {
      _lastReported = selected;
      widget.onSelectionChanged?.call(selected);
    }
    if (!mounted) return;
    setState(() {});
    final info = DuoLayoutInfo.of(context);
    if (_isSplit(info)) return;
    if (selected == null) {
      _closePushed();
    } else if (_pushed == null || !_pushed!.isActive) {
      _push(selected);
    }
  }

  bool _isSplit(DuoLayoutInfo info) {
    final custom = widget.splitWhen;
    if (custom != null) return custom(info);
    final config = DuoAdaptConfig.of(context);
    return info.canSplit(
      minPaneExtent: widget.minPaneExtent ?? config.minPaneExtent,
      ratio: widget.ratio ?? config.splitRatio,
    );
  }

  void _push(T item) {
    final detail = Builder(builder: (c) => widget.detailBuilder(c, item));
    final route = widget.compactRouteBuilder?.call(context, detail) ??
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(appBar: AppBar(), body: detail),
        );
    _pushed = route;
    Navigator.of(context).push(route).then((_) {
      if (_pushed == route) {
        _pushed = null;
        // Back from the detail page: clear so the list shows no selection.
        if (mounted && !_isSplit(DuoLayoutInfo.of(context))) {
          _controller.clear();
        }
      }
    });
  }

  void _closePushed() {
    final pushed = _pushed;
    _pushed = null;
    if (pushed != null && pushed.isActive) {
      Navigator.of(context).removeRoute(pushed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = DuoLayoutInfo.of(context);
    final split = _isSplit(info);
    final selected = _controller.selected;

    if (_wasSplit != split) {
      final wasSplit = _wasSplit;
      _wasSplit = split;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (split) {
          // Unfolded while a compact detail route was open: show it in the
          // split instead.
          _closePushed();
        } else if (wasSplit == true &&
            selected != null &&
            widget.openDetailOnFold) {
          _push(selected);
        } else if (wasSplit == true && !widget.openDetailOnFold) {
          // Folded: back to the plain list.
          _controller.clear();
        }
      });
    }

    final list = KeyedSubtree(
      key: _listKey,
      child: widget.listBuilder(
        context,
        split ? selected : null,
        _controller.select,
      ),
    );
    if (!split) return list;
    final config = DuoAdaptConfig.of(context);
    final detail = selected == null
        ? (widget.emptyDetail ?? const SizedBox.shrink())
        : KeyedSubtree(
            key: ValueKey<T>(selected),
            child: widget.detailBuilder(context, selected),
          );
    return DuoSplit(
      ratio: widget.ratio ?? config.splitRatio,
      minPaneExtent: 0,
      splitWhen: (_) => true,
      divider: widget.divider ?? const VerticalDivider(width: 1, thickness: 1),
      first: list,
      second: detail,
    );
  }
}
