import 'package:flutter/cupertino.dart' show CupertinoTabBar;
import 'package:flutter/material.dart';

import 'config.dart';
import 'layout_info.dart';

/// Which side the vertical navigation bar sits on when the screen is wide.
enum DuoBarEdge {
  /// Left in left-to-right locales, right in right-to-left.
  leading,

  /// Right in left-to-right locales, left in right-to-left.
  trailing,
}

/// One navigation destination, independent of the bar that shows it.
@immutable
class DuoDestination {
  /// Creates a destination.
  const DuoDestination({
    required this.icon,
    required this.label,
    Widget? selectedIcon,
    this.tooltip,
  }) : selectedIcon = selectedIcon ?? icon;

  /// Icon when not selected.
  final Widget icon;

  /// Icon when selected.
  final Widget selectedIcon;

  /// Text label. Also used in the overflow menu, so always set it.
  final String label;

  /// Tooltip, if different from [label].
  final String? tooltip;
}

/// Navigation extracted from an existing bottom bar.
@immutable
class DuoNavigation {
  /// Creates navigation data.
  const DuoNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Reads a `BottomNavigationBar`, `NavigationBar` or `CupertinoTabBar`.
  /// Returns `null` for anything else: pass `DuoAdaptiveScaffold.navigation`
  /// yourself in that case.
  static DuoNavigation? fromBar(Widget? bar) {
    if (bar is BottomNavigationBar) {
      return DuoNavigation(
        destinations: <DuoDestination>[
          for (final item in bar.items)
            DuoDestination(
              icon: item.icon,
              selectedIcon: item.activeIcon,
              label: item.label ?? '',
              tooltip: item.tooltip,
            ),
        ],
        selectedIndex: bar.currentIndex,
        onSelected: bar.onTap,
      );
    }
    if (bar is NavigationBar) {
      final dests = <DuoDestination>[];
      for (final d in bar.destinations) {
        if (d is! NavigationDestination) return null;
        dests.add(DuoDestination(
          icon: d.icon,
          selectedIcon: d.selectedIcon,
          label: d.label,
          tooltip: d.tooltip,
        ));
      }
      return DuoNavigation(
        destinations: dests,
        selectedIndex: bar.selectedIndex,
        onSelected: bar.onDestinationSelected,
      );
    }
    if (bar is CupertinoTabBar) {
      return DuoNavigation(
        destinations: <DuoDestination>[
          for (final item in bar.items)
            DuoDestination(
              icon: item.icon,
              selectedIcon: item.activeIcon,
              label: item.label ?? '',
              tooltip: item.tooltip,
            ),
        ],
        selectedIndex: bar.currentIndex,
        onSelected: bar.onTap,
      );
    }
    return null;
  }

  /// Destinations in order.
  final List<DuoDestination> destinations;

  /// Currently selected destination.
  final int selectedIndex;

  /// Called with the tapped index.
  final ValueChanged<int>? onSelected;
}

/// What a custom rail builder receives.
@immutable
class DuoRailData {
  /// Creates rail data.
  const DuoRailData({
    required this.navigation,
    required this.visible,
    required this.overflow,
    required this.actions,
    required this.edge,
    required this.info,
  });

  /// All navigation.
  final DuoNavigation navigation;

  /// Indexes shown directly on the rail.
  final List<int> visible;

  /// Indexes that did not fit (show them in a menu).
  final List<int> overflow;

  /// App bar actions moved to the rail (empty unless enabled).
  final List<Widget> actions;

  /// Physical side of the screen the rail is on.
  final AxisDirection edge;

  /// Current layout.
  final DuoLayoutInfo info;
}

/// Builds a fully custom rail.
typedef DuoRailBuilder = Widget Function(BuildContext context, DuoRailData data);

/// Retrofits an existing [Scaffold] for wide and unfolded screens.
///
/// Wrap the scaffold you already have. On a compact screen it looks exactly
/// as before. From regular width (the unfolded iPhone Duo, the outer
/// display held sideways, a tablet) its bottom bar moves to a vertical rail
/// on the side, which is where iOS 27.1 puts tab bars on iPhone Duo.
///
/// ```dart
/// return DuoAdaptiveScaffold(
///   scaffold: Scaffold(
///     appBar: AppBar(title: const Text('Inbox')),
///     body: const InboxList(),
///     bottomNavigationBar: BottomNavigationBar(items: items, ...),
///   ),
/// );
/// ```
///
/// Behaviour you get for free:
///
/// * The body keeps its state (open pages, scroll, selection) across the
///   switch.
/// * Rail and body keep clear of camera cutouts on both sides, in LTR and
///   RTL.
/// * Destinations beyond `DuoAdaptConfig.railMaxDestinations` go into a
///   "More" menu.
/// * With `moveAppBarActionsToRail` (per widget or in config), `AppBar`
///   actions move to the rail, like iOS toolbar items move into the
///   vertical bar.
///
/// Everything can be overridden per widget, and [railBuilder] replaces the
/// rail completely.
class DuoAdaptiveScaffold extends StatefulWidget {
  /// Wraps [scaffold].
  const DuoAdaptiveScaffold({
    super.key,
    required this.scaffold,
    this.navigation,
    this.barEdge = DuoBarEdge.leading,
    this.labelType,
    this.maxDestinations,
    this.moveAppBarActionsToRail,
    this.railLeading,
    this.railTrailing,
    this.railBuilder,
    this.extendRailFrom,
    this.overflowLabel = 'More',
    this.overflowIcon = const Icon(Icons.more_horiz),
    this.showRail,
  });

