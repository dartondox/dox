import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_request_handler.dart';

class DoxServer {
  /// register singleton
  static final DoxServer _singleton = DoxServer._internal();
  factory DoxServer() => _singleton;
  DoxServer._internal();

  /// httpServer dart:io
  late HttpServer httpServer;

  /// set responseHandler
  ResponseHandlerInterface? responseHandler;

  /// listen the request
  /// ```
  /// DoxServer().listen(3000);
  /// ```
  Future<HttpServer> listen(int port,
      {Function? onError, int? isolateId}) async {
    HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv6,
      port,
      shared: true,
    );
    server.listen(
      (HttpRequest req) {
        httpCorsHandler(req);
        httpRequestHandler(req);
      },
      onError: onError ?? (dynamic error) => print(error),
    );
    httpServer = server;
    return server;
  }

  /// close http server
  /// ```
  /// server.close();
  /// ```
  Future<void> close({bool force = false}) async {
    await httpServer.close(force: force);
  }

  /// set response handler
  /// ```
  /// server.setResponseHandler(Handler());
  /// ```
  void setResponseHandler(ResponseHandlerInterface? handler) {
    responseHandler = handler;
  }
}
