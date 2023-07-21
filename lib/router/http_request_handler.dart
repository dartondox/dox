import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_response_handler.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/utils/utils.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
Future<void> httpRequestHandler(HttpRequest req) async {
  try {
    // preflight
    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.ok;
      await req.response.close();
      return;
    }

    String? domain = req.headers.value('host');

    /// getting matched route
    RouteData? route = _getMatchRoute(req.uri.path, req.method, domain);
    if (route == null) {
      await _routeNotFound(req);
      return;
    }

    /// convert http request into DoxRequest
    /// we did not use constructor here because we require
    /// async await to get body string from HttpRequest.
    DoxRequest doxReq = await DoxRequest.httpRequestToDoxRequest(req, route);

    /// route.controllers will be always list
    /// see Route()._addRoute() for explanation
    await _handleMiddlewareController(route, doxReq, req);
    return;
  } catch (error, stackTrace) {
    if (error is Exception || error is Error) {
      DoxLogger.warn(error);
      DoxLogger.danger(stackTrace.toString());
    }
    httpResponseHandler(error, req);
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

Future<void> _routeNotFound(HttpRequest req) async {
  req.response.write('${req.method} ${req.uri.path} not found');
  await req.response.close();
}

/// Handle middleware and controllers
Future<void> _handleMiddlewareController(
  RouteData route,
  DoxRequest doxReq,
  HttpRequest httpRequest,
) async {
  dynamic result;
  for (dynamic controller in route.controllers) {
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
      result = await Function.apply(middleware.handle, <dynamic>[doxReq]);
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
Future<void> _handleController(
  RouteData route,
  dynamic controller,
  DoxRequest doxRequest,
  HttpRequest httpRequest,
) async {
  dynamic result;

  List<dynamic> args = doxRequest.param.values
      .toList()
      .sublist(0, _lengthOfControllerArguments(controller) - 1);

  List<String> types = _getControllerArgumentDataTypes(controller);

  if (types.isNotEmpty) {
    String requestName = types.first;
    if (requestName != 'DoxRequest') {
      FormRequest? formReq = Global.ioc.getByName(requestName);
      if (formReq != null && _isFormRequestTypeMatched(controller, formReq)) {
        /// mapping request inputs field
        doxRequest.mapInputs(formReq.mapInputs());

        /// setting dox request to custom form request
        formReq.setRequest(doxRequest);

        /// validate request
        doxRequest.validate(
          formReq.rules(),
          messages: formReq.messages(),
        );

        /// run setup()
        formReq.setUp();

        result = await Function.apply(controller, <dynamic>[formReq, ...args]);
        httpResponseHandler(result, httpRequest);
        return;
      }
    }
  }

  result = await Function.apply(controller, <dynamic>[doxRequest, ...args]);
  httpResponseHandler(result, httpRequest);
}

/// checking that controller first request param is matched
/// with custom form request
bool _isFormRequestTypeMatched(dynamic controller, dynamic req) {
  List<String> args = _getControllerArgumentDataTypes(controller);
  return args[0].toString() == req.runtimeType.toString();
}

/// get controller arguments data type
/// eg. [DoxRequest, String]
List<String> _getControllerArgumentDataTypes(dynamic controller) {
  return controller.toString().split('(')[1].split(')')[0].split(', ');
}

/// get length controller arguments to check how many arguments
/// need to pass to the controller
int _lengthOfControllerArguments(dynamic controller) {
  List<String> args = _getControllerArgumentDataTypes(controller);
  return args.length;
}
