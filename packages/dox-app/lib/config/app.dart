import 'package:dox_app/http/handler.dart';
import 'package:dox_app/http/requests/blog.request.dart';
import 'package:dox_app/routes/api.dart';
import 'package:dox_app/routes/web.dart';
import 'package:dox_app/routes/websocket.dart';
import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';

class Config extends AppConfig {
  @override
  int get totalIsolate => 6;

  @override
  String get appKey => Env.get('APP_KEY');

  @override
  int get serverPort => int.parse(Env.get('APP_PORT', 3000));

  @override
  Map<Type, Function()> get formRequests => <Type, Function()>{
        BlogRequest: () => BlogRequest(),
      };

  @override
  List<dynamic> get globalMiddleware => <dynamic>[
        // LogMiddleware(filter: logFilter, withHeader: true),
      ];

  @override
  List<Router> get routers => <Router>[
        WebRouter(),
        ApiRouter(),
        WebsocketRouter(),
      ];

  @override
  CORSConfig get cors => CORSConfig(
        allowOrigin: '*',
        allowHeaders: '*',
        allowMethods: '*',
        allowCredentials: true,
        exposeHeaders: '*',
      );
  @override
  CacheConfig get cacheConfig => CacheConfig(
        drivers: <String, CacheDriverInterface>{
          'file': FileCacheDriver(),
        },
      );

  @override
  ResponseHandlerInterface get responseHandler => ResponseHandler();

  // @override
  // void Function(Object? error, StackTrace stackTrace) get errorHandler =>
  //     (Object? error, StackTrace stackTrace) {
  //       DoxLogger.prettyLog(
  //         'error',
  //         error.toString(),
  //         stackTrace.toString(),
  //       );
  //     };
}
