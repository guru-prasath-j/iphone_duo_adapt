/// Make an existing Flutter app iPhone Duo ready.
///
/// Start with [DuoAdapt] in your app's `builder`, wrap scaffolds in
/// [DuoAdaptiveScaffold] (or swap `CupertinoTabScaffold` for
/// [DuoCupertinoTabScaffold]), and use [DuoListDetail], [DuoSplit],
/// [DuoArrangement] and [DuoFoldAvoid] where layouts need them. Every
/// setting lives in [DuoAdaptConfig].
///
/// Tools: `dart run flutter_iphone_duo_adapt:duo_audit` finds code that breaks on
/// foldables; `dart run flutter_iphone_duo_adapt:duo_migrate` applies the retrofit.
/// Tests: `package:flutter_iphone_duo_adapt/testing.dart`.
library;

export 'src/arrangement.dart';
export 'src/config.dart';
export 'src/cupertino_scaffold.dart';
export 'src/device_spec.dart';
export 'src/duo_adapt_widget.dart';
export 'src/hinge.dart';
export 'src/layout_builders.dart';
export 'src/layout_info.dart';
export 'src/list_detail.dart';
export 'src/native_bridge.dart';
export 'src/preview.dart';
export 'src/scaffold.dart';
export 'src/scope.dart';
export 'src/split.dart';
