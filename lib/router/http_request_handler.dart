import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_response_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/utils/utils.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
dynamic httpRequestHandler(HttpRequest req) async {
  try {
    // preflight
    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.ok;
      return req.response.close();
    }

    String? domain = req.headers.value('host');

    /// getting matched route
    RouteData? route = _getMatchRoute(req.uri.path, req.method, domain);
    if (route == null) {
      return _routeNotFound(req);
    }

    /// convert http request into DoxRequest
    /// we did not use constructor here because we require
    /// async await to get body string from HttpRequest.
    var doxReq = await DoxRequest.httpRequestToDoxRequest(req, route);

    /// route.controllers will be always list
    /// see Route()._addRoute() for explanation
    return await _handleMiddlewareController(route, doxReq, req);
  } catch (error, stackTrace) {
    if (error is Exception || error is Error) {
      DoxLogger.warn(error);
      DoxLogger.danger(stackTrace.toString());
    }
    return httpResponseHandler(error, req);
  }
}

/// get matched route from the list
/// method, domain, path
RouteData? _getMatchRoute(String inputRoute, String method, String? domain) {
  List<RouteData> methodMatchedRoutes = Route().routes.where((route) {
    if (domain != null && route.domain != null) {
      return route.method.toLowerCase() == method.toLowerCase() &&
          route.domain?.toLowerCase() == domain.toLowerCase();
    } else {
      return route.method.toLowerCase() == method.toLowerCase();
    }
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
      .where((part) => part.startsWith('{') && part.endsWith('}'))
      .map((part) => part.substring(1, part.length - 1));
}

/// get pattern matched routes from the list
Iterable<RegExpMatch> _getPatternMatches(
  String input,
  RouteData route,
) {
  var pattern = RegExp(
      '^${route.path.replaceAllMapped(RegExp(r'{[^/]+}'), (match) => '([^/]+)').replaceAll('/', '\\/')}\$');
  return pattern.allMatches(input);
}

/// get the param from the named route as Map response
/// eg {'id' : 1}
Map<String, dynamic> _getParameterAsMap(
  Iterable<RegExpMatch> matches,
  Iterable<String> parameterNames,
) {
  var match = matches.first;
  var parameterValues =
      match.groups(List<int>.generate(parameterNames.length, (i) => i + 1));
  return Map.fromIterables(parameterNames, parameterValues);
}

_routeNotFound(HttpRequest req) {
  req.response.write('${req.method} ${req.uri.path} not found');
  return req.response.close();
}

/// Handle middleware and controllers
Future _handleMiddlewareController(
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
      httpResponseHandler(result, httpRequest);
      break;
    }
  }
}

/// handle controller
Future _handleController(
  RouteData route,
  controller,
  DoxRequest doxRequest,
  HttpRequest httpRequest,
) async {
  dynamic result;

  List args = doxRequest.param.values
      .toList()
      .sublist(0, _lengthOfControllerArguments(controller) - 1);

  List types = _getControllerArgumentDataTypes(controller);

  if (types.isNotEmpty) {
    String requestName = types.first;
    if (requestName != 'DoxRequest') {
      FormRequest? formReq = Global.ioc.getByName(requestName);
      if (formReq != null && _isFormRequestTypeMatched(controller, formReq)) {
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

        result = await Function.apply(controller, [formReq, ...args]);
        httpResponseHandler(result, httpRequest);
        return;
      }
    }
  }

  result = await Function.apply(controller, [doxRequest, ...args]);
  httpResponseHandler(result, httpRequest);
}

/// checking that controller first request param is matched
/// with custom form request
bool _isFormRequestTypeMatched(controller, req) {
  List args = _getControllerArgumentDataTypes(controller);
  return args[0].toString() == req.runtimeType.toString();
}

/// get controller arguments data type
/// eg. [DoxRequest, String]
List _getControllerArgumentDataTypes(controller) {
  return controller.toString().split('(')[1].split(')')[0].split(', ');
}

/// get length controller arguments to check how many arguments
/// need to pass to the controller
_lengthOfControllerArguments(controller) {
  List args = _getControllerArgumentDataTypes(controller);
  return args.length;
}
