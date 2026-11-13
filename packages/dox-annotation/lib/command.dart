/// Add your own `dox` commands, in a package or in the app.
///
/// Name a library in the `dox: commands:` key of pubspec.yaml. That
/// library has a top-level `commands` list. The `dox` CLI finds it.
/// See the "Package commands" docs page.
library;

export 'src/console/command.dart';
export 'src/console/migration_file.dart';
