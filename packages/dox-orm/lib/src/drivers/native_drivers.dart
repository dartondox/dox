import 'dart:io';

import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';

/// Picks the default driver for Postgres and MySQL: the native (Rust)
/// driver. It uses the Dart driver when:
/// - `DOX_DB_DRIVER=dart` is set, or `extra['native']` is `false`.
/// - Postgres needs TLS (`useSSL` or `extra['sslMode']`). The native
///   Postgres driver has no TLS yet.
/// - The native library does not load. Then it prints one warning.
class NativeDrivers {
  /// Why the native library of [driver] does not load, or null when it
  /// loads. Tests set it to act like a missing library.
  static String? Function(Driver driver) loadError = _loadError;

  /// where the warning goes. Tests read it.
  static StringSink warnings = stderr;

  /// the drivers that printed the warning already
  static final Set<Driver> _warned = <Driver>{};

  /// The native driver for [config], or null to use the Dart driver.
  static DBDriver? create(ConnectionConfig config) {
    Driver driver = config.driver;
    if (driver == Driver.sqlite || !wanted(config)) return null;
    if (driver == Driver.postgres &&
        (config.useSSL || config.extra['sslMode'] != null)) {
      return null;
    }
    String? error = loadError(driver);
    if (error != null) {
      if (_warned.add(driver)) {
        warnings.writeln(
          '[dox] warning: dox_${driver.name}_native did not load, using the '
          'Dart ${driver.name} driver ($error)',
        );
      }
      return null;
    }
    return driver == Driver.postgres
        ? PostgresNativeDriver.fromConfig(config)
        : MysqlNativeDriver.fromConfig(config);
  }

  /// false when the user asks for the Dart driver
  static bool wanted(ConnectionConfig config) {
    if (config.extra['native'] == false) return false;
    return Platform.environment['DOX_DB_DRIVER']?.toLowerCase() != 'dart';
  }

  static String? _loadError(Driver driver) => driver == Driver.postgres
      ? PgNativePool.loadError
      : MysqlNativePool.loadError;
}
