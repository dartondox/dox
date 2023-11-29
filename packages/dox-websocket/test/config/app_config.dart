import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

import 'router.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  void handle(DoxResponse res) {}
}

class Config extends AppConfig {
  @override
  int get totalIsolate => 3;

  @override
  String get appKey => '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

  int _serverPort = 3001;

  @override
  int get serverPort => _serverPort;

  set serverPort(int val) => _serverPort = val;

  @override
  CORSConfig get cors => CORSConfig(
        allowOrigin: '*',
        allowMethods: '*',
        allowCredentials: true,
      );

  @override
  List<Router> get routers => <Router>[WebsocketRouter()];

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

  @override
  ResponseHandlerInterface get responseHandler => ResponseHandler();
}
