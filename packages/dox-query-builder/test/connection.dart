import 'dart:io';

import 'package:postgres/postgres.dart';

Future<Connection> poolConnection() {
  String host = Platform.environment['DB_HOST'] ?? 'localhost';
  int port = int.parse(Platform.environment['PORT'] ?? '5432');
  return Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: 'postgres',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: PoolSettings(
      sslMode: SslMode.disable,
    ),
  );
}
