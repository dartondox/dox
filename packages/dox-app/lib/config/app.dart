import 'package:dox_app/config/cache.dart';
import 'package:dox_app/config/cors.dart';
import 'package:dox_app/config/services.dart';
import 'package:dox_app/config/storage.dart';
import 'package:dox_app/http/handler.dart';
import 'package:dox_app/http/requests/blog.request.dart';
import 'package:dox_app/routes/api.dart';
import 'package:dox_app/routes/web.dart';
import 'package:dox_app/routes/websocket.dart';
import 'package:dox_core/dox_core.dart';

AppConfig appConfig = AppConfig(
  /// application key
  appKey: Env.get('APP_KEY'),

  /// application server port
  serverPort: int.parse(Env.get('APP_PORT', 3000)),

  /// total multi-thread isolate to run
  totalIsolate: 6,

  /// global middleware
  globalMiddleware: <dynamic>[],

  /// form requests
  formRequests: <Type, FormRequest Function()>{
    BlogRequest: () => BlogRequest(),
  },

  /// routers
  routers: <Router>[
    WebRouter(),
    ApiRouter(),
    WebsocketRouter(),
  ],

  /// response handler
  responseHandler: ResponseHandler(),

  /// service to run on multithread server
  services: services,

  /// cors configuration
  cors: cors,

  /// cache driver configuration
  cache: cache,

  /// file storage driver configuration
  fileStorage: storage,
);
