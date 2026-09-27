import 'package:flutter/widgets.dart';

import 'config.dart';
import 'hinge.dart';

/// Holds the `GlobalKey`s behind [DuoSlot]s, so a widget keeps its state
/// when a layout change moves it to a different parent.
class DuoSlotRegistry {
  final Map<Object, GlobalKey> _keys = <Object, GlobalKey>{};

  /// Key for slot [id], created on first use.
  GlobalKey keyFor(Object id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'DuoSlot($id)'));

  /// Forgets slot [id] (its state is dropped next time it is built).
  void forget(Object id) => _keys.remove(id);

  /// Ids currently registered.
  Iterable<Object> get ids => _keys.keys;
}

/// Data `DuoAdapt` shares with the tree: settings, the latest hinge reading
/// and the slot registry. Read it with [DuoScope.maybeOf]; most code should
/// use `DuoLayoutInfo.of` or `DuoAdaptConfig.of` instead.
class DuoScope extends InheritedWidget {
  /// Creates the scope. `DuoAdapt` does this for you.
  const DuoScope({
    super.key,
    required this.config,
    required this.slots,
    this.hinge,
    required super.child,
  });

  /// Settings.
  final DuoAdaptConfig config;

  /// Latest hinge reading, if any source reports one.
  final DuoHingeReading? hinge;

  /// State keepers for [DuoSlot].
  final DuoSlotRegistry slots;

  /// Nearest scope, or `null` outside `DuoAdapt`.
  static DuoScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoScope>();

  @override
  bool updateShouldNotify(DuoScope oldWidget) =>
      oldWidget.config != config ||
      oldWidget.hinge != hinge ||
      oldWidget.slots != slots;
}

/// Keeps [child]'s state when a layout change moves it somewhere else in
/// the tree, for example from a single-pane layout into a split.
///
/// Give the same [id] wherever the widget appears. Only one [DuoSlot] with
/// a given id may be built at a time.
///
/// ```dart
/// final player = DuoSlot(id: 'player', child: VideoPlayer(controller));
/// return info.isOpen
///     ? Row(children: [Expanded(child: player), const Comments()])
///     : Column(children: [player, const Expanded(child: Comments())]);
/// ```
class DuoSlot extends StatelessWidget {
  /// Creates a slot. Works without `DuoAdapt`, using a registry shared by
  /// the whole app.
  const DuoSlot({super.key, required this.id, required this.child});

  /// Stable identity of this slot.
  final Object id;

  /// Subtree whose state is kept.
  final Widget child;

  static final DuoSlotRegistry _fallback = DuoSlotRegistry();

  @override
  Widget build(BuildContext context) {
    final registry = DuoScope.maybeOf(context)?.slots ?? _fallback;
    return KeyedSubtree(key: registry.keyFor(id), child: child);
  }
}
