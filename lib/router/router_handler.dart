import 'dart:io';

import 'package:dox_core/dox_core.dart';

class RouteHandler {
  List<RouteData> get routes => Route().routes;

  dynamic handle(HttpRequest req) async {
    try {
      RouteData? route = getMatchRoute(req.uri.path, req.method);
      if (route == null) {
        return _routeNotFound(req);
      }
      var doxReq = await DoxRequest.httpRequestToDoxRequest(req, route);

      // if controller is a Function
      if (route.controllers is Function) {
        return await _handleController(route.controllers, doxReq, req);
      }

      // if list controller
      if (route.controllers is List) {
        return await _handleListController(route, doxReq, req);
      }

      return DoxResponse.send(route.controllers, req);
    } catch (error) {
      req.response.write(error.toString());
      req.response.close();
      print(error);
    }
  }

  Iterable<String> _getParameterNameFromRoute(RouteData route) {
    return route.path
        .split('/')
        .where((part) => part.startsWith('{') && part.endsWith('}'))
        .map((part) => part.substring(1, part.length - 1));
  }

  Iterable<RegExpMatch> _getPatternMatches(
    String input,
    RouteData route,
  ) {
    var pattern = RegExp(
        '^${route.path.replaceAllMapped(RegExp(r'{[^/]+}'), (match) => '([^/]+)').replaceAll('/', '\\/')}\$');
    return pattern.allMatches(input);
  }

  Map<String, dynamic> _getParameterMap(
    Iterable<RegExpMatch> matches,
    Iterable<String> parameterNames,
  ) {
    var match = matches.first;
    var parameterValues =
        match.groups(List<int>.generate(parameterNames.length, (i) => i + 1));
    return Map.fromIterables(parameterNames, parameterValues);
  }

  RouteData? getMatchRoute(String inputRoute, String method) {
    List<RouteData> methodMatchedRoutes = routes.where((route) {
      return route.method.toLowerCase() == method.toLowerCase();
    }).toList();

    RouteData? matchRoute;
    for (var route in methodMatchedRoutes) {
      route.path = Route.sanitizeRoutePath(route.path);
      inputRoute = Route.sanitizeRoutePath(inputRoute);

      /// when route is the same route exactly same route
      /// route without params, eg. /api/example
      if (route.path == inputRoute) {
        matchRoute = route;
        break;
      }

      /// when route have params
      /// eg. /api/admin/{adminId}
      var parameterNames = _getParameterNameFromRoute(route);
      var matches = _getPatternMatches(inputRoute, route);

      if (matches.isNotEmpty) {
        matchRoute = route;
        matchRoute.params = _getParameterMap(matches, parameterNames);
        break;
      }
    }
    return matchRoute;
  }

  _routeNotFound(HttpRequest req) {
    req.response.write('${req.method} ${req.uri.path} not found');
    return req.response.close();
  }

  Future _handleListController(
    RouteData route,
    DoxRequest doxReq,
    HttpRequest httpRequest,
  ) async {
    dynamic result;
    for (var controller in route.controllers) {
      if (controller is Function) {
        /// when it is a function and last item, it mean it is a controller
        if (controller == route.controllers.last) {
          return await _handleController(controller, doxReq, httpRequest);
        }
        result = await controller(doxReq);
      }

      // when controller is middleware
      if (controller is DoxMiddleware) {
        DoxMiddleware middleware = controller;
        result = await Function.apply(middleware.handle, [doxReq]);
      }

      /// if request is dox Request, it mean result is from middleware
      if (result is DoxRequest) {
        doxReq = result;
      } else {
        /// else result is from controller and ready to response
        DoxResponse.send(result, httpRequest);
        break;
      }
    }
  }

  Future _handleController(
    controller,
    DoxRequest doxRequest,
    HttpRequest httpRequest,
  ) async {
    List args = doxRequest.param.values.toList();
    var result = await Function.apply(controller, [doxRequest, ...args]);
    DoxResponse.send(result, httpRequest);
  }
}
