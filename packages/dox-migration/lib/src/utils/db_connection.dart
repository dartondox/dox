import 'package:dox_orm/dox_orm.dart';
import 'package:mysql_dart/mysql_dart.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Wraps a postgres `Connection`/`Pool`, a mysql
/// `MySQLConnection`/`MySQLConnectionPool` or a sqlite `Database`, so
/// migration code can run the same query on all drivers.
/// Use `?` for values in queries.
class DbConnection {
  /// postgres `Connection`/`Pool`, mysql `MySQLConnection`/
  /// `MySQLConnectionPool` or sqlite `Database`
  final dynamic conn;

  DbConnection(this.conn);

  bool get isMysql =>
      conn is mysql.MySQLConnection || conn is mysql.MySQLConnectionPool;

  bool get isSqlite => conn is sqlite.Database;

  /// The database config from [env].
  ///
  /// `DATABASE_URL` wins when it is set (see `ConnectionConfig.fromUrl`).
  /// Else `DB_CONNECTION` (postgres, mysql or sqlite), `DB_HOST`,
  /// `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_DATABASE` (or
  /// `DB_NAME`). For sqlite, the database is the file path. A host that
  /// starts with `/` is a Unix socket: the socket folder for Postgres, the
  /// socket file for MySQL.
  static ConnectionConfig config(Map<String, String> env) {
    String? url = env['DATABASE_URL']?.trim();
    if (url != null && url.isNotEmpty) {
      return ConnectionConfig.fromUrl(url);
    }
    String database = env['DB_DATABASE'] ?? env['DB_NAME'] ?? 'dox';
    Driver driver = switch (env['DB_CONNECTION']) {
      'sqlite' => Driver.sqlite,
      'mysql' => Driver.mysql,
      _ => Driver.postgres,
    };
    bool isMysql = driver == Driver.mysql;
    return ConnectionConfig(
      driver: driver,
      host: env['DB_HOST'] ?? 'localhost',
      port: int.parse(env['DB_PORT'] ?? (isMysql ? '3306' : '5432')),
      user: env['DB_USERNAME'] ?? (isMysql ? 'root' : 'postgres'),
      password: env['DB_PASSWORD'] ?? (isMysql ? '' : 'postgres'),
      database: database,
      debug: false,
    );
  }

  /// open one connection with the config from [env], see [config]
  static Future<DbConnection> open(Map<String, String> env) async {
    ConnectionConfig c = config(env);

    if (c.driver == Driver.sqlite) {
      sqlite.Database db = c.database == ':memory:'
          ? sqlite.sqlite3.openInMemory()
          : sqlite.sqlite3.open(c.database);
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA foreign_keys = ON');
      return DbConnection(db);
    }

    if (c.driver == Driver.mysql) {
      // caching_sha2_password (mysql 8 default) without TLS needs the
      // server RSA key to send the password. see
      // ConnectionConfig.mysqlAllowPublicKeyRetrieval for when we ask the
      // server for it.
      mysql.MySQLConnection conn = await mysql.MySQLConnection.createConnection(
        host: c.mysqlHost,
        port: c.mysqlPort,
        userName: c.user,
        password: c.password,
        databaseName: c.database,
        secure: c.useSSL,
        onBadCertificate: c.mysqlAcceptBadCertificate,
        allowPublicKeyRetrieval: c.mysqlAllowPublicKeyRetrieval,
        serverPublicKey: c.extra['serverPublicKey'],
      );
      await conn.connect();
      return DbConnection(conn);
    }

    return DbConnection(
      await postgres.Connection.open(
        c.postgresEndpoint,
        settings: postgres.ConnectionSettings(sslMode: c.postgresSslMode),
      ),
    );
  }

  /// run query and return rows as list of column maps
  Future<List<Map<String, dynamic>>> execute(
    String query, [
    List<Object?> values = const <Object?>[],
  ]) async {
    if (conn is sqlite.Database) {
      sqlite.ResultSet result = (conn as sqlite.Database).select(query, values);
      return <Map<String, dynamic>>[
        for (sqlite.Row row in result) Map<String, dynamic>.of(row),
      ];
    }

    if (isMysql) {
      // no values: plain text query, so `?` in migration sql is kept
      Object? params = values.isEmpty ? null : values;
      mysql.IResultSet result = conn is mysql.MySQLConnectionPool
          ? await conn.withConnection(
              (mysql.MySQLConnection c) => c.execute(query, params),
            )
          : await conn.execute(query, params);
      return <Map<String, dynamic>>[
        for (mysql.ResultSetRow row in result.rows) row.typedAssoc(),
      ];
    }

    // plain string when there are no values,
    // so `@` or `?` inside migration sql is not read as a variable.
    postgres.Result result = values.isEmpty
        ? await conn.execute(query)
        : await conn.execute(
            postgres.Sql.indexed(query, substitution: '?'),
            parameters: values,
          );
    return result.map((postgres.ResultRow row) => row.toColumnMap()).toList();
  }

  /// run [callback] in one transaction on one connection (a pool gives one
  /// of its connections). commit when it ends, rollback when it throws.
  Future<T> transaction<T>(Future<T> Function(DbConnection tx) callback) async {
    if (conn is sqlite.Database) {
      sqlite.Database db = conn;
      db.execute('BEGIN');
      try {
        T result = await callback(this);
        db.execute('COMMIT');
        return result;
      } catch (error) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (conn is mysql.MySQLConnectionPool) {
      return await conn.withConnection(
        (mysql.MySQLConnection c) => c.transactional(
          (mysql.MySQLConnection tx) => callback(DbConnection(tx)),
        ),
      );
    }
    if (conn is mysql.MySQLConnection) {
      return await conn.transactional(
        (mysql.MySQLConnection tx) => callback(DbConnection(tx)),
      );
    }
    return await conn.runTx(
      (postgres.TxSession tx) => callback(DbConnection(tx)),
    );
  }

  Future<void> close() async {
    if (conn is sqlite.Database) {
      (conn as sqlite.Database).close();
      return;
    }
    await conn.close();
  }
}
