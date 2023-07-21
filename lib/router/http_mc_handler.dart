import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

/// Handle middleware and controllers
Future<dynamic> handleMiddlewareAndController(
  RouteData route,
  DoxRequest doxReq,
) async {
  dynamic result;

  for (dynamic controller in route.controllers) {
    if (controller is Function) {
      /// when it is a function and last item, it mean it is a final controller
      if (controller == route.controllers.last) {
        return await _handleController(route, controller, doxReq);
      }

      /// this mean a function middleware
      /// since there is more functions in the `route.controllers`
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
      return result;
    }
  }
}

/// handle controller
Future<dynamic> _handleController(
  RouteData route,
  dynamic controller,
  DoxRequest doxRequest,
) async {
  dynamic result;

  /// controller arguments except first arguments
  List<dynamic> controllerArguments = doxRequest.param.values
      .toList()
      .sublist(0, _lengthOfControllerArguments(controller) - 1);

  /// controller argument data types
  List<String> controllerArgumentsDataType =
      _getControllerArgumentDataTypes(controller);

  /// if the first argument data type is not DoxRequest,
  /// controller request custom FormRequest class
  if (controllerArgumentsDataType.isNotEmpty) {
    String requestName = controllerArgumentsDataType.first;
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

        result = await Function.apply(
            controller, <dynamic>[formReq, ...controllerArguments]);
        return result;
      }
    }
  }

  return await Function.apply(
      controller, <dynamic>[doxRequest, ...controllerArguments]);
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
