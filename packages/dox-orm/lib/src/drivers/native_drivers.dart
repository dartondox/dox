import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';

/// Checks that the native (Rust) library of Postgres or MySQL loads.
/// Dox has no other driver for them, so it stops with a clear error when
/// the library is missing.
class NativeDrivers {
  /// Why the native library of [driver] does not load, or null when it
  /// loads. Tests set it to act like a missing library.
  static String? Function(Driver driver) loadError = _loadError;

  /// Throws an [UnsupportedError] that says why the native library of
  /// [driver] did not load and how to fix it. SQLite needs no native
  /// library of Dox, so it never throws for it.
  static void ensureAvailable(Driver driver) {
    if (driver == Driver.sqlite) return;
    String? error = loadError(driver);
    if (error == null) return;
    String name = 'dox_${driver.name}_native';
    throw UnsupportedError(
      '$name did not load: $error.\n'
      'Dox needs it to talk to ${driver == Driver.postgres ? 'Postgres' : 'MySQL'}. '
      'Fix: run the app with `dart run` or `dart build cli`. The build hook '
      'then downloads the ready library for this platform, or builds it '
      'from source when Rust is installed (cargo, see https://rustup.rs). '
      'When you set `lib_path` for $name in pubspec.yaml, check that the '
      'file is there and is built for this platform.',
    );
  }

  static String? _loadError(Driver driver) => switch (driver) {
    Driver.postgres => PgNativePool.loadError,
    Driver.mysql => MysqlNativePool.loadError,
    Driver.sqlite => null,
  };
}
