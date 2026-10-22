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

  late DBDriver dbDriver;

  bool debug = true;

  QueryPrinter printer = PrettyQueryPrinter();

  DatabaseConfig? databaseConfig;

  /// initialize with DatabaseConfig class
  static void initializeWithDatabaseConfig(DatabaseConfig config) async {
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

  /// initialize query builder
  /// ```
  ///  SqlQueryBuilder.initialize(
  ///   database: db,
  ///   debug: true,
  ///   prettyPrint: true
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
