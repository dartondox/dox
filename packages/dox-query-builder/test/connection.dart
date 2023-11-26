import 'dart:io';

import 'package:postgres_pool/postgres_pool.dart';

Future<PostgreSQLConnection> connection() async {
  String host = Platform.environment['DB_HOST'] ?? 'localhost';
  int port = int.parse(Platform.environment['PORT'] ?? '5432');
  PostgreSQLConnection db = PostgreSQLConnection(
    host,
    port,
    "postgres",
    username: "admin",
    password: "password",
  );
  await db.open();
  return db;
}

PgPool poolConnection() {
  String host = Platform.environment['DB_HOST'] ?? 'localhost';
  int port = int.parse(Platform.environment['PORT'] ?? '5432');
  return PgPool(
    PgEndpoint(
      host: host,
      port: port,
      database: 'postgres',
      username: 'admin',
      password: 'password',
    ),
    settings: PgPoolSettings()
      ..maxConnectionAge = Duration(hours: 1)
      ..concurrency = 4,
  );
}
