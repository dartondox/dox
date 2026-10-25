import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';

/// a custom driver: it runs the queries with the built-in driver and
/// counts them
class CountingDriver extends DBDriver {
  final DBDriver inner;
  final String name;
  int queries = 0;

  CountingDriver(ConnectionConfig config, this.name)
    : inner = ConnectionConfig(
        driver: config.driver,
        host: config.host,
        port: config.port,
        user: config.user,
        password: config.password,
        database: config.database,
        extra: config.extra,
        debug: false,
      ).createDriver();

  @override
  Driver getName() => inner.getName();

  @override
  bool get supportsReturning => inner.supportsReturning;

  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) {
    queries++;
    return inner.query(
      query,
      primaryKey: primaryKey,
      substitutionValues: substitutionValues,
    );
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) {
    queries++;
    return inner.execute(query, substitutionValues: substitutionValues);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() callback) {
    return inner.transaction(callback);
  }
}

List<CountingDriver> made = <CountingDriver>[];

DBDriver makeDriver(ConnectionConfig config) {
  CountingDriver driver = CountingDriver(config, config.database);
  made.add(driver);
  return driver;
}

void main() {
  ConnectionConfig base = databaseConfig.getConnectionConfig();

  ConnectionConfig withFactory() {
    return ConnectionConfig(
      driver: base.driver,
      host: base.host,
      port: base.port,
      user: base.user,
      password: base.password,
      database: base.database,
      extra: base.extra,
      debug: false,
      driverFactory: makeDriver,
    );
  }

  test('driverFactory is used by the default and named connections', () async {
    SqlQueryBuilder.initializeWithDatabaseConfig(
      DatabaseConfig(
        connection: 'main',
        connections: <String, ConnectionConfig>{
          'main': withFactory(),
          'other': withFactory(),
        },
      ),
    );
    expect(made.length, 1);
    expect(SqlQueryBuilder().dbDriver, same(made[0]));

    await QueryBuilder.table('x').rawQuery('SELECT 1 AS one').get();
    expect(made[0].queries, 1);

    /// a named connection makes its driver once, with the same factory
    List<dynamic> rows = await QueryBuilder.table('x')
        .withConnection('other')
        .rawQuery('SELECT 2 AS two')
        .get();
    expect(rows.first['two'], 2);
    await QueryBuilder.table('x')
        .withConnection('other')
        .rawQuery('SELECT 3 AS three')
        .get();
    expect(made.length, 2);
    expect(made[1].queries, 2);
    expect(made[0].queries, 1);
  });
}
