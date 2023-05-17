import 'package:dox_core/dox_core.dart';

class Dox {
  static final Dox _singleton = Dox._internal();

  factory Dox() {
    return _singleton;
  }

  Dox._internal();

  late AppConfig config;

  static DoxServer get server => DoxServer();

  initialize(AppConfig config) {
    Env.load();
    Dox dox = Dox();
    dox.config = config;
    dox._initServer();
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      Route.use(router.middleware);
      router.register();
    }
  }

  Dox websocket({
    required DoxWebsocket websocket,
    String route = 'ws',
    List middleware = const [],
  }) {
    Route.websocket(
      websocket: websocket,
      route: route,
      middleware: middleware,
    );
    return this;
  }

  _initServer() {
    var config = Dox().config;
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    server.listen(config.serverPort);
  }
}
