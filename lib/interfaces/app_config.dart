/// coverage:ignore-file
import 'package:dox_core/dox_core.dart';

class CORSConfig {
  final dynamic allowOrigin;
  final dynamic allowMethods;
  final dynamic allowHeaders;
  final dynamic exposeHeaders;
  final bool? allowCredentials;

  const CORSConfig({
    this.allowOrigin,
    this.allowMethods,
    this.allowHeaders,
    this.exposeHeaders,
    this.allowCredentials,
  });
}

abstract class AppConfig {
  String get appKey;

  int get serverPort;

  Handler get responseHandler;

  Map<Type, Function()> get formRequests => <Type, Function()>{};

  List<dynamic> get globalMiddleware => <dynamic>[];

  List<Router> get routers;

  CORSConfig get cors;
}
