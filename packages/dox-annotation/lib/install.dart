/// `Installer`, the steps of a `<package>:install` command.
///
/// `dox add <package>` adds the package, then runs its `<package>:install`
/// command. That command uses [Installer] to write the config files, add
/// the `.env` keys and run build_runner, without overwriting anything.
/// See the "Package commands" docs page.
library;

export 'src/console/installer.dart';
