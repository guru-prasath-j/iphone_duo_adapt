/// Pure-Dart audit that flags code likely to break on iPhone Duo.
///
/// Used by `dart run iphone_duo_adapt:duo_audit`; import it to run the checks
/// from your own tooling.
library;

export 'src/audit/auditor.dart';
