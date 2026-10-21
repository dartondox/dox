import 'package:mysql1/mysql1.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;

/// Wraps a postgres `Connection` or a mysql `MySqlConnection`,
/// so migration code can run the same query on both drivers.
/// Use `?` for values in queries.
class DbConnection {
  /// postgres `Connection` or mysql `MySqlConnection`
  final dynamic conn;

  DbConnection(this.conn);

  bool get isMysql => conn is mysql.MySqlConnection;

  /// open connection using `DB_CONNECTION` (postgres or mysql) from env
  static Future<DbConnection> open(Map<String, String> env) async {
    String host = env['DB_HOST'] ?? 'localhost';
    String database = env['DB_NAME'] ?? 'dox';

    if (env['DB_CONNECTION'] == 'mysql') {
      mysql.MySqlConnection conn = await mysql.MySqlConnection.connect(
        mysql.ConnectionSettings(
          host: host,
          port: int.parse(env['DB_PORT'] ?? '3306'),
          db: database,
          user: env['DB_USERNAME'] ?? 'root',
          password: env['DB_PASSWORD'],
        ),
      );
      // mysql1 returns before MySQL 8 auth is done, and the first
      // queries then read wrong results. Wait a little before using it.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return DbConnection(conn);
    }

    return DbConnection(await postgres.Connection.open(
      postgres.Endpoint(
        host: host,
        port: int.parse(env['DB_PORT'] ?? '5432'),
        database: database,
        username: env['DB_USERNAME'] ?? 'postgres',
        password: env['DB_PASSWORD'] ?? 'postgres',
      ),
      settings: postgres.ConnectionSettings(sslMode: postgres.SslMode.disable),
    ));
  }

  /// run query and return rows as list of column maps
  Future<List<Map<String, dynamic>>> execute(String query,
      [List<Object?> values = const <Object?>[]]) async {
    if (conn is mysql.MySqlConnection) {
      mysql.Results result = await conn.query(query, values);
      return result.map((mysql.ResultRow row) => row.fields).toList();
    }

    // plain string when there are no values,
    // so `@` or `?` inside migration sql is not read as a variable.
    postgres.Result result = values.isEmpty
        ? await conn.execute(query)
        : await conn.execute(postgres.Sql.indexed(query, substitution: '?'),
            parameters: values);
    return result.map((postgres.ResultRow row) => row.toColumnMap()).toList();
  }

  Future<void> close() async {
    await conn.close();
  }
}
