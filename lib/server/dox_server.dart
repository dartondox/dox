import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_request_handler.dart';
import 'package:dox_core/utils/logger.dart';

class DoxServer {
  /// register singleton
  static final DoxServer _singleton = DoxServer._internal();
  factory DoxServer() => _singleton;
  DoxServer._internal();

  /// httpServer dart:io
  late HttpServer httpServer;

  /// set responseHandler
  Handler? responseHandler;

  /// listen the request
  /// ```
  /// DoxServer().listen(3000);
  /// ```
  Future<HttpServer> listen(int port, {Function? onError}) async {
    Env.load();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    DoxLogger.info("Server started at http://127.0.0.1:${server.port}");
    server.listen(
      (HttpRequest req) {
        _setCors(req);
        httpRequestHandler(req);
      },
      onError: onError ?? (error) => {print(error)},
    );
    httpServer = server;
    return server;
  }

  /// close http server
  /// ```
  /// server.close();
  /// ```
  close({bool force = false}) {
    httpServer.close(force: force);
  }

  /// set response handler
  /// ```
  /// server.setResponseHandler(Handler());
  /// ```
  setResponseHandler(Handler handler) {
    responseHandler = handler;
  }

  _setCors(HttpRequest req) {
    CORSConfig cors = Dox().config.cors;
    _setCorsValue(req, 'Access-Control-Allow-Origin', cors.allowOrigin);
    _setCorsValue(req, 'Access-Control-Allow-Methods', cors.allowMethods);
    _setCorsValue(req, 'Access-Control-Allow-Headers', cors.allowHeaders);
    _setCorsValue(req, 'Access-Control-Expose-Headers', cors.exposeHeaders);
    if (cors.allowCredentials != null) {
      req.response.headers.add(
          'Access-Control-Allow-Credentials', cors.allowCredentials.toString());
    }
    if (cors.maxAge != null) {
      req.response.headers
          .add('Access-Control-Max-Age', cors.maxAge.toString());
    }
  }

  _setCorsValue(HttpRequest req, key, data) {
    if (data is List<String> && data.isNotEmpty) {
      req.response.headers.add(key, data.join(','));
    } else if (data is String && data.isNotEmpty) {
      req.response.headers.add(key, data);
    }
  }
}
