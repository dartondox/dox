import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:dox_query_builder/src/drivers/mysql_driver.dart';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;

class SqlQueryBuilder {
  static final SqlQueryBuilder _singleton = SqlQueryBuilder._internal();

  factory SqlQueryBuilder() {
    return _singleton;
  }

  SqlQueryBuilder._internal();

  late DBDriver dbDriver;

  bool debug = true;

  QueryPrinter printer = PrettyQueryPrinter();

  /// initialize with DatabaseConfig class
  static Future<void> initializeWithDatabaseConfig(
    DatabaseConfig config,
  ) async {
    DatabaseConnection? databaseConnection =
        config.connections[config.connection];

    if (databaseConnection == null) {
      throw Exception('${config.connection} not found');
    }

    dynamic conn = databaseConnection.driver == Driver.mysql
        ? await _getMysqlConnection(databaseConnection)
        : await _getPostgresConnection(databaseConnection);

    initialize(
      database: conn,
      debug: databaseConnection.debug,
      driver: databaseConnection.driver,
      printer: databaseConnection.printer,
    );
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

    /// checking validation for postgres connection
    if (driver == Driver.postgres) {
      if (database is! postgres.Connection) {
        throw Exception(
            'Invalid database connection. It must be postgres `Connection` type');
      }
      sql.dbDriver = PostgresDriver(conn: database);
    }

    /// checking validation for mysql connection
    else if (driver == Driver.mysql) {
      if (database is! mysql.MySqlConnection) {
        throw Exception(
            'Invalid database connection. It must be `MySqlConnection` type');
      }
      sql.dbDriver = MysqlDriver(conn: database);
    }

    /// throw error if driver is not from the supported list
    else {
      throw Exception('Invalid driver or not supported');
    }

    sql.debug = debug;
    // coverage:ignore-start
    if (printer != null) {
      sql.printer = printer;
    }
    // coverage:ignore-end
  }

  /// get mysql connection
  static Future<mysql.MySqlConnection> _getMysqlConnection(
    DatabaseConnection databaseConnection,
  ) {
    SharedConnection connection = databaseConnection.connection;
    Map<String, dynamic> extra = connection.extra;

    return mysql.MySqlConnection.connect(
      mysql.ConnectionSettings(
        host: connection.host,
        port: connection.port,
        user: connection.user,
        password: connection.password,
        db: connection.database,
        useSSL: connection.useSSL,
        useCompression: extra['useCompression'] ?? false,
        maxPacketSize: extra['maxPacketSize'] ?? 16 * 1024 * 1024,
        timeout: extra['timeout'] ?? const Duration(seconds: 30),
        characterSet: extra['characterSet'] ?? mysql.CharacterSet.UTF8MB4,
      ),
      isUnixSocket: extra['isUnixSocket'] ?? false,
    );
  }

  /// get mysql connection
  static Future<postgres.Connection> _getPostgresConnection(
    DatabaseConnection databaseConnection,
  ) {
    SharedConnection connection = databaseConnection.connection;
    Map<String, dynamic> extra = connection.extra;

    postgres.SslMode sslMode =
        connection.useSSL ? postgres.SslMode.require : postgres.SslMode.disable;

    return postgres.Connection.open(
      postgres.Endpoint(
        host: connection.host,
        port: connection.port,
        username: connection.user,
        password: connection.password,
        database: connection.database,
      ),
      settings: postgres.PoolSettings(
        sslMode: extra['sslMode'] ?? sslMode,
        maxConnectionCount: extra['maxConnectionCount'],
        maxConnectionAge: extra['maxConnectionAge'],
        maxSessionUse: extra['maxSessionUse'],
        maxQueryCount: extra['maxQueryCount'],
        applicationName: extra['applicationName'],
        connectTimeout: extra['connectTimeout'],
        encoding: extra['encoding'],
        timeZone: extra['timeZone'],
        replicationMode: extra['replicationMode'],
        transformer: extra['transformer'],
        queryTimeout: extra['queryTimeout'],
        queryMode: extra['queryMode'],
        ignoreSuperfluousParameters: extra['ignoreSuperfluousParameters'],
      ),
    );
  }
}
