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

  /// initialize dox application
  /// - load env
  /// - start http server
  /// - start form requests in global ioc
  /// - register routes
  initialize(AppConfig c) {
    Env.load();
    Dox dox = Dox();
    dox.config = c;
    dox._startHttpServer();
    dox._registerFormRequests();
    dox._registerRoute();
  }

  /// register form request assign in app config
  _registerFormRequests() {
    config.formRequests.forEach((key, value) {
      Global.ioc.registerRequest(key.toString(), value);
    });
  }

  /// register routes assign in app config
  _registerRoute() {
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      Route.resetWithNewMiddleware(
          [...config.globalMiddleware, ...router.middleware]);
      router.register();
    }
    Route.prefix('');
    Route.resetWithNewMiddleware([]);
  }

  /// start http server
  _startHttpServer() {
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    server.listen(config.serverPort);
  }
}
