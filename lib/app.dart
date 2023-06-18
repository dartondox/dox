import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';

class Dox {
  /// setup singleton
  static final Dox _singleton = Dox._internal();
  factory Dox() => _singleton;
  Dox._internal();

  /// get dox http server
  DoxServer get server => DoxServer();

  /// get app config
  late AppConfig config;

  /// auth guard
  Guard? authGuard;

  /// initialize dox application
  /// - load env
  /// - start http server
  /// - start form requests in global ioc
  /// - register routes
  Future<void> initialize(AppConfig config) async {
    Env.load();
    Dox dox = Dox();
    dox.config = config;
    dox._registerFormRequests();
    dox._registerRoute();
    await dox._startHttpServer();
  }

  /// set authorization config
  /// and this function can only call after initialize()
  /// ```
  /// await dox.initialize(config)
  /// dox.setAuthConfig(AuthConfig())
  /// ```
  void setAuthConfig(AuthConfigInterface authConfig) {
    Dox().authGuard = authConfig.guards[authConfig.defaultGuard];
  }

  /// register form request assign in app config
  void _registerFormRequests() {
    config.formRequests.forEach((Type key, Function() value) {
      Global.ioc.registerRequest(key.toString(), value);
    });
  }

  /// register routes assign in app config
  void _registerRoute() {
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      Route.resetWithNewMiddleware(
          <dynamic>[...config.globalMiddleware, ...router.middleware]);
      router.register();
    }
    Route.prefix('');
    Route.resetWithNewMiddleware(<dynamic>[]);
  }

  /// start http server
  Future<void> _startHttpServer() async {
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    await server.listen(config.serverPort);
  }
}
