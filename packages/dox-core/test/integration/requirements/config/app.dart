import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

import '../handler.dart';
import '../middleware/custom_middleware.dart';
import '../../../dtos/dtos.dart';
import 'api_router.dart';

AppConfig config = AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// application server port
  serverPort: 50010,

  /// total multi-thread isolate to run
  totalIsolate: 1,

  // cors configuration
  cors: CORSConfig(
    enabled: false,
    origin: '*',
    methods: <String>['GET', 'POST', 'DELETE', 'PUT', 'PATCH'],
    credentials: true,
  ),

  /// response handler
  responseHandler: ResponseHandler(),

  /// global middleware
  globalMiddleware: <dynamic>[customMiddleware],

  /// the DTOs of the tests
  dtos: testDtos,

  /// routers
  routers: <Router>[ApiRouter()],

  /// error handler
  errorHandler: (Object? error, StackTrace stackTrace) {
    Logger.danger(error);
  },

  /// cache driver configuration
  cache: CacheConfig(
    defaultStore: 'file',
    stores: <String, Map<String, dynamic>>{
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
      'memory': <String, dynamic>{'driver': 'memory'},
    },
  ),
);