  /// The scaffold you already have.
  final Scaffold scaffold;

  /// Navigation to show on the rail. Defaults to what [DuoNavigation.fromBar]
  /// reads from `scaffold.bottomNavigationBar`.
  final DuoNavigation? navigation;

  /// Side of the screen for the rail.
  final DuoBarEdge barEdge;

  /// Rail label style. Defaults to `DuoAdaptConfig.railLabelType`.
  final NavigationRailLabelType? labelType;

  /// Destinations before the overflow menu. Defaults to
  /// `DuoAdaptConfig.railMaxDestinations`.
  final int? maxDestinations;

  /// Move `AppBar.actions` into the rail. Defaults to
  /// `DuoAdaptConfig.moveAppBarActionsToRail`.
  final bool? moveAppBarActionsToRail;

  /// Widget above the rail destinations (for example a FAB).
  final Widget? railLeading;

  /// Widget below the rail destinations.
  final Widget? railTrailing;

  /// Replaces the built-in rail.
  final DuoRailBuilder? railBuilder;

  /// Show the extended (labelled, wider) rail from this width.
  final double? extendRailFrom;

  /// Label of the overflow menu button.
  final String overflowLabel;

  /// Icon of the overflow menu button.
  final Widget overflowIcon;

  /// Decides when to use the rail. Defaults to regular width.
  final bool Function(DuoLayoutInfo info)? showRail;

  @override
  State<DuoAdaptiveScaffold> createState() => _DuoAdaptiveScaffoldState();
}

class _DuoAdaptiveScaffoldState extends State<DuoAdaptiveScaffold> {
  // Moves the body between layouts without losing its state.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'DuoAdaptiveScaffold.body');

  @override
  Widget build(BuildContext context) {
    final scaffold = widget.scaffold;
    final config = DuoAdaptConfig.of(context);
    final info = DuoLayoutInfo.of(context);
    final body = KeyedSubtree(
      key: _bodyKey,
      child: scaffold.body ?? const SizedBox.shrink(),
    );
    final useRail = widget.showRail?.call(info) ??
        info.widthClass == DuoSizeClass.regular;
    final nav = useRail
        ? widget.navigation ?? DuoNavigation.fromBar(scaffold.bottomNavigationBar)
        : null;
    if (nav == null || nav.destinations.length < 2) {
      return _copy(scaffold,
          body: body, bottomNavigationBar: scaffold.bottomNavigationBar);
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final railOnLeft = (widget.barEdge == DuoBarEdge.leading) != rtl;
    final max = (widget.maxDestinations ?? config.railMaxDestinations)
        .clamp(2, nav.destinations.length);
    var visible = List<int>.generate(nav.destinations.length, (i) => i);
    var overflow = <int>[];
    if (nav.destinations.length > max) {
      // Keep the selected destination visible.
      visible = List<int>.generate(max - 1, (i) => i);
      if (!visible.contains(nav.selectedIndex)) {
        visible[visible.length - 1] = nav.selectedIndex;
      }
      overflow = [
        for (var i = 0; i < nav.destinations.length; i++)
          if (!visible.contains(i)) i,
      ];
    }

    final moveActions =
        widget.moveAppBarActionsToRail ?? config.moveAppBarActionsToRail;
    final appBar = scaffold.appBar;
    final actions = moveActions && appBar is AppBar
        ? (appBar.actions ?? const <Widget>[])
        : const <Widget>[];

    final data = DuoRailData(
      navigation: nav,
      visible: visible,
      overflow: overflow,
      actions: actions,
      edge: railOnLeft ? AxisDirection.left : AxisDirection.right,
      info: info,
    );
    final rail = widget.railBuilder?.call(context, data) ??
        _defaultRail(context, data, config);

    final children = <Widget>[
      SafeArea(
        left: railOnLeft,
        right: !railOnLeft,
        child: rail,
      ),
      const VerticalDivider(width: 1, thickness: 1),
      // The body keeps clear of the cutout on the edge opposite the rail.
      Expanded(
        child: SafeArea(
          top: false,
          bottom: false,
          left: !railOnLeft,
          right: railOnLeft,
          child: body,
        ),
      ),
    ];

    return _copy(
      scaffold,
      appBar: actions.isNotEmpty ? _withoutActions(appBar! as AppBar) : appBar,
      body: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: railOnLeft ? children : children.reversed.toList(),
      ),
    );
  }

