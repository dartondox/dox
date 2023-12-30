import 'dart:io';

import 'package:mysql1/mysql1.dart';

Future<MySqlConnection> mysqlConnection() {
  String host = Platform.environment['DB_HOST'] ?? 'localhost';
  int port = int.parse(Platform.environment['PORT'] ?? '3306');
  ConnectionSettings settings = ConnectionSettings(
    host: host,
    port: port,
    user: 'root',
    password: 'password',
    db: 'dox-framework',
  );
  return MySqlConnection.connect(settings);
}
