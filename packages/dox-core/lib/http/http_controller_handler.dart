import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

/// Handle middleware and controllers
Future<dynamic> middlewareAndControllerHandler(DoxRequest doxReq) async {
  dynamic result;
  RouteData route = doxReq.route;

  for (dynamic fn in route.controllers) {
    if (fn is Function) {
      /// when it is a function and last item int the list,
      /// it mean it is a final controller
      if (fn == route.controllers.last) {
        return await _handleController(route, fn, doxReq);
      }

      /// A function but not last item,
      /// it mean function base middleware which
      /// need to pass the result to next `fn`
      result = await fn(doxReq);
    }

    /// DoxMiddleware class
    /// with handle function
    if (fn is IDoxMiddleware) {
      result = await fn.handle(doxReq);
    }

    /// if result is dox Request, it mean result is from middleware
    /// and need to pass values to next controller.
    if (result is DoxRequest) {
      /// override doxReq from arguments in order to pass in the next loop
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
  dynamic fn,
  DoxRequest doxRequest,
) async {
  dynamic result;

  /// length of param arguments need to pass to controller
  /// -1 to remove do request
  int lengthOfParam = _lengthOfControllerArguments(fn) - 1;

  /// controller arguments except first arguments(doxRequest)
  /// param values from route `/user/{name}`
  List<dynamic> controllerArguments = doxRequest.param.values.isNotEmpty
      ? doxRequest.param.values.toList().sublist(0, lengthOfParam)
      : _generateEmptyArgumentValues(lengthOfParam);

  /// controller argument data types
  List<String> controllerArgumentsDataType =
      _getControllerArgumentDataTypes(fn);

  /// if the first argument data type is not DoxRequest,
  /// controller request custom FormRequest class
  if (controllerArgumentsDataType.isNotEmpty) {
    String requestName = controllerArgumentsDataType.first;
    if (requestName != 'DoxRequest') {
      FormRequest? formReq = Dox().ioc.getByName(requestName);
      if (formReq != null && _isFormRequestTypeMatched(fn, formReq)) {
        /// mapping request inputs field
        doxRequest.processInputMapper(formReq.mapInputs());

        /// setting dox request to custom form request
        formReq.setRequest(doxRequest);

        /// validate request
        doxRequest.validate(
          formReq.rules(),
          messages: formReq.messages(),
        );

        /// run setup()
        await formReq.setUp();

        result = await Function.apply(
            fn, <dynamic>[formReq, ...controllerArguments]);
        return result;
      }
    }
  }

  return await Function.apply(
      fn, <dynamic>[doxRequest, ...controllerArguments]);
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

List<String> _generateEmptyArgumentValues(int count) {
  List<String> ret = <String>[];
  for (int i = 0; i < count; i++) {
    ret.add('');
  }
  return ret;
}
