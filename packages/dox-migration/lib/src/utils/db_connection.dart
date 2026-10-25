import 'package:dox_orm/dox_orm.dart';

/// Runs migration queries on a dox_orm [DBDriver]: the native Postgres or
/// MySQL driver, or the sqlite driver. Use `@name` for values in queries.
class DbConnection {
  final DBDriver driver;

  DbConnection(this.driver);

  bool get isMysql => driver.getName() == Driver.mysql;

  bool get isSqlite => driver.getName() == Driver.sqlite;

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

  /// open a driver with the config from [env], see [config].
  /// Postgres and MySQL throw an [UnsupportedError] when their native
  /// library does not load.
  static Future<DbConnection> open(Map<String, String> env) async {
    return DbConnection(config(env).createDriver());
  }

  /// run query and return rows as list of column maps
  Future<List<Map<String, dynamic>>> execute(
    String query, [
    Map<String, dynamic>? values,
  ]) {
    return driver.query(query, substitutionValues: values);
  }

  /// run [callback] in one transaction on one connection. commit when it
  /// ends, rollback when it throws. queries of [driver] inside [callback]
  /// use the transaction.
  Future<T> transaction<T>(Future<T> Function() callback) {
    return driver.transaction(callback);
  }

  Future<void> close() => driver.close();
}
