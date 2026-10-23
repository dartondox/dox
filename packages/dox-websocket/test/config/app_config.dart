import 'package:dox_core/dox_core.dart';

import 'router.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) {
    return res;
  }
}

AppConfig appConfig = AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// the OS picks a free port, so test files can run in parallel
  serverPort: 0,

  /// total multi-thread isolate to run
  totalIsolate: 1,

  // cors configuration
  cors: CORSConfig(origin: '*', methods: '*', credentials: true),

  /// response handler
  responseHandler: ResponseHandler(),

  /// global middleware
  globalMiddleware: <dynamic>[],

  /// routers
  routers: <Router>[WebsocketRouter()],

  /// cache driver configuration
  cache: CacheConfig(
    defaultStore: 'file',
    stores: <String, Map<String, dynamic>>{
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
      'memory': <String, dynamic>{'driver': 'memory'},
    },
  ),
);
