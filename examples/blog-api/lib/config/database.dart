import 'package:blog/config/app.dart';
import 'package:blog/config/env.dart';
import 'package:dox_orm/dox_orm.dart';

/// Print every SQL query only in development.
/// Printing each query costs time, so it is off in production.
bool _debug = appConfig.isDevelopment;

DatabaseConfig databaseConfig = DatabaseConfig(
  /// Database url
  /// -------------------------------
  /// `DATABASE_URL` from `.env` or the environment, the same one that
  /// `dox migrate` reads. When it is set, it wins over the DB_* keys.
  url: env.databaseUrl,

  /// Connection
  /// -------------------------------
  /// The connection to use. It is one key of `connections` below.
  connection: env.dbConnection,

  connections: <String, ConnectionConfig>{
    /// Postgres
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: env.dbHost,
      port: env.dbPort ?? 5432,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{
        /// Each isolate has its own pool.
        'maxConnectionCount': 10,
        'maxConnectionAge': Duration(hours: 1),
      },
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),

    /// MySQL and MariaDB
    'mysql': ConnectionConfig(
      driver: Driver.mysql,
      host: env.dbHost,
      port: env.dbPort ?? 3306,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      extra: <String, dynamic>{'collation': 'utf8mb4_general_ci'},
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),

    /// SQLite. `DB_NAME` is a file path, or `:memory:`.
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName,
      debug: _debug,
      printer: PrettyQueryPrinter(),
    ),
  },
);
