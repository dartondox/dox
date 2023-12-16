import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_error_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/http_route_handler.dart';
import 'package:dox_core/http/http_websocket_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/router/route_data.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
void httpRequestHandler(HttpRequest req) {
  try {
    RouteData? route = httpRouteHandler(req);
    if (route == null) return;

    httpCorsHandler(route.corsEnabled, req);

    if (WebSocketTransformer.isUpgradeRequest(req)) {
      httpWebSocketHandler(req, route);
      return;
    }

    getDoxRequest(req, route).then((DoxRequest doxReq) {
      middlewareAndControllerHandler(doxReq).then((dynamic result) {
        httpResponseHandler(result, req);
      }).onError((Object? error, StackTrace stackTrace) {
        httpErrorHandler(req, error, stackTrace);
      });
    }).onError((Object? error, StackTrace stackTrace) {
      httpErrorHandler(req, error, stackTrace);
    });

    /// form data do not support isolate or multithread
  } catch (error, stackTrace) {
    httpErrorHandler(req, error, stackTrace);
  }
}

Future<DoxRequest> getDoxRequest(HttpRequest req, RouteData route) async {
  return DoxRequest(
    route: route,
    uri: req.uri,
    body: await HttpBody.read(req),
    contentType: req.headers.contentType,
    clientIp: req.connectionInfo?.remoteAddress.address,
    httpHeaders: req.headers,
    httpRequest: req,
  );
}
