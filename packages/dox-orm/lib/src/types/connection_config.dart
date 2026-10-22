import 'package:dox_orm/dox_orm.dart';
import 'package:mysql_dart/mysql_dart.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;
import 'package:sqlite3/sqlite3.dart' as sqlite;

class ConnectionConfig {
  /// Database driver
  /// Driver.postgres, Driver.mysql (also mariadb) or Driver.sqlite
  Driver driver;

  /// Enable debugging mode
  bool debug;

  /// Query printer to use when debugging mode is no.
  /// support build-in `PrettyQueryPrinter()` and `ConsoleQueryPrinter()`
  /// and `FileQueryPrinter()`.
  /// You can also create your own custom query printer by implementing
  /// `QueryPrinter` interface
  QueryPrinter? printer;

  /// database host
  String host;

  /// database username
  String user;

  /// database password
  String password;

  /// database name.
  /// for sqlite it is the file path, or `:memory:`
  String database;

  /// database connection port
  int port;

  /// use ssl mode
  bool useSSL;

  /// extra configuration for the connection
  /// eg. `maxConnectionCount` for postgres and mysql,
  /// `busyTimeout` for sqlite
  Map<String, dynamic> extra;

  /// use your own driver class instead of the built-in one, eg. a native
  /// driver package. it gets this config and returns the driver.
  /// [driver] is still used to pick the sql dialect.
  ///
  /// ```
  /// driverFactory: PostgresNativeDriver.fromConfig,
  /// ```
  DBDriver Function(ConnectionConfig config)? driverFactory;

  /// [user], [password] and [port] are not used by sqlite
  ConnectionConfig({
    required this.driver,
    this.host = 'localhost',
    this.useSSL = false,
    this.user = '',
    this.password = '',
    required this.database,
    this.port = 0,
    this.extra = const <String, dynamic>{},
    required this.debug,
    this.printer,
    this.driverFactory,
  });

  /// max prepared statements kept per connection (default 100).
  /// set it with `extra['preparedStatementCacheSize']`.
  int get statementCacheSize =>
      extra['preparedStatementCacheSize'] as int? ?? defaultStatementCacheSize;

  /// make the driver of this connection: [driverFactory] when it is set,
  /// else the built-in driver for [driver]
  DBDriver createDriver() {
    if (driverFactory != null) {
      return driverFactory!(this);
    }
    return getDatabaseDriver(
      driver,
      getDatabaseConnection(),
      statementCacheSize: statementCacheSize,
    );
  }

  /// get database connection: postgres `Pool`, mysql `MySQLConnectionPool`
  /// or sqlite `Database`
  Future<dynamic> getDatabaseConnection() {
    if (driver == Driver.mysql) {
      return Future<dynamic>.value(_getMysqlPool());
    }
    if (driver == Driver.sqlite) {
      return Future<dynamic>.value(_openSqlite());
    }
    return _getPostgresConnection();
  }

  /// get mysql connection pool.
  /// it opens up to `maxConnectionCount` connections (default 10) when
  /// needed. caching_sha2_password (mysql 8 default) works without TLS:
  /// the password is encrypted with the server RSA key. it asks the server
  /// for the key, unless you give it in `serverPublicKey` (safer).
  mysql.MySQLConnectionPool _getMysqlPool() {
    return mysql.MySQLConnectionPool(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: database,
      maxConnections: extra['maxConnectionCount'] ?? 10,
      secure: useSSL,
      collation: extra['collation'] ?? 'utf8mb4_general_ci',
      timeoutMs: extra['timeoutMs'] ?? 10000,
      allowPublicKeyRetrieval: extra['allowPublicKeyRetrieval'] ?? true,
      serverPublicKey: extra['serverPublicKey'],
      timeZone: extra['timeZone'],
      maxConnectionAge: extra['maxConnectionAge'] ?? const Duration(hours: 12),
      autoPreparedStatementCacheCapacity: statementCacheSize,
    );
  }

  /// open sqlite database file (made if missing), or `:memory:`.
  /// - WAL: readers do not wait for the writer, faster writes.
  /// - busy_timeout: wait for a lock (eg. another isolate writing)
  ///   instead of failing right away.
  /// - foreign_keys: sqlite turns them off by default.
  sqlite.Database _openSqlite() {
    sqlite.Database db = database == ':memory:'
        ? sqlite.sqlite3.openInMemory()
        : sqlite.sqlite3.open(database);
    // busy_timeout first: switching to WAL needs a lock, and many isolates
    // open the file at the same time on start.
    db.execute('PRAGMA busy_timeout = ${extra['busyTimeout'] as int? ?? 5000}');
    if (database != ':memory:') {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    }
    db.execute('PRAGMA foreign_keys = ON');
    return db;
  }

  /// get postgres connection pool.
  /// it opens up to `maxConnectionCount` connections when needed.
  Future<postgres.Pool<dynamic>> _getPostgresConnection() async {
    postgres.SslMode sslMode = useSSL
        ? postgres.SslMode.require
        : postgres.SslMode.disable;

    return postgres.Pool<dynamic>.withEndpoints(
      <postgres.Endpoint>[
        postgres.Endpoint(
          host: host,
          port: port,
          username: user,
          password: password,
          database: database,
        ),
      ],
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
