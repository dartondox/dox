import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';

class Dox {
  /// setup singleton
  static Dox? _singleton;

  factory Dox() {
    if (_singleton == null) {
      Env().load();
      _singleton = Dox._internal();
    }
    return _singleton!;
  }

  Dox._internal();

  /// get dox http server
  DoxServer get server => DoxServer();

  /// get app config
  late AppConfig config;

  /// auth guard
  Guard? authGuard;

  /// initialize dox application
  /// it load env and set config
  void initialize(AppConfig config) async {
    Dox dox = Dox();
    dox.config = config;
  }

  /// start dox server
  Future<void> startServer() async {
    _registerFormRequests();
    _registerRoute();
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    await server.listen(config.serverPort);
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
}
