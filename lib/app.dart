import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';

class Dox {
  /// setup singleton
  static final Dox _singleton = Dox._internal();
  factory Dox() => _singleton;
  Dox._internal();

  late AppConfig _config;

  /// get dox http server
  DoxServer get server => DoxServer();

  /// get app config
  AppConfig get config => _config;

  /// initialize dox application
  /// - load env
  /// - start http server
  /// - start form requests in global ioc
  /// - register routes
  initialize(AppConfig c) {
    Env.load();
    Dox dox = Dox();
    dox._config = c;
    dox._startHttpServer();
    dox._registerFormRequests();
    dox._registerRoute();
  }

  /// register form request assign in app config
  _registerFormRequests() {
    _config.formRequests.forEach((key, value) {
      Global.ioc.registerRequest(key.toString(), value);
    });
  }

  /// register routes assign in app config
  _registerRoute() {
    List<Router> routers = _config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      Route.resetWithNewMiddleware(
          [..._config.globalMiddleware, ...router.middleware]);
      router.register();
    }
  }

  /// start http server
  _startHttpServer() {
    DoxServer server = DoxServer();
    server.setResponseHandler(_config.responseHandler);
    server.listen(_config.serverPort);
  }
}
