import 'dart:io';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart' as mysql;

DatabaseConfig databaseConfig = DatabaseConfig(
  /// -------------------------------
  /// Connection
  /// -------------------------------
  /// The primary connection for making database queries across the application
  /// You can use any key from the `connections` Map defined in this same
  /// file.
  connection: Platform.environment['DRIVER'] ?? 'mysql',

  connections: <String, ConnectionConfig>{
    /// -------------------------------
    /// Postgres config
    /// -------------------------------
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      port: 5432,
      user: 'postgres',
      password: 'postgres',
      database: 'postgres',
      extra: <String, dynamic>{
        'maxConnectionCount': 20,
        'maxConnectionAge': Duration(hours: 1),
      },
      debug: false,
      printer: ConsoleQueryPrinter(),
    ),

    /// -------------------------------
    /// Mysql config
    /// -------------------------------
    'mysql': ConnectionConfig(
      driver: Driver.mysql,
      port: 3306,
      user: Platform.environment['DB_USER'] ?? 'root',
      password: 'password',
      database: 'dox-framework',
      extra: <String, dynamic>{
        'characterSet': mysql.CharacterSet.UTF8MB4,
      },
      debug: false,
      printer: ConsoleQueryPrinter(),
    ),
  },
);

Future<void> initQueryBuilder() async {
  SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
}
