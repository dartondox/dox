import 'package:dox_core/dox_core.dart';
import 'package:postgres/postgres.dart';

Endpoint postgresEndpoint = Endpoint(
  /// database host
  host: Env.get('DB_HOST', 'localhost'),

  /// database port
  port: Env.get<int>('DB_PORT', 5432),

  /// database name
  database: Env.get('DB_NAME', 'dox'),

  /// database username
  username: Env.get('DB_USERNAME', 'postgres'),

  /// database password
  password: Env.get('DB_PASSWORD', 'postgres'),
);

/// postgres pool connection configuration
PoolSettings postgresPoolSetting = PoolSettings(
  /// The maximum number of concurrent sessions.
  maxConnectionCount: 10,

  /// The maximum duration a connection is kept open.
  /// New sessions won't be scheduled after this limit is reached.
  maxConnectionAge: Duration(hours: 1),

  sslMode: SslMode.disable,
);
