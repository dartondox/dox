import 'package:dox_query_builder/dox_query_builder.dart';

class DatabaseConfig {
  /// Name of the connection
  String connection;

  /// List of database connections
  Map<String, DatabaseConnection> connections;

  DatabaseConfig({
    required this.connection,
    required this.connections,
  });
}

class DatabaseConnection {
  /// Database driver
  /// Driver.mysql or Driver.postgres
  Driver driver;

  /// Database connection.
  /// for postgres it should be `Future<Connection>` datatype
  /// for mysql it should be `Future<MySqlConnection>` datatype
  SharedConnection connection;

  /// Enable debugging mode
  bool debug;

  /// Query printer to use when debugging mode is no.
  /// support build in `PrettyQueryPrinter()` and `ConsoleQueryPrinter()`
  /// and `FileQueryPrinter()`.
  /// You can also create your own custom query printer by implementing
  /// `QueryPrinter`
  QueryPrinter? printer;

  DatabaseConnection({
    required this.driver,
    required this.connection,
    required this.debug,
    this.printer,
  });
}

class SharedConnection {
  String host;
  String user;
  String password;
  String database;
  int port;
  bool useSSL;
  Map<String, dynamic> extra;

  SharedConnection({
    this.host = 'localhost',
    this.useSSL = false,
    required this.user,
    required this.password,
    required this.database,
    required this.port,
    this.extra = const <String, dynamic>{},
  });
}
