import 'package:flutter/cupertino.dart';

import 'layout_info.dart';
import 'scaffold.dart' show DuoBarEdge;

/// Drop-in replacement for [CupertinoTabScaffold] that moves the tab bar to
/// a vertical rail on regular width.
///
/// Same constructor as [CupertinoTabScaffold], so migrating is a rename
/// (`dart run iphone_duo_adapt:duo_migrate` does it for you). Each tab keeps
/// its state, including its navigation stack, when the device folds or
/// unfolds. It uses no Material widgets, so it works inside `CupertinoApp`.
class DuoCupertinoTabScaffold extends StatefulWidget {
  /// Creates the scaffold.
  const DuoCupertinoTabScaffold({
    super.key,
    required this.tabBar,
    required this.tabBuilder,
    this.controller,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.restorationId,
    this.barEdge = DuoBarEdge.leading,
    this.railWidth = 80,
    this.railBuilder,
    this.showRail,
  });

  /// The tab bar used on compact screens. Its items, colours and `onTap`
  /// are reused for the rail.
  final CupertinoTabBar tabBar;

  /// Builds each tab, lazily on first visit.
  final IndexedWidgetBuilder tabBuilder;

  /// Controls the selected tab.
  final CupertinoTabController? controller;

  /// Background behind the tabs.
  final Color? backgroundColor;

  /// Pad the tabs for the on-screen keyboard.
  final bool resizeToAvoidBottomInset;

  /// Restoration id (reserved for parity with [CupertinoTabScaffold]).
  final String? restorationId;

  /// Side of the rail.
  final DuoBarEdge barEdge;

  /// Width of the built-in rail.
  final double railWidth;

  /// Replaces the built-in rail. Receives the selected index and a
  /// callback to select another.
  final Widget Function(
    BuildContext context,
    int selectedIndex,
    ValueChanged<int> onSelect,
  )? railBuilder;

  /// Decides when to use the rail. Defaults to regular width.
  final bool Function(DuoLayoutInfo info)? showRail;

  @override
  State<DuoCupertinoTabScaffold> createState() =>
      _DuoCupertinoTabScaffoldState();
}

class _DuoCupertinoTabScaffoldState extends State<DuoCupertinoTabScaffold> {
  CupertinoTabController? _own;
  final Set<int> _visited = <int>{};
  final List<GlobalKey> _tabKeys = <GlobalKey>[];
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'DuoCupertinoTabs');

  CupertinoTabController get _controller =>
      widget.controller ?? (_own ??= CupertinoTabController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(DuoCupertinoTabScaffold oldWidget) {
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

  void _changed() => setState(() {});

  void _select(int i) {
    widget.tabBar.onTap?.call(i);
    _controller.index = i;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.tabBar.items.length;
    while (_tabKeys.length < count) {
      _tabKeys.add(GlobalKey(debugLabel: 'DuoCupertinoTab${_tabKeys.length}'));
    }
    final index = _controller.index.clamp(0, count - 1);
    _visited.add(index);

    final info = DuoLayoutInfo.of(context);
    final useRail =
        widget.showRail?.call(info) ?? info.widthClass == DuoSizeClass.regular;
    final media = MediaQuery.of(context);
    final background = widget.backgroundColor ??
        CupertinoTheme.of(context).scaffoldBackgroundColor;

    Widget tabs = IndexedStack(
      index: index,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          KeyedSubtree(
            key: _tabKeys[i],
            child: _visited.contains(i)
                ? widget.tabBuilder(context, i)
                : const SizedBox.shrink(),
          ),
      ],
    );
    tabs = KeyedSubtree(key: _contentKey, child: tabs);

    final keyboard =
        widget.resizeToAvoidBottomInset ? media.viewInsets.bottom : 0.0;

    if (!useRail) {
      final bar = widget.tabBar.copyWith(currentIndex: index, onTap: _select);
      final barHeight = bar.preferredSize.height + media.padding.bottom;
      final showBar = keyboard == 0;
      return ColoredBox(
        color: CupertinoDynamicColor.resolve(background, context),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    bottom: showBar ? barHeight : media.padding.bottom,
                  ),
                  viewInsets: media.viewInsets.copyWith(bottom: 0),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboard),
                  child: tabs,
                ),
              ),
            ),
            if (showBar) Positioned(left: 0, right: 0, bottom: 0, child: bar),
          ],
        ),
      );
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final railOnLeft = (widget.barEdge == DuoBarEdge.leading) != rtl;
    final rail = widget.railBuilder?.call(context, index, _select) ??
        _CupertinoRail(
          bar: widget.tabBar,
          selected: index,
          onSelect: _select,
          width: widget.railWidth,
        );
    final children = <Widget>[
      SafeArea(left: railOnLeft, right: !railOnLeft, child: rail),
      Container(
        width: 0.5,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ),
      ),
      Expanded(
        child: MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              left: railOnLeft ? 0 : media.padding.left,
              right: railOnLeft ? media.padding.right : 0,
            ),
            viewInsets: media.viewInsets.copyWith(bottom: 0),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: tabs,
          ),
        ),
      ),
    ];
    return ColoredBox(
      color: CupertinoDynamicColor.resolve(background, context),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: railOnLeft ? children : children.reversed.toList(),
      ),
    );
  }
}

class _CupertinoRail extends StatelessWidget {
  const _CupertinoRail({
    required this.bar,
    required this.selected,
    required this.onSelect,
    required this.width,
  });

  final CupertinoTabBar bar;
  final int selected;
  final ValueChanged<int> onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    final active = CupertinoDynamicColor.resolve(
      bar.activeColor ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final inactive = CupertinoDynamicColor.resolve(bar.inactiveColor, context);
    final background = bar.backgroundColor == null
        ? CupertinoTheme.of(context).barBackgroundColor
        : bar.backgroundColor!;
    return ColoredBox(
      color: CupertinoDynamicColor.resolve(background, context),
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: <Widget>[
            for (var i = 0; i < bar.items.length; i++)
              Semantics(
                selected: i == selected,
                button: true,
                label: bar.items[i].label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: IconTheme(
                      data: IconThemeData(
                        color: i == selected ? active : inactive,
                        size: bar.iconSize,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          i == selected
                              ? bar.items[i].activeIcon
                              : bar.items[i].icon,
                          if (bar.items[i].label != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                bar.items[i].label!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: i == selected ? active : inactive,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
