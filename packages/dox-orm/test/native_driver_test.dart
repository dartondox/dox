import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';

void main() {
  ConnectionConfig base = databaseConfig.getConnectionConfig();

  test('postgres and mysql use the native driver', () async {
    DBDriver driver = base.createDriver();
    addTearDown(driver.close);
    expect(driver, switch (base.driver) {
      Driver.postgres => isA<PostgresNativeDriver>(),
      Driver.mysql => isA<MysqlNativeDriver>(),
      Driver.sqlite => isNot(isA<PostgresNativeDriver>()),
    });
  });

  test('named connections use the same driver', () {
    SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
    DBDriver named = SqlQueryBuilder().getDBDriver(databaseConfig.connection);
    expect(named.runtimeType, SqlQueryBuilder().dbDriver.runtimeType);
  });

  test('a native library that does not load stops with a clear error', () {
    String? Function(Driver) real = NativeDrivers.loadError;
    NativeDrivers.loadError = (Driver d) => 'no library (test)';
    addTearDown(() => NativeDrivers.loadError = real);

    for (Driver driver in <Driver>[Driver.postgres, Driver.mysql]) {
      ConnectionConfig config = ConnectionConfig(
        driver: driver,
        database: 'app',
        debug: false,
      );
      expect(
        config.createDriver,
        throwsA(
          isA<UnsupportedError>().having(
            (UnsupportedError e) => e.message,
            'message',
            allOf(
              contains('dox_${driver.name}_native did not load'),
              contains('no library (test)'),
              contains('Fix:'),
            ),
          ),
        ),
      );
    }

    /// sqlite needs no native library of Dox
    NativeDrivers.ensureAvailable(Driver.sqlite);
  });
}
