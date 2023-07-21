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
    HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    DoxLogger.info('Server started at http://127.0.0.1:${server.port}');
    server.listen(
      (HttpRequest req) {
        _setCors(req);
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
  void setResponseHandler(Handler handler) {
    responseHandler = handler;
  }

  /// set cors in the response header
  void _setCors(HttpRequest req) {
    CORSConfig cors = Dox().config.cors;
    Map<String, dynamic> headers = <String, dynamic>{
      'Access-Control-Allow-Origin': cors.allowOrigin,
      'Access-Control-Allow-Methods': cors.allowMethods,
      'Access-Control-Allow-Headers': cors.allowHeaders,
      'Access-Control-Expose-Headers': cors.exposeHeaders,
      'Access-Control-Allow-Credentials': cors.allowCredentials,
    };

    headers.forEach((String key, dynamic value) {
      _setCorsValue(req.response, key, value);
    });
  }

  // set cors in header
  void _setCorsValue(HttpResponse res, String key, dynamic data) {
    /// when data is list of string, eg. ['GET', 'POST']
    if (data is List<String> && data.isNotEmpty) {
      res.headers.add(key, data.join(','));
      return;
    }

    /// when data is string, eg. 'GET'
    if (data is String && data.isNotEmpty) {
      res.headers.add(key, data);
      return;
    }

    /// when data is other type and has value, just convert to string
    if (data != null) {
      res.headers.add(key, data.toString());
    }
  }
}
