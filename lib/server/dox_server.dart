import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxServer {
  static final DoxServer _singleton = DoxServer._internal();

  factory DoxServer() {
    return _singleton;
  }

  DoxServer._internal();

  ExceptionHandler? exceptionHandler;

  late HttpServer httpServer;

  Future<HttpServer> listen(int port, {Function? onError}) async {
    Env.load();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print(
        '\x1B[34m[Dox] Server started at http://127.0.0.1:${server.port}\x1B[0m');

    server.listen(
      RouteHandler().handle,
      onError: onError ?? (error) => {print(error)},
    );
    httpServer = server;
    return server;
  }

  setExceptionHandler(ExceptionHandler handler) {
    exceptionHandler = handler;
  }
}
