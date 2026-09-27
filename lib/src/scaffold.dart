import 'package:flutter/cupertino.dart' show CupertinoTabBar;
import 'package:flutter/material.dart';

import 'layout_info.dart';

/// Which side the vertical navigation bar sits on when the screen is wide.
enum DuoBarEdge {
  /// Left in left-to-right locales.
  leading,

  /// Right in left-to-right locales.
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
  }) : selectedIcon = selectedIcon ?? icon;

  /// Icon when not selected.
  final Widget icon;

  /// Icon when selected.
  final Widget selectedIcon;

  /// Text label.
  final String label;
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
  /// Returns `null` for anything else (wrap your bar's data in
  /// [DuoNavigation] yourself in that case).
  static DuoNavigation? fromBar(Widget? bar) {
    if (bar is BottomNavigationBar) {
      return DuoNavigation(
        destinations: <DuoDestination>[
          for (final item in bar.items)
            DuoDestination(
              icon: item.icon,
              selectedIcon: item.activeIcon,
              label: item.label ?? '',
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

/// Retrofits an existing [Scaffold] for wide and unfolded screens.
///
/// Wrap the scaffold you already have. On a compact screen it is returned
/// untouched. On a regular-width screen (the unfolded iPhone Duo, a
/// landscape phone, a tablet) its bottom bar is moved to a vertical
/// [NavigationRail] on the side, which is where iOS 27.1 puts tab bars on
/// iPhone Duo.
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
/// Note: the body is re-parented when the layout switches, so state inside
/// it that is not keyed or stored above it is rebuilt on fold/unfold.
class DuoAdaptiveScaffold extends StatelessWidget {
  /// Wraps [scaffold].
  const DuoAdaptiveScaffold({
    super.key,
    required this.scaffold,
    this.navigation,
    this.barEdge = DuoBarEdge.leading,
    this.labelType = NavigationRailLabelType.all,
    this.railLeading,
    this.railTrailing,
  });

  /// The scaffold you already have.
  final Scaffold scaffold;

  /// Navigation to show on the rail. Defaults to what [DuoNavigation.fromBar]
  /// reads from `scaffold.bottomNavigationBar`.
  final DuoNavigation? navigation;

  /// Side of the screen for the rail.
  final DuoBarEdge barEdge;

  /// Rail label style.
  final NavigationRailLabelType labelType;

  /// Widget above the rail destinations (for example a FAB).
  final Widget? railLeading;

  /// Widget below the rail destinations.
  final Widget? railTrailing;

  @override
  Widget build(BuildContext context) {
    final info = DuoLayoutInfo.of(context);
    if (info.widthClass == DuoSizeClass.compact) return scaffold;
    final nav = navigation ?? DuoNavigation.fromBar(scaffold.bottomNavigationBar);
    if (nav == null || nav.destinations.length < 2) return scaffold;

    final rail = NavigationRail(
      selectedIndex: nav.selectedIndex,
      onDestinationSelected: nav.onSelected,
      labelType: labelType,
      leading: railLeading,
      trailing: railTrailing,
      destinations: <NavigationRailDestination>[
        for (final d in nav.destinations)
          NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
      ],
    );
    final body = scaffold.body ?? const SizedBox.shrink();
    final children = <Widget>[
      SafeArea(
        left: barEdge == DuoBarEdge.leading,
        right: barEdge == DuoBarEdge.trailing,
        child: rail,
      ),
      const VerticalDivider(width: 1, thickness: 1),
      Expanded(child: body),
    ];

    final s = scaffold;
    return Scaffold(
      key: s.key,
      appBar: s.appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: barEdge == DuoBarEdge.leading
            ? children
            : children.reversed.toList(),
      ),
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
