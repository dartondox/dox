import 'dart:io';

import 'package:dox_core/constants/http_request_method.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/utils.dart';

RouteData? httpRouteHandler(HttpRequest req) {
  RouteData? route = _getMatchRoute(
    req.uri.path,
    req.method,
    req.headers.value(HttpHeaders.hostHeader),
  );

  if (route == null) {
    /// answer preflight OPTIONS with 204 and cors headers.
    /// use cors setting of the route the browser is asking about.
    if (req.method == HttpRequestMethod.OPTIONS.name) {
      RouteData? target = _getMatchRoute(
        req.uri.path,
        req.headers.value('access-control-request-method') ?? '',
        req.headers.value(HttpHeaders.hostHeader),
      );
      httpCorsHandler(target?.corsEnabled, req);
      req.response.statusCode = HttpStatus.noContent;
      responseDataHandler(null, req);
    } else {
      req.response.statusCode = HttpStatus.notFound;
      responseDataHandler('${req.method} ${req.uri.path} not found', req);
    }
  }
  return route;
}

/// routes grouped by method, rebuilt when the route list changes.
/// keeps the registration order, so the first match still wins.
Map<String, List<RouteData>> _byMethod = <String, List<RouteData>>{};
List<RouteData>? _indexedList;
int _indexedLength = -1;

Map<String, List<RouteData>> _routeIndex() {
  List<RouteData> routes = Route().routes;
  if (!identical(routes, _indexedList) || routes.length != _indexedLength) {
    Map<String, List<RouteData>> index = <String, List<RouteData>>{};
    for (RouteData route in routes) {
      route.path = sanitizeRoutePath(route.path);
      (index[route.method.toUpperCase()] ??= <RouteData>[]).add(route);
    }
    _byMethod = index;
    _indexedList = routes;
    _indexedLength = routes.length;
  }
  return _byMethod;
}

/// get matched route from the list
/// method, domain, path
RouteData? _getMatchRoute(String inputRoute, String method, String? domain) {
  List<RouteData>? candidates = _routeIndex()[method.toUpperCase()];
  if (candidates == null) return null;

  inputRoute = sanitizeRoutePath(inputRoute).trim();
  String? host = domain?.toLowerCase();

  for (RouteData route in candidates) {
    if (host != null &&
        route.domain != null &&
        route.domain!.toLowerCase() != host) {
      continue;
    }

    /// route without params, eg. /api/example
    RegExp? pattern = route.pattern;
    if (pattern == null) {
      if (route.path.trim() == inputRoute) return route;
      continue;
    }

    /// when route have params
    /// eg. /api/admin/{adminId}
    RegExpMatch? match = pattern.firstMatch(inputRoute);
    if (match != null) {
      List<String> names = route.paramNames;
      Map<String, dynamic> params = <String, dynamic>{};
      for (int i = 0; i < names.length; i++) {
        params[names[i]] = match.group(i + 1);
      }
      return route.withParams(params);
    }
  }
  return null;
}
