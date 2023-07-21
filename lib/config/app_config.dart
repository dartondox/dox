/// coverage:ignore-file
import 'package:dox_core/dox_core.dart';

class CORSConfig {
  final dynamic allowOrigin;
  final dynamic allowMethods;
  final dynamic allowHeaders;
  final dynamic exposeHeaders;
  final bool? allowCredentials;
  final int? maxAge;

  const CORSConfig({
    this.allowOrigin,
    this.allowMethods,
    this.allowHeaders,
    this.exposeHeaders,
    this.allowCredentials,
    this.maxAge,
  });
}

class DBConfig {
  final DatabaseDriver dbDriver;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUsername;
  final String dbPassword;
  final bool enableQueryLog;

  const DBConfig({
    required this.dbDriver,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUsername,
    required this.dbPassword,
    required this.enableQueryLog,
  });
}

abstract class AppConfig {
  String get appKey;

  int get serverPort;

  DBConfig get dbConfig;

  Handler get responseHandler;

  Map<Type, Function()> get formRequests => <Type, Function()>{};

  List<dynamic> get globalMiddleware => <dynamic>[];

  List<Router> get routers;

  CORSConfig get cors;
}
