import 'dart:io';

import 'package:dox_orm/dox_orm.dart';

class DatabaseConfig {
  /// Name of the connection
  String connection;

  /// List of database connections
  Map<String, ConnectionConfig> connections;

  /// A database url, like `postgres://user:pass@host:5432/db`.
  /// See [ConnectionConfig.fromUrl] for the forms it reads.
  ///
  /// The rule: when it is set, it wins. It replaces the config of
  /// [connection] (the default connection). That config still gives
  /// `debug`, `printer` and `extra`. Other named connections do not change.
  ///
  /// When not given, it is the `DATABASE_URL` environment variable.
  /// An empty text means no url.
  String? url;

  DatabaseConfig({
    required this.connection,
    required this.connections,
    String? url,
  }) : url = url ?? Platform.environment['DATABASE_URL'];

  ConnectionConfig? _fromUrl;

  /// get database connection configuration
  ConnectionConfig getConnectionConfig([String? connectionName]) {
    String name = connectionName ?? connection;
    String? databaseUrl = url?.trim();
    if (name == connection && databaseUrl != null && databaseUrl.isNotEmpty) {
      ConnectionConfig? base = connections[connection];
      return _fromUrl ??= ConnectionConfig.fromUrl(
        databaseUrl,
        debug: base?.debug ?? false,
        printer: base?.printer,
        extra: base?.extra ?? const <String, dynamic>{},
      );
    }
    ConnectionConfig? conn = connections[name];
    if (conn == null) {
      throw Exception('$name not found');
    }
    return conn;
  }
}
