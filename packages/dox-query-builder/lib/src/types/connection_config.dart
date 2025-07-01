import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:postgres/postgres.dart' as postgres;

class ConnectionConfig {
  /// Database driver
  /// Driver.mysql or Driver.postgres
  Driver driver;

  /// Enable debugging mode
  bool debug;

  /// Query printer to use when debugging mode is no.
  /// support build-in `PrettyQueryPrinter()` and `ConsoleQueryPrinter()`
  /// and `FileQueryPrinter()`.
  /// You can also create your own custom query printer by implementing
  /// `QueryPrinter` interface
  QueryPrinter? printer;

  /// database host
  String host;

  /// database username
  String user;

  /// database password
  String password;

  /// database name
  String database;

  /// database connection port
  int port;

  /// use ssl mode
  bool useSSL;

  /// extra configuration for the connection
  /// eg. `characterSet` for mysql and `maxConnectionCount` for postgres
  Map<String, dynamic> extra;

  ConnectionConfig({
    required this.driver,
    this.host = 'localhost',
    this.useSSL = false,
    required this.user,
    required this.password,
    required this.database,
    required this.port,
    this.extra = const <String, dynamic>{},
    required this.debug,
    this.printer,
  });

  /// get database connection
  /// with  mysql `MysqlConnection` or postgres `Connection` type
  Future<dynamic> getDatabaseConnection() {
    if (driver == Driver.mysql) {
      return _getMysqlConnection();
    }
    return _getPostgresConnection();
  }

  /// get mysql connection
  Future<mysql.MySqlConnection> _getMysqlConnection() {
    return mysql.MySqlConnection.connect(
      mysql.ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
        useSSL: useSSL,
        useCompression: extra['useCompression'] ?? false,
        maxPacketSize: extra['maxPacketSize'] ?? 16 * 1024 * 1024,
        timeout: extra['timeout'] ?? const Duration(seconds: 30),
        characterSet: extra['characterSet'] ?? mysql.CharacterSet.UTF8MB4,
      ),
      isUnixSocket: extra['isUnixSocket'] ?? false,
    );
  }

  /// get mysql connection
  Future<postgres.Connection> _getPostgresConnection() {
    postgres.SslMode sslMode =
        useSSL ? postgres.SslMode.require : postgres.SslMode.disable;

    return postgres.Connection.open(
      postgres.Endpoint(
        host: host,
        port: port,
        username: user,
        password: password,
        database: database,
      ),
      settings: postgres.PoolSettings(
        sslMode: extra['sslMode'] ?? sslMode,
        maxConnectionCount: extra['maxConnectionCount'],
        maxConnectionAge: extra['maxConnectionAge'],
        maxSessionUse: extra['maxSessionUse'],
        maxQueryCount: extra['maxQueryCount'],
        applicationName: extra['applicationName'],
        connectTimeout: extra['connectTimeout'],
        encoding: extra['encoding'],
        timeZone: extra['timeZone'],
        replicationMode: extra['replicationMode'],
        transformer: extra['transformer'],
        queryTimeout: extra['queryTimeout'],
        queryMode: extra['queryMode'],
        ignoreSuperfluousParameters: extra['ignoreSuperfluousParameters'],
      ),
    );
  }
}
