import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_error_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/http_route_handler.dart';
import 'package:dox_core/http/http_websocket_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:dox_core/router/route_data.dart';

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

    if (WebSocketTransformer.isUpgradeRequest(req)) {
      httpWebSocketHandler(req, route);
      return;
    }

    getDoxRequest(req, route)
        .then((DoxRequest doxReq) {
          middlewareAndControllerHandler(doxReq)
              .then((dynamic result) {
                httpResponseHandler(result, req);
              })
              .onError((Object? error, StackTrace stackTrace) {
                httpErrorHandler(req, error, stackTrace);
              });
        })
        .onError((Object? error, StackTrace stackTrace) {
          httpErrorHandler(req, error, stackTrace);
        });

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

Future<DoxRequest> getDoxRequest(HttpRequest req, RouteData route) async {
  String? address = req.connectionInfo?.remoteAddress.address;
  String? remote = address == null ? null : TrustedProxy.normalize(address);
  String? clientIp = remote;
  String scheme = 'http';
  TrustedProxy proxy = _trustedProxy();
  if (remote != null && proxy.enabled) {
    clientIp = proxy.clientIp(remote, req.headers.value('x-forwarded-for'));
    scheme = proxy.scheme(remote, req.headers.value('x-forwarded-proto'));
  }
  RequestBody body = await HttpBody.read(req);
  return DoxRequest(
    route: route,
    uri: req.uri,
    body: body.map,
    requestBody: body,
    contentType: req.headers.contentType,
    clientIp: clientIp,
    scheme: scheme,
    httpHeaders: req.headers,
    httpRequest: req,
  );
}

List<String>? _proxyList;
TrustedProxy _proxy = TrustedProxy(const <String>[]);

/// parse `trustedProxies` once per isolate, not on every request
TrustedProxy _trustedProxy() {
  List<String> list = Dox().config.trustedProxies;
  if (!identical(list, _proxyList)) {
    _proxy = TrustedProxy(list);
    _proxyList = list;
  }
  return _proxy;
}
