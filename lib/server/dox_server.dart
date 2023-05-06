import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/dox_http_request.dart';

class DoxServer {
  static final DoxServer _singleton = DoxServer._internal();

  factory DoxServer() {
    return _singleton;
  }

  DoxServer._internal();

  ExceptionHandler? exceptionHandler;

  late HttpServer httpServer;
  DoxWebsocket? doxWebsocket;

  Future<HttpServer> listen(int port, {Function? onError}) async {
    Env.load();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print(
        '\x1B[34m[Dox] Server started at http://127.0.0.1:${server.port}\x1B[0m');

    server.listen(
      (HttpRequest req) {
        _setCors(req);
        DoxHttpRequest().handle(req);
      },
      onError: onError ?? (error) => {print(error)},
    );
    httpServer = server;
    return server;
  }

  setExceptionHandler(ExceptionHandler handler) {
    exceptionHandler = handler;
  }

  _setCors(HttpRequest req) {
    CORSConfig cors = Dox().config.cors;
    _parseCorsValue(req, 'Access-Control-Allow-Origin', cors.allowOrigin);
    _parseCorsValue(req, 'Access-Control-Allow-Methods', cors.allowMethods);
    _parseCorsValue(req, 'Access-Control-Allow-Headers', cors.allowHeaders);
    _parseCorsValue(req, 'Access-Control-Expose-Headers', cors.exposeHeaders);
    if (cors.allowCredentials != null) {
      req.response.headers.add(
          'Access-Control-Allow-Credentials', cors.allowCredentials.toString());
    }
    if (cors.maxAge != null) {
      req.response.headers
          .add('Access-Control-Max-Age', cors.maxAge.toString());
    }
  }

  _parseCorsValue(HttpRequest req, key, data) {
    if (data is List<String> && data.isNotEmpty) {
      req.response.headers.add(key, data.join(','));
    } else if (data is String && data.isNotEmpty) {
      req.response.headers.add(key, data);
    }
  }
}
