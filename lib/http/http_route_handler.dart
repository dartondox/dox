import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/utils.dart';

Future<RouteData?> httpRouteHandler(HttpRequest req) async {
  RouteData? route = _getMatchRoute(
    req.uri.path,
    req.method,
    req.headers.value(HttpHeaders.hostHeader),
  );

  if (route == null) {
    req.response.statusCode = HttpStatus.notFound;
    await httpResponseHandler('${req.method} ${req.uri.path} not found', req);
  }
  return route;
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
