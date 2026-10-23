import 'dart:io';

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
  /// `busyTimeout` for sqlite.
  /// `native: false` uses the Dart driver instead of the native one.
  Map<String, dynamic> extra;

  /// use your own driver class instead of the built-in one.
  /// it gets this config and returns the driver. it wins over every other
  /// setting. [driver] is still used to pick the sql dialect.
  ///
  /// ```
  /// driverFactory: MysqlDriverOfMyOwn.fromConfig,
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

  /// Makes a config from a database url, like `DATABASE_URL`.
  ///
  /// - `postgres://user:pass@host:5432/db` (also `postgresql://`)
  /// - `mysql://user:pass@host:3306/db` (also `mariadb://`)
  /// - `sqlite:///abs/path.db`, `sqlite://db/dox.sqlite`, `sqlite::memory:`
  ///   or `file:db/dox.sqlite`
  ///
  /// The user, password and database name are url-decoded. A missing port
  /// is 5432 for Postgres and 3306 for MySQL.
  ///
  /// Query options:
  /// - `host=/path` (or `socket=/path`): a Unix socket. It wins over the
  ///   host part of the url. For Postgres it is the socket folder, eg.
  ///   `/cloudsql/project:region:instance`. For MySQL it is the socket
  ///   file, eg. `/var/run/mysqld/mysqld.sock`.
  /// - `sslmode` (or `ssl`): `disable`, `allow`, `prefer`, `false` and `0`
  ///   mean no TLS. `verify-full` checks the server certificate. Any other
  ///   value (eg. `require`, `true`) turns TLS on.
  /// - any other option goes to [extra]. `10` becomes an int, and `true` or
  ///   `false` a bool. Eg. `?maxConnectionCount=20`.
  ///
  /// [extra] is the base, the url options win over it.
  factory ConnectionConfig.fromUrl(
    String url, {
    bool debug = false,
    QueryPrinter? printer,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    url = url.trim();
    int colon = url.indexOf(':');
    String scheme = colon < 0 ? '' : url.substring(0, colon).toLowerCase();

    if (scheme == 'sqlite' || scheme == 'file') {
      String path = url.substring(colon + 1);
      if (path.startsWith('//')) path = path.substring(2);
      int query = path.indexOf('?');
      if (query >= 0) path = path.substring(0, query);
      return ConnectionConfig(
        driver: Driver.sqlite,
        database: Uri.decodeComponent(path),
        debug: debug,
        printer: printer,
        extra: extra,
      );
    }

    Driver driver = switch (scheme) {
      'postgres' || 'postgresql' => Driver.postgres,
      'mysql' || 'mariadb' => Driver.mysql,
      _ => throw FormatException(
        'database url must start with postgres://, postgresql://, mysql://, '
        'mariadb://, sqlite: or file:',
        scheme,
      ),
    };
    Uri uri = Uri.parse(url);
    Map<String, dynamic> options = <String, dynamic>{...extra};
    String host = Uri.decodeComponent(uri.host);
    bool useSSL = false;
    uri.queryParameters.forEach((String key, String value) {
      switch (key) {
        case 'host' || 'socket':
          host = value;
        case 'sslmode' || 'ssl':
          String mode = value.toLowerCase();
          useSSL = !<String>{
            'disable',
            'disabled',
            'allow',
            'prefer',
            'preferred',
            'false',
            '0',
          }.contains(mode);
          if (driver == Driver.postgres && mode.startsWith('verify')) {
            options['sslMode'] = postgres.SslMode.verifyFull;
          }
        default:
          options[key] = int.tryParse(value) ?? bool.tryParse(value) ?? value;
      }
    });
    List<String> userInfo = uri.userInfo.split(':');
    String path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

    return ConnectionConfig(
      driver: driver,
      host: host.isEmpty ? 'localhost' : host,
      port: uri.hasPort
          ? uri.port
          : driver == Driver.postgres
          ? 5432
          : 3306,
      user: Uri.decodeComponent(userInfo.first),
      password: userInfo.length > 1
          ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
          : '',
      database: Uri.decodeComponent(path),
      useSSL: useSSL,
      debug: debug,
      printer: printer,
      extra: options,
    );
  }

  /// true when [host] is a Unix socket: a path that starts with `/`.
  /// For Postgres it is the folder of the socket, like libpq. For MySQL it
  /// is the socket file. Eg. Google Cloud SQL uses
  /// `/cloudsql/project:region:instance` for both.
  bool get isUnixSocket => host.startsWith('/');

  /// the Postgres server of this config, for the Dart `postgres` package.
  /// A socket folder gets the file name `.s.PGSQL.<port>`, like libpq.
  postgres.Endpoint get postgresEndpoint {
    int pgPort = port == 0 ? 5432 : port;
    String pgHost = host;
    if (isUnixSocket && !pgHost.contains('/.s.PGSQL.')) {
      pgHost = '${pgHost.endsWith('/') ? pgHost : '$pgHost/'}.s.PGSQL.$pgPort';
    }
    return postgres.Endpoint(
      host: pgHost,
      port: pgPort,
      username: user,
      password: password,
      database: database,
      isUnixSocket: isUnixSocket,
    );
  }

  /// the MySQL server address for the Dart `mysql_dart` package: a unix
  /// [InternetAddress] for a socket, else the host name.
  Object get mysqlHost => isUnixSocket
      ? InternetAddress(host, type: InternetAddressType.unix)
      : host;

  /// the MySQL port: 0 for a Unix socket, else [port] (default 3306).
  int get mysqlPort => isUnixSocket
      ? 0
      : port == 0
      ? 3306
      : port;

  /// max prepared statements kept per connection (default 100).
  /// set it with `extra['preparedStatementCacheSize']`.
  int get statementCacheSize =>
      extra['preparedStatementCacheSize'] as int? ?? defaultStatementCacheSize;

  /// make the driver of this connection: [driverFactory] when it is set,
  /// else the native driver for postgres and mysql (see [NativeDrivers]),
  /// else the Dart driver for [driver]
  DBDriver createDriver() {
    if (driverFactory != null) {
      return driverFactory!(this);
    }
    DBDriver? native = NativeDrivers.create(this);
    if (native != null) {
      return native;
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
      host: mysqlHost,
      port: mysqlPort,
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
      <postgres.Endpoint>[postgresEndpoint],
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
