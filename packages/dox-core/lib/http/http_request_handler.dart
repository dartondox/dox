import 'dart:async';
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
import 'package:dox_http_native/dox_http_native.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
void httpRequestHandler(HttpRequest req) {
  try {
    /// raw handlers like Socket.IO. empty map when nothing is mounted.
    Map<String, RawRequestHandler> mounts = Route().mounts;
    if (mounts.isNotEmpty && _mounted(req, mounts)) return;

    RouteData? route = httpRouteHandler(req);
    if (route == null) return;

    httpCorsHandler(route.corsEnabled, req);

    if (NativeWebSocket.isUpgradeRequest(req)) {
      httpWebSocketHandler(req, route);
      return;
    }

    /// no Content-Type means no body to read. then the request is
    /// made at once, with no Future in between.
    if (req.headers.contentType == null) {
      _run(req, _doxRequest(req, route, RequestBody.empty()));
    } else {
      HttpBody.read(req)
          .then((RequestBody body) {
            _run(req, _doxRequest(req, route, body));
          })
          .onError((Object? error, StackTrace stackTrace) {
            httpErrorHandler(req, error, stackTrace);
          });
    }

    /// form data do not support isolate or multithread
  } catch (error, stackTrace) {
    httpErrorHandler(req, error, stackTrace);
  }
}

/// hand the request to a mounted handler. it writes the response itself.
bool _mounted(HttpRequest req, Map<String, RawRequestHandler> mounts) {
  String path = req.uri.path;
  for (MapEntry<String, RawRequestHandler> mount in mounts.entries) {
    String prefix = mount.key;
    if (path.startsWith(prefix) ||
        (prefix.endsWith('/') &&
            path == prefix.substring(0, prefix.length - 1))) {
      mount.value(req).catchError((Object error, StackTrace stackTrace) {
        Dox().config.errorHandler(error, stackTrace);
      });
      return true;
    }
  }
  return false;
}

/// run middleware and controller, then send the result.
/// a plain value is sent at once. only a Future waits.
void _run(HttpRequest req, DoxRequest doxReq) {
  FutureOr<dynamic> result = runMiddlewareAndController(doxReq);
  if (result is Future<dynamic>) {
    result
        .then((dynamic value) {
          httpResponseHandler(value, req);
        })
        .onError((Object? error, StackTrace stackTrace) {
          httpErrorHandler(req, error, stackTrace);
        });
  } else {
    httpResponseHandler(result, req);
  }
}

Future<DoxRequest> getDoxRequest(HttpRequest req, RouteData route) async {
  return _doxRequest(req, route, await HttpBody.read(req));
}

DoxRequest _doxRequest(HttpRequest req, RouteData route, RequestBody body) {
  return DoxRequest(
    route: route,
    uri: req.uri,
    body: body.map,
    requestBody: body,
    contentType: req.headers.contentType,
    httpHeaders: req.headers,
    httpRequest: req,
    // the client ip needs a socket call, so it is read on first use only
    readClient: true,
  );
}
