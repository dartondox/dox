import 'package:dox_app/app/http/handler.dart';
import 'package:dox_app/app/http/requests/blog.request.dart';
import 'package:dox_app/config/cache.dart';
import 'package:dox_app/config/cors.dart';
import 'package:dox_app/config/logger.dart';
import 'package:dox_app/config/openapi.dart';
import 'package:dox_app/config/services.dart';
import 'package:dox_app/config/socketio.dart';
import 'package:dox_app/config/storage.dart';
import 'package:dox_app/routes/api.dart';
import 'package:dox_app/routes/web.dart';
import 'package:dox_app/routes/websocket.dart';
import 'package:dox_app/config/env.dart';
import 'package:dox_core/dox_core.dart';

AppConfig appConfig = AppConfig(
  /// Application secret key
  /// -------------------------------
  /// This key is use to encrypt/decrypt the data such as cache and cookies.
  /// Make sure to keep the `APP_KEY` as an environment variable and secure.
  ///
  /// Note: Changing the application key for an existing app will make all
  /// the cookies and cache invalid and also the existing encrypted data
  /// will not be decrypted.
  appKey: env.appKey,

  /// Server port
  /// -------------------------------
  /// App will be running on this port.
  serverPort: env.appPort,

  /// Total isolate (multi thread)
  /// -------------------------------
  /// Isolates that serve http requests, all on the same port.
  /// Default is one per CPU core, which uses all cores.
  /// Set `APP_TOTAL_ISOLATE` to change it.
  totalIsolate: env.appTotalIsolate,

  /// Form requests
  /// -------------------------------
  /// Register form request to dox in order to inject into the controller.
  /// Example,
  /// {
  ///   BlogRequest : () => BlogRequest(),
  ///   UserRequest : () => UserRequest(),
  /// }
  formRequests: <Type, FormRequest Function()>{
    BlogRequest: () => BlogRequest(),
  },

  /// Global middleware
  /// -------------------------------
  /// By registering global middleware here,
  /// middleware will be applied to all the routes.
  globalMiddleware: <dynamic>[LogMiddleware(enabled: true)],

  /// Routers
  /// -------------------------------
  /// Register routers to create route to dox framework.
  routers: <Router>[WebRouter(), ApiRouter(), WebsocketRouter()],

  /// Response handler
  responseHandler: ResponseHandler(),

  /// Cache stores (config/cache.dart)
  cache: cache,

  /// Storage disks (config/storage.dart)
  storage: storage,

  /// OpenAPI docs at /docs (config/openapi.dart)
  openApi: openApi,

  /// Socket.IO on the app port (config/socketio.dart)
  socketIo: socketIo,

  /// Cors configuration
  cors: cors,

  /// Service to run on multithread server
  services: services,

  /// logger configuration
  logger: logger,
);
