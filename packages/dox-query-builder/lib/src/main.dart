import 'package:dox_query_builder/dox_query_builder.dart';

Map<String, dynamic> _globalConnections = <String, dynamic>{};

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
  static void initializeWithDatabaseConfig(
    DatabaseConfig config,
  ) async {
    SqlQueryBuilder().databaseConfig = config;
    ConnectionConfig connConfig = config.getConnectionConfig();

    initialize(
      database: connConfig.getDatabaseConnection(),
      debug: connConfig.debug,
      driver: connConfig.driver,
      printer: connConfig.printer,
    );
  }

  /// Get database driver with connection name
  DBDriver getDBDriver([String? connection]) {
    if (connection == null || databaseConfig == null) {
      return dbDriver;
    }

    ConnectionConfig? connConfig =
        databaseConfig?.getConnectionConfig(connection);

    if (connConfig != null) {
      dynamic conn = _globalConnections[connection];

      if (conn == null) {
        conn = connConfig.getDatabaseConnection();
        _globalConnections[connection] = conn;
      }

      return getDatabaseDriver(connConfig.driver, conn);
    }
    throw Exception('invalid connection');
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
