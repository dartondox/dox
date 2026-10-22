import 'dart:io';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';

ConnectionConfig copy(ConnectionConfig c, {Map<String, dynamic>? extra}) {
  return ConnectionConfig(
    driver: c.driver,
    host: c.host,
    port: c.port,
    user: c.user,
    password: c.password,
    database: c.database,
    extra: extra ?? c.extra,
    debug: false,
  );
}

void main() {
  ConnectionConfig base = databaseConfig.getConnectionConfig();
  bool dartForced = Platform.environment['DOX_DB_DRIVER'] == 'dart';
  bool sqlite = base.driver == Driver.sqlite;

  Type nativeType = base.driver == Driver.postgres
      ? PostgresNativeDriver
      : MysqlNativeDriver;

  test('the default driver is native, unless DOX_DB_DRIVER=dart', () {
    DBDriver driver = base.createDriver();
    if (sqlite || dartForced) {
      expect(driver, isNot(isA<PostgresNativeDriver>()));
      expect(driver, isNot(isA<MysqlNativeDriver>()));
    } else {
      expect(driver.runtimeType, nativeType);
    }
  });

  test('named connections use the same default', () {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
    DBDriver named = SqlQueryBuilder().getDBDriver(databaseConfig.connection);
    expect(named.runtimeType, SqlQueryBuilder().dbDriver.runtimeType);
  });

  test("extra['native'] = false uses the Dart driver", () {
    DBDriver driver = copy(
      base,
      extra: <String, dynamic>{...base.extra, 'native': false},
    ).createDriver();
    expect(driver.runtimeType, isNot(nativeType));
  });

  test('a library that does not load falls back to Dart, warns once', () async {
    StringBuffer out = StringBuffer();
    String? Function(Driver) real = NativeDrivers.loadError;
    StringSink realSink = NativeDrivers.warnings;
    NativeDrivers.loadError = (Driver d) => 'no library (test)';
    NativeDrivers.warnings = out;
    addTearDown(() {
      NativeDrivers.loadError = real;
      NativeDrivers.warnings = realSink;
    });

    DBDriver first = copy(base).createDriver();
    DBDriver second = copy(base).createDriver();
    expect(first.runtimeType, isNot(nativeType));
    expect(second.runtimeType, first.runtimeType);
    if (sqlite || dartForced) {
      expect(out.toString(), isEmpty);
      return;
    }
    expect(out.toString().trim().split('\n'), <String>[
      '[dox] warning: dox_${base.driver.name}_native did not load, using '
          'the Dart ${base.driver.name} driver (no library (test))',
    ]);

    /// the Dart driver works
    List<Map<String, dynamic>> rows = await first.query('SELECT 1 AS one');
    expect(rows.first['one'], 1);
  });
}
