import 'package:dox_query_builder/dox_query_builder.dart';

class DatabaseConfig {
  /// Name of the connection
  String connection;

  /// List of database connections
  Map<String, ConnectionConfig> connections;

  DatabaseConfig({
    required this.connection,
    required this.connections,
  });

  /// get database connection configuration
  ConnectionConfig getConnectionConfig([String? connectionName]) {
    ConnectionConfig? conn;
    if (connectionName == null) {
      conn = connections[connection];
    } else {
      conn = connections[connectionName];
    }
    if (conn == null) {
      throw Exception('$connection not found');
    }
    return conn;
  }
}
