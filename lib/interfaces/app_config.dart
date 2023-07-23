/// coverage:ignore-file
import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

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

  int totalIsolate = 3;

  int get serverPort;

  ResponseHandlerInterface get responseHandler;

  void Function(Object?, StackTrace) get errorHandler =>
      (Object? error, StackTrace stackTrace) {
        DoxLogger.warn(error);
        DoxLogger.danger(stackTrace.toString());
      };

  Map<Type, Function()> get formRequests => <Type, Function()>{};

  List<dynamic> get globalMiddleware => <dynamic>[];

  List<Router> get routers;

  CORSConfig get cors;

  CacheDriverInterface? get customCacheDriver => null;
}
