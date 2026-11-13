/// Add your own `dox` commands, in a package or in the app.
///
/// Name a library in the `dox: commands:` key of pubspec.yaml. That
/// library has a top-level `commands` list. The `dox` CLI finds it.
/// See the "Package commands" docs page.
///
/// `Command` and `MigrationFile` live in dox_annotation. A package that
/// does not use dox_core imports `package:dox_annotation/command.dart`.
library;

export 'package:dox_annotation/command.dart';
