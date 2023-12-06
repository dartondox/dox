import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';

import 'router.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  void handle(DoxResponse res) {}
}

AppConfig appConfig = AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// application server port
  serverPort: 3004,

  /// total multi-thread isolate to run
  totalIsolate: 3,

  // cors configuration
  cors: CORSConfig(
    allowOrigin: '*',
    allowMethods: '*',
    allowCredentials: true,
  ),

  /// response handler
  responseHandler: ResponseHandler(),

  /// global middleware
  globalMiddleware: <dynamic>[],

  /// routers
  routers: <Router>[
    WebsocketRouter(),
  ],

  /// cache driver configuration
  cache: CacheConfig(
    drivers: <String, CacheDriverInterface>{
      'file': FileCacheDriver(),
    },
  ),
);
