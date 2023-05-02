import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:postgres/postgres.dart';
import 'package:sql_query_builder/sql_query_builder.dart';

class Dox {
  static final Dox _singleton = Dox._internal();

  factory Dox() {
    return _singleton;
  }

  Dox._internal();

  late AppConfig config;

  static HttpServer get httpServer => DoxServer().httpServer;

  static initialize(AppConfig config) {
    Env.load();
    Dox dox = Dox();
    dox.config = config;
    dox.initQueryBuilder();
    dox.initServer();
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      router.register();
    }
  }

  static dynamic get db => SqlQueryBuilder().db;

  initServer() {
    var config = Dox().config;
    DoxServer server = DoxServer();
    server.setExceptionHandler(config.exceptionHandler);
    server.listen(config.serverPort);
  }

  Future<dynamic> initQueryBuilder() async {
    var config = Dox().config;
    if (config.dbDriver == DatabaseDriver.postgres) {
      PostgreSQLConnection db = PostgreSQLConnection(
        config.dbHost,
        config.dbPort,
        config.dbName,
        username: config.dbUsername,
        password: config.dbPassword,
      );
      await db.open();
      SqlQueryBuilder.initialize(database: db, debug: config.enableQueryLog);
    }
  }
}
