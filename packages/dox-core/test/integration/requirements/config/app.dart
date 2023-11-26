import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

import '../handler.dart';
import '../middleware/custom_middleware.dart';
import '../requests/blog_request.dart';
import 'api_router.dart';

class Config extends AppConfig {
  @override
  int get totalIsolate => 1;

  @override
  String get appKey => '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

  int _serverPort = 50010;

  @override
  int get serverPort => _serverPort;

  set serverPort(int val) => _serverPort = val;

  @override
  CORSConfig get cors => CORSConfig(
        allowOrigin: '*',
        allowMethods: <String>['GET', 'POST', 'DELETE', 'PUT', 'PATCH'],
        allowCredentials: true,
      );

  @override
  ResponseHandlerInterface get responseHandler => ResponseHandler();

  @override
  List<dynamic> get globalMiddleware => <dynamic>[customMiddleware];

  @override
  Map<Type, Function()> get formRequests => <Type, Function()>{
        BlogRequest: () => BlogRequest(),
      };

  @override
  List<Router> get routers => <Router>[ApiRouter()];

  @override
  void Function(Object? error, StackTrace stackTrace) get errorHandler =>
      (Object? error, StackTrace stackTrace) {
        DoxLogger.danger(error);
      };

  @override
  CacheConfig get cacheConfig => CacheConfig(
        defaultDriver: 'redis',
        drivers: <String, CacheDriverInterface>{
          'file': FileCacheDriver(),
        },
      );
}
