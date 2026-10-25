import 'package:dox_orm/dox_orm.dart';

/// one driver per connection name, so each name keeps its own pool and
/// its own statement caches
Map<String, DBDriver> _globalDrivers = <String, DBDriver>{};

class SqlQueryBuilder {
  static final SqlQueryBuilder _singleton = SqlQueryBuilder._internal();

  factory SqlQueryBuilder() {
    return _singleton;
  }

  SqlQueryBuilder._internal();

  DBDriver? _dbDriver;

  /// the driver of the default connection
  DBDriver get dbDriver {
    DBDriver? driver = _dbDriver;
    if (driver == null) {
      throw StateError(
        'The ORM is not set up. Call SqlQueryBuilder.initialize first.',
      );
    }
    return driver;
  }

  set dbDriver(DBDriver driver) => _dbDriver = driver;

  bool debug = true;

  QueryPrinter printer = PrettyQueryPrinter();

  DatabaseConfig? databaseConfig;

  /// initialize with DatabaseConfig class.
  /// postgres and mysql throw an [UnsupportedError] when their native
  /// library does not load.
  static void initializeWithDatabaseConfig(DatabaseConfig config) {
    SqlQueryBuilder sql = SqlQueryBuilder();
    sql.databaseConfig = config;
    ConnectionConfig connConfig = config.getConnectionConfig();

    sql.dbDriver = connConfig.createDriver();
    sql.debug = connConfig.debug;
    if (connConfig.printer != null) {
      sql.printer = connConfig.printer!;
    }
  }

  /// Get database driver with connection name
  DBDriver getDBDriver([String? connection]) {
    if (connection == null || databaseConfig == null) {
      return dbDriver;
    }
    DBDriver? driver = _globalDrivers[connection];
    if (driver != null) {
      return driver;
    }
    ConnectionConfig connConfig = databaseConfig!.getConnectionConfig(
      connection,
    );
    return _globalDrivers[connection] = connConfig.createDriver();
  }

  /// Close every open database connection of this isolate: the default
  /// connection and all named connections. Running queries finish first.
  /// It is safe to call it twice. Call `initialize` again to use the
  /// database after it.
  /// ```
  /// await SqlQueryBuilder.close();
  /// ```
  static Future<void> close() async {
    SqlQueryBuilder sql = SqlQueryBuilder();
    Set<DBDriver> drivers = <DBDriver>{
      ?sql._dbDriver,
      ..._globalDrivers.values,
    };
    sql._dbDriver = null;
    _globalDrivers.clear();
    for (DBDriver driver in drivers) {
      await driver.close();
    }
  }

  /// initialize query builder with your own [database]: a `PgNativePool`
  /// for postgres, a `MysqlNativePool` for mysql or a sqlite `Database`.
  /// ```
  ///  SqlQueryBuilder.initialize(
  ///   database: db,
  ///   driver: Driver.sqlite,
  ///   debug: true,
  /// );
  /// ```
  static void initialize({
    required dynamic database,
    bool debug = false,
    QueryPrinter? printer,
    Driver driver = Driver.postgres,
  }) {
    SqlQueryBuilder sql = SqlQueryBuilder();

    sql.dbDriver = getDatabaseDriver(driver, database);
    sql.debug = debug;

    // coverage:ignore-start
    if (printer != null) {
      sql.printer = printer;
    }
    // coverage:ignore-end
  }
}
