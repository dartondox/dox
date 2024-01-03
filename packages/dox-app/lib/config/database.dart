import 'package:dox_core/dox_core.dart';
import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart' as mysql;

DatabaseConfig databaseConfig = DatabaseConfig(
  /// -------------------------------
  /// Connection
  /// -------------------------------
  /// The primary connection for making database queries across the application
  /// You can use any key from the `connections` Map defined in this same
  /// file.
  connection: Env.get('DB_CONNECTION', 'postgres'),

  connections: <String, DatabaseConnection>{
    /// -------------------------------
    /// Postgres config
    /// -------------------------------
    'postgres': DatabaseConnection(
      driver: Driver.postgres,
      connection: SharedConnection(
        host: Env.get('DB_HOST', 'localhost'),
        port: Env.get<int>('DB_PORT', 5432),
        user: Env.get('DB_USERNAME', 'postgres'),
        password: Env.get('DB_PASSWORD', 'postgres'),
        database: Env.get('DB_NAME', 'dox'),
        extra: <String, dynamic>{
          'maxConnectionCount': 10,
          'maxConnectionAge': Duration(hours: 1),
        },
      ),
      debug: true,
      printer: ConsoleQueryPrinter(),
    ),

    /// -------------------------------
    /// Mysql config
    /// -------------------------------
    'mysql': DatabaseConnection(
      driver: Driver.mysql,
      connection: SharedConnection(
        host: Env.get('DB_HOST', 'localhost'),
        port: Env.get<int>('DB_PORT', 3306),
        user: Env.get('DB_USERNAME', 'root'),
        password: Env.get('DB_PASSWORD', 'password'),
        database: Env.get('DB_NAME', 'dox'),
        extra: <String, dynamic>{
          'characterSet': mysql.CharacterSet.UTF8MB4,
        },
      ),
      debug: true,
      printer: ConsoleQueryPrinter(),
    ),
  },
);
