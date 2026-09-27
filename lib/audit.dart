/// Pure-Dart audit that flags code and project settings likely to break on
/// iPhone Duo and other foldables.
///
/// Used by `dart run iphone_duo_adapt:duo_audit`; import it to run the
/// checks from your own tooling or an AI agent.
library;

export 'src/audit/auditor.dart';
