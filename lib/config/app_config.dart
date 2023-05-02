import 'package:dox_core/dox_core.dart';

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
}
