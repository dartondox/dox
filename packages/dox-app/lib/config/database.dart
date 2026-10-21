import 'package:dox_app/config/env.dart';
import 'package:dox_orm/dox_orm.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  /// -------------------------------
  /// Connection
  /// -------------------------------
  /// The primary connection for making database queries across the application
  /// You can use any key from the `connections` Map defined in this same
  /// file.
  connection: env.dbConnection,

  connections: <String, ConnectionConfig>{
    /// -------------------------------
    /// Postgres config
    /// -------------------------------
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: env.dbHost,
      port: env.dbPort ?? 5432,
      user: env.dbUsername ?? 'postgres',
      password: env.dbPassword ?? 'postgres',
      database: env.dbName ?? 'dox',
      extra: <String, dynamic>{
        'maxConnectionCount': 10,
        'maxConnectionAge': Duration(hours: 1),
      },
      debug: true,
      printer: ConsoleQueryPrinter(),
    ),

    /// -------------------------------
    /// Mysql config
    /// -------------------------------
    'mysql': ConnectionConfig(
      driver: Driver.mysql,
      host: env.dbHost,
      port: env.dbPort ?? 3306,
      user: env.dbUsername ?? 'root',
      password: env.dbPassword ?? 'password',
      database: env.dbName ?? 'dox',
      extra: <String, dynamic>{'collation': 'utf8mb4_general_ci'},
      debug: true,
      printer: ConsoleQueryPrinter(),
    ),

    /// -------------------------------
    /// SQLite config
    /// -------------------------------
    /// `database` is a file path or `:memory:`.
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName ?? 'dox.sqlite',
      debug: true,
      printer: ConsoleQueryPrinter(),
    ),
  },
);
