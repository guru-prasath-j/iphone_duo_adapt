/// Retrofit existing Flutter UIs for iPhone Duo and other foldables.
///
/// Start with [DuoAdapt] in your app's `builder`, wrap scaffolds in
/// [DuoAdaptiveScaffold], and use [DuoListDetail] / [DuoSplit] where a
/// two-pane layout makes sense. Run `dart run iphone_duo_adapt:duo_audit` to find
/// code that needs attention.
library;

export 'src/device_spec.dart';
export 'src/duo_adapt_widget.dart';
export 'src/layout_info.dart';
export 'src/list_detail.dart';
export 'src/preview.dart';
export 'src/scaffold.dart';
export 'src/split.dart';
