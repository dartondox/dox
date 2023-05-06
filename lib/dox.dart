import 'package:dox_core/dox_core.dart';
import 'package:postgres_pool/postgres_pool.dart';

class Dox {
  static final Dox _singleton = Dox._internal();

  factory Dox() {
    return _singleton;
  }

  Dox._internal();

  late AppConfig config;

  static DoxServer get server => DoxServer();

  static dynamic get db => SqlQueryBuilder().db;

  initialize(AppConfig config) {
    Env.load();
    Dox dox = Dox();
    dox.config = config;
    dox._initQueryBuilder();
    dox._initServer();
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
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
    server.setExceptionHandler(config.exceptionHandler);
    server.listen(config.serverPort);
  }

  Future<dynamic> _initQueryBuilder() async {
    var config = Dox().config.dbConfig;
    if (config.dbDriver == DatabaseDriver.postgres) {
      PgPool db = PgPool(
        PgEndpoint(
          host: config.dbHost,
          port: config.dbPort,
          database: config.dbName,
          username: config.dbUsername,
          password: config.dbPassword,
        ),
        settings: PgPoolSettings()
          ..maxConnectionAge = Duration(hours: 1)
          ..concurrency = 4,
      );
      SqlQueryBuilder.initialize(database: db, debug: config.enableQueryLog);
    }
  }
}
