import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/src/drivers/sqlite_driver.dart';
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

  /// use TLS.
  /// - mysql: the server certificate is checked. set
  ///   `extra['verifyCertificate']` to false to skip the check, eg. for a
  ///   self-signed certificate in development.
  /// - postgres: TLS mode `require` (encrypt, no certificate check, like
  ///   libpq). set `extra['sslMode']` to `verify-full` to also check the
  ///   certificate. see [postgresSslMode].
  bool useSSL;

  /// extra configuration for the connection
  /// eg. `maxConnectionCount` for postgres and mysql,
  /// `sslMode` for postgres, `busyTimeout` for sqlite.
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
  /// - `sslmode` (or `ssl`): `disable`, `false` and `0` mean no TLS.
  ///   `allow` and `prefer` use TLS only when the server has it (Postgres)
  ///   and set no [useSSL]. Any other value (eg. `require`, `true`) turns
  ///   TLS on. For Postgres, `require` does not check the certificate (like
  ///   libpq), `verify-ca` and `verify-full` check it. For MySQL the
  ///   certificate is checked, add `verifyCertificate=false` to skip the
  ///   check (eg. a self-signed certificate in development).
  /// - `sslrootcert=/path/ca.pem` (Postgres): the CA certificates to trust
  ///   for `verify-full`. See [postgresSslRootCert].
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
          String mode = switch (value.toLowerCase()) {
            'disable' || 'disabled' || 'false' || '0' => 'disable',
            'allow' || 'prefer' || 'preferred' => 'prefer',
            'verify-ca' => 'verify-ca',
            String m when m.startsWith('verify') => 'verify-full',
            _ => 'require',
          };
          useSSL = mode == 'require' || mode.startsWith('verify');
          // like libpq: `require` encrypts but does not check the
          // certificate (eg. Heroku). `verify-ca` and `verify-full`
          // check it.
          if (driver == Driver.postgres) options['sslMode'] = mode;
        case 'sslrootcert' when driver == Driver.postgres:
          options['sslRootCert'] = value;
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

  /// false when `extra['verifyCertificate']` is false: MySQL TLS does
  /// not check the server certificate. only use it for a self-signed
  /// certificate in development. default true.
  bool get verifyCertificate => extra['verifyCertificate'] as bool? ?? true;

  /// the Postgres TLS mode: `disable`, `prefer`, `require`, `verify-ca`
  /// (checks the certificate, not the host name) or `verify-full`. it is `extra['sslMode']` when set, else `require`
  /// with [useSSL], else `disable`.
  String get postgresSslMode =>
      extra['sslMode'] as String? ?? (useSSL ? 'require' : 'disable');

  /// the path of a PEM file with the CA certificates that Postgres TLS
  /// trusts for `verify-ca` and `verify-full`, eg. the CA of a cloud database. it is
  /// `extra['sslRootCert']` (`sslrootcert` in a url). when it is not set,
  /// the system certificates are used.
  String? get postgresSslRootCert => extra['sslRootCert'] as String?;

  /// max prepared statements kept per connection (default 100).
  /// set it with `extra['preparedStatementCacheSize']`.
  int get statementCacheSize =>
      extra['preparedStatementCacheSize'] as int? ?? defaultStatementCacheSize;

  /// make the driver of this connection: [driverFactory] when it is set,
  /// else the native driver for postgres and mysql, else the sqlite
  /// driver. postgres and mysql throw an [UnsupportedError] when their
  /// native library does not load (see [NativeDrivers.ensureAvailable]).
  DBDriver createDriver() {
    if (driverFactory != null) {
      return driverFactory!(this);
    }
    return switch (driver) {
      Driver.postgres => PostgresNativeDriver.fromConfig(this),
      Driver.mysql => MysqlNativeDriver.fromConfig(this),
      Driver.sqlite => SqliteDriver(
        conn: _openSqlite(),
        statementCacheSize: statementCacheSize,
      ),
    };
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
}
