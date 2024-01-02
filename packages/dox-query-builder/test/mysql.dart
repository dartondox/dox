import 'dart:io';

import 'package:mysql1/mysql1.dart';

Future<MySqlConnection> mysqlConnection() {
  String host = Platform.environment['DB_HOST'] ?? 'localhost';
  int port = int.parse(Platform.environment['PORT'] ?? '3306');
  String user = Platform.environment['DB_USER'] ?? 'root';
  ConnectionSettings settings = ConnectionSettings(
    host: host,
    port: port,
    user: user,
    password: 'password',
    db: 'dox-framework',
  );
  return MySqlConnection.connect(settings);
}
