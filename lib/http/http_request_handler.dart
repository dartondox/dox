import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/multi_thread/multi_thread.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/utils/utils.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
Future<void> httpRequestHandler(HttpRequest req) async {
  try {
    // return 200 status on preflight
    if (req.method == 'OPTIONS') {
      await httpResponseHandler(null, req);
      return;
    }

    /// getting matched route
    /// by checking with path, method, and host/domain
    RouteData? route = _getMatchRoute(
      req.uri.path,
      req.method,
      req.headers.value(HttpHeaders.hostHeader),
    );

    if (route == null) {
      await httpResponseHandler('${req.method} ${req.uri.path} not found', req);
      return;
    }

    bool isWebSocket = WebSocketTransformer.isUpgradeRequest(req);

    Map<String, dynamic> body = await HttpBody.read(req);

    DoxRequest doxReq = DoxRequest(
      route: route,
      uri: req.uri,
      body: body,
      contentType: req.headers.contentType,
      clientIp: req.connectionInfo?.remoteAddress.address,
      httpHeaders: req.headers,
    );

    /// form data do not support isolate or multithread
    if (HttpBody.isFormData(req.headers.contentType)) {
      dynamic result = await middlewareAndControllerHandler(route, doxReq);
      await httpResponseHandler(result, req);
      return;
    }

    /// websocket requests required http request and do not support isolate
    if (isWebSocket) {
      doxReq.setHttpRequest(req);
      dynamic result = await middlewareAndControllerHandler(route, doxReq);
      await httpResponseHandler(result, req);
      return;
    }

    DoxMultiThread().handleRequest(
      route,
      doxReq,
      (dynamic response) {
        httpResponseHandler(response, req);
      },
    );
  } catch (error, stackTrace) {
    if (error is Exception || error is Error) {
      DoxLogger.warn(error);
      DoxLogger.danger(stackTrace.toString());
    }
    await httpResponseHandler(error, req);
    return;
  }
}

/// get matched route from the list
/// method, domain, path
RouteData? _getMatchRoute(String inputRoute, String method, String? domain) {
  List<RouteData> methodMatchedRoutes = Route().routes.where((RouteData route) {
    if (domain != null && route.domain != null) {
      return route.method.toLowerCase() == method.toLowerCase() &&
          route.domain?.toLowerCase() == domain.toLowerCase();
    } else {
      return route.method.toLowerCase() == method.toLowerCase();
    }
  }).toList();

  RouteData? matchRoute;
  for (RouteData route in methodMatchedRoutes) {
    route.path = sanitizeRoutePath(route.path);
    inputRoute = sanitizeRoutePath(inputRoute);

    /// When route is the same route exactly same route.
    /// route without params, eg. /api/example
    if (route.path.trim() == inputRoute.trim()) {
      matchRoute = route;
      break;
    }

    /// when route have params
    /// eg. /api/admin/{adminId}
    Iterable<String> parameterNames = _getParameterNameFromRoute(route);
    Iterable<RegExpMatch> matches = _getPatternMatches(inputRoute, route);

    if (matches.isNotEmpty) {
      matchRoute = route;
      matchRoute.params = _getParameterAsMap(matches, parameterNames);
      break;
    }
  }
  return matchRoute;
}

/// get parameter name from named route eg. /blog/{id}
/// eg ('id')
Iterable<String> _getParameterNameFromRoute(RouteData route) {
  return route.path
      .split('/')
      .where((String part) => part.startsWith('{') && part.endsWith('}'))
      .map((String part) => part.substring(1, part.length - 1));
}

/// get pattern matched routes from the list
Iterable<RegExpMatch> _getPatternMatches(
  String input,
  RouteData route,
) {
  RegExp pattern = RegExp(
      '^${route.path.replaceAllMapped(RegExp(r'{[^/]+}'), (Match match) => '([^/]+)').replaceAll('/', '\\/')}\$');
  return pattern.allMatches(input);
}

/// get the param from the named route as Map response
/// eg {'id' : 1}
Map<String, dynamic> _getParameterAsMap(
  Iterable<RegExpMatch> matches,
  Iterable<String> parameterNames,
) {
  RegExpMatch match = matches.first;
  List<String?> parameterValues =
      match.groups(List<int>.generate(parameterNames.length, (int i) => i + 1));
  return Map<String, dynamic>.fromIterables(parameterNames, parameterValues);
}