  Widget _defaultRail(
    BuildContext context,
    DuoRailData data,
    DuoAdaptConfig config,
  ) {
    final nav = data.navigation;
    final selectedVisible = data.visible.indexOf(nav.selectedIndex);
    final extend = widget.extendRailFrom != null &&
        data.info.size.width >= widget.extendRailFrom!;
    final trailing = <Widget>[
      if (data.overflow.isNotEmpty)
        PopupMenuButton<int>(
          tooltip: widget.overflowLabel,
          icon: widget.overflowIcon,
          onSelected: nav.onSelected,
          itemBuilder: (context) => <PopupMenuEntry<int>>[
            for (final i in data.overflow)
              PopupMenuItem<int>(
                value: i,
                child: ListTile(
                  leading: nav.destinations[i].icon,
                  title: Text(nav.destinations[i].label),
                ),
              ),
          ],
        ),
      ...data.actions,
      if (widget.railTrailing != null) widget.railTrailing!,
    ];
    return NavigationRail(
      selectedIndex: selectedVisible < 0 ? null : selectedVisible,
      onDestinationSelected: nav.onSelected == null
          ? null
          : (i) => nav.onSelected!(data.visible[i]),
      extended: extend,
      labelType: extend ? NavigationRailLabelType.none : widget.labelType ?? config.railLabelType,
      leading: widget.railLeading,
      trailing: trailing.isEmpty
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: trailing),
      destinations: <NavigationRailDestination>[
        for (final i in data.visible)
          NavigationRailDestination(
            icon: _tip(nav.destinations[i], nav.destinations[i].icon),
            selectedIcon: nav.destinations[i].selectedIcon,
            label: Text(nav.destinations[i].label),
          ),
      ],
    );
  }

  Widget _tip(DuoDestination d, Widget icon) =>
      d.tooltip == null ? icon : Tooltip(message: d.tooltip, child: icon);

  static AppBar _withoutActions(AppBar a) {
    return AppBar(
      key: a.key,
      leading: a.leading,
      automaticallyImplyLeading: a.automaticallyImplyLeading,
      title: a.title,
      flexibleSpace: a.flexibleSpace,
      bottom: a.bottom,
      elevation: a.elevation,
      scrolledUnderElevation: a.scrolledUnderElevation,
      notificationPredicate: a.notificationPredicate,
      shadowColor: a.shadowColor,
      surfaceTintColor: a.surfaceTintColor,
      shape: a.shape,
      backgroundColor: a.backgroundColor,
      foregroundColor: a.foregroundColor,
      iconTheme: a.iconTheme,
      actionsIconTheme: a.actionsIconTheme,
      primary: a.primary,
      centerTitle: a.centerTitle,
      excludeHeaderSemantics: a.excludeHeaderSemantics,
      titleSpacing: a.titleSpacing,
      toolbarOpacity: a.toolbarOpacity,
      bottomOpacity: a.bottomOpacity,
      toolbarHeight: a.toolbarHeight,
      leadingWidth: a.leadingWidth,
      toolbarTextStyle: a.toolbarTextStyle,
      titleTextStyle: a.titleTextStyle,
      systemOverlayStyle: a.systemOverlayStyle,
      forceMaterialTransparency: a.forceMaterialTransparency,
      clipBehavior: a.clipBehavior,
    );
  }

  static Scaffold _copy(
    Scaffold s, {
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? bottomNavigationBar,
  }) {
    return Scaffold(
      key: s.key,
      appBar: appBar ?? s.appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: s.floatingActionButton,
      floatingActionButtonLocation: s.floatingActionButtonLocation,
      floatingActionButtonAnimator: s.floatingActionButtonAnimator,
      persistentFooterButtons: s.persistentFooterButtons,
      persistentFooterAlignment: s.persistentFooterAlignment,
      drawer: s.drawer,
      onDrawerChanged: s.onDrawerChanged,
      endDrawer: s.endDrawer,
      onEndDrawerChanged: s.onEndDrawerChanged,
      bottomSheet: s.bottomSheet,
      backgroundColor: s.backgroundColor,
      resizeToAvoidBottomInset: s.resizeToAvoidBottomInset,
      primary: s.primary,
      drawerDragStartBehavior: s.drawerDragStartBehavior,
      extendBody: s.extendBody,
      drawerBarrierDismissible: s.drawerBarrierDismissible,
      extendBodyBehindAppBar: s.extendBodyBehindAppBar,
      drawerScrimColor: s.drawerScrimColor,
      drawerEdgeDragWidth: s.drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: s.drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: s.endDrawerEnableOpenDragGesture,
      restorationId: s.restorationId,
    );
  }
}
