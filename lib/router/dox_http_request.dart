import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/utils/utils.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `RouterResponse.send`
class DoxHttpRequest {
  dynamic handle(HttpRequest req) async {
    try {
      // preflight
      if (req.method == 'OPTIONS') {
        req.response.statusCode = HttpStatus.ok;
        return req.response.close();
      }

      /// getting matched route
      RouteData? route = _getMatchRoute(req.uri.path, req.method);
      if (route == null) {
        return _routeNotFound(req);
      }

      /// convert http request into DoxRequest
      /// we did not use constructor here because we require
      /// async await to get body string from HttpRequest.
      var doxReq = await DoxRequest.httpRequestToDoxRequest(req, route);

      /// route.controllers will be always list
      /// see Route()._addRoute() for explanation
      return await _handleListController(route, doxReq, req);
    } catch (error, stackTrace) {
      if (error is Exception || error is Error) {
        DoxLogger.warn(error);
        DoxLogger.danger(stackTrace.toString());
      }
      return RouterResponse.send(error, req);
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

  RouteData? _getMatchRoute(String inputRoute, String method) {
    List<RouteData> methodMatchedRoutes = Route().routes.where((route) {
      return route.method.toLowerCase() == method.toLowerCase();
    }).toList();

    RouteData? matchRoute;
    for (var route in methodMatchedRoutes) {
      route.path = sanitizeRoutePath(route.path);
      inputRoute = sanitizeRoutePath(inputRoute);

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
        /// when it is a function and last item, it mean it is a final controller
        if (controller == route.controllers.last) {
          await _handleController(route, controller, doxReq, httpRequest);

          /// end the loop
          break;
        }

        /// this mean a function middleware
        result = await controller(doxReq);
      }

      /// this mean a dox base class middleware
      /// where it have handle function
      if (controller is DoxMiddleware) {
        DoxMiddleware middleware = controller;
        result = await Function.apply(middleware.handle, [doxReq]);
      }

      /// if request is dox Request, it mean result is from middleware
      /// mean need to pass values to next controller.
      if (result is DoxRequest) {
        /// override doxReq from arguments and
        /// in order to pass in next loop
        doxReq = result;
      } else {
        /// else result is from controller and ready to response
        RouterResponse.send(result, httpRequest);
        break;
      }
    }
  }

  Future _handleController(
    RouteData route,
    controller,
    DoxRequest doxRequest,
    HttpRequest httpRequest,
  ) async {
    dynamic result;
    List args = doxRequest.param.values.toList();
    FormRequest Function()? creator = route.formRequest;

    if (creator != null) {
      FormRequest formReq = creator();

      /// mapping request inputs field
      doxRequest.mapInputs(formReq.mapInputs());

      /// setting dox request to custom form request
      formReq.setRequest(doxRequest);

      /// run setup();
      formReq.setUp();

      /// finally validate;
      doxRequest.validate(
        formReq.rules(),
        messages: formReq.messages(),
      );

      if (formReq.useAsControllerRequest) {
        result = await Function.apply(controller, [formReq, ...args]);
        RouterResponse.send(result, httpRequest);
        return;
      }
    }

    result = await Function.apply(controller, [doxRequest, ...args]);
    RouterResponse.send(result, httpRequest);
  }
}
