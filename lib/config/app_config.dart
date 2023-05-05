import 'package:dox_core/dox_core.dart';

class CORSConfig {
  final dynamic allowOrigin;
  final dynamic allowMethods;
  final dynamic allowMHeaders;
  final dynamic exposeHeaders;
  final bool? allowCredentials;
  final int? maxAge;

  const CORSConfig({
    this.allowOrigin,
    this.allowMethods,
    this.allowMHeaders,
    this.exposeHeaders,
    this.allowCredentials,
    this.maxAge,
  });
}

abstract class AppConfig {
  int get serverPort;
  String get dbDriver;
  String get dbHost;
  int get dbPort;
  String get dbName;
  String get dbUsername;
  String get dbPassword;

  ExceptionHandler get exceptionHandler;
  List<Router> get routers;

  bool get enableQueryLog;

  CORSConfig? get cors;
}
