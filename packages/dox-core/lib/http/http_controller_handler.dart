import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

/// Handle middleware and controllers
Future<dynamic> middlewareAndControllerHandler(DoxRequest doxReq) async {
  return await runMiddlewareAndController(doxReq);
}

/// Run middleware and controllers. It stays sync while every step gives
/// a plain value, so a simple route needs no Future. At the first Future
/// it waits, then goes on with the next item.
FutureOr<dynamic> runMiddlewareAndController(DoxRequest doxReq) {
  return _runFrom(doxReq, 0, null);
}

FutureOr<dynamic> _runFrom(DoxRequest doxReq, int start, dynamic result) {
  RouteData route = doxReq.route;
  List<dynamic> controllers = route.controllers;
  int last = controllers.length - 1;

  for (int i = start; i <= last; i++) {
    dynamic fn = controllers[i];
    if (fn is Function) {
      /// the last function is the controller
      if (i == last) return route.handler!.call(doxReq);

      /// a function before it is a middleware, which gives the request
      /// (to go on) or a response
      result = fn(doxReq);
    } else if (fn is IDoxMiddleware) {
      /// DoxMiddleware class with handle function
      result = fn.handle(doxReq);
    }

    if (result is Future<dynamic>) return _resume(result, i + 1);

    /// a request from a middleware goes on to the next item,
    /// anything else is the response
    if (result is DoxRequest) {
      doxReq = result;
    } else {
      return result;
    }
  }
  return null;
}

/// wait for a middleware Future, then go on from item [next]
Future<dynamic> _resume(Future<dynamic> pending, int next) async {
  dynamic result = await pending;
  if (result is DoxRequest) return await _runFrom(result, next, result);
  return result;
}

/// What Dox gives to one parameter of a controller.
enum ArgKind { request, dto, path }

/// The type of a path param parameter.
enum PathType { string, integer, decimal, number, boolean }

/// One parameter of a controller.
class ControllerArg {
  const ControllerArg(
    this.kind, {
    this.dto,
    this.pathType = PathType.string,
    this.nullable = false,
    this.param = '',
  });

  final ArgKind kind;

  /// the DTO, for [ArgKind.dto]
  final DtoSchema<Object>? dto;

  /// the type of a path param
  final PathType pathType;

  /// `int?`: the param may be missing (`{id?}`)
  final bool nullable;

  /// the name of the path param
  final String param;
}

/// How to call one controller: what goes in each parameter.
///
/// It is made once per route, at start. Dox reads the parameter types
/// from the function type (no `dart:mirrors`), and finds DTOs in
/// `AppConfig(dtos: dtos)`. Each request only fills the list and calls
/// the function.
class ControllerPlan {
  ControllerPlan(this.fn, this.args);

  final Function fn;
  final List<ControllerArg> args;

  static const Map<String, PathType> _pathTypes = <String, PathType>{
    'String': PathType.string,
    'int': PathType.integer,
    'double': PathType.decimal,
    'num': PathType.number,
    'bool': PathType.boolean,
  };

  /// The plan for [fn] on [route]. Throws a [StateError] when a
  /// parameter type is not known.
  static ControllerPlan of(Function fn, RouteData route) {
    String where = '${route.method} ${route.path}';
    List<String> types = ControllerTypes.parameters(fn, where);
    List<String> params = route.paramNames;
    List<ControllerArg> args = <ControllerArg>[];
    int paths = 0;
    bool hasDto = false;
    for (int i = 0; i < types.length; i++) {
      String type = types[i];
      bool nullable = type.endsWith('?');
      String name = nullable ? type.substring(0, type.length - 1) : type;
      if (name == 'DoxRequest' || name == 'IDoxRequest') {
        args.add(const ControllerArg(ArgKind.request));
        continue;
      }
      // an untyped first parameter `(req)` is the request
      if (name == 'dynamic' && i == 0 && !types.contains('DoxRequest')) {
        args.add(const ControllerArg(ArgKind.request));
        continue;
      }
      PathType? pathType = name == 'dynamic' || name == 'Object'
          ? PathType.string
          : _pathTypes[name];
      if (pathType != null) {
        if (paths >= params.length) {
          throw StateError(
            'Route $where: the controller has more path params than the '
            'route has {...} params (${params.length}).',
          );
        }
        args.add(
          ControllerArg(
            ArgKind.path,
            pathType: pathType,
            nullable: nullable || name == 'dynamic',
            param: params[paths++],
          ),
        );
        continue;
      }
      DtoSchema<Object>? dto = Dox().dtos.ofName(name);
      if (dto == null) {
        throw StateError(
          'Route $where: the controller parameter type $type is not known. '
          'Use DoxRequest, a @Dto class, or String, int, double, num, bool '
          'for path params. For a DTO: did you run '
          '`dart run build_runner build` and set `dtos: dtos` in AppConfig?',
        );
      }
      if (hasDto) {
        throw StateError('Route $where: a controller can have one @Dto only.');
      }
      hasDto = true;
      args.add(ControllerArg(ArgKind.dto, dto: dto));
    }
    return ControllerPlan(fn, args);
  }

  /// Fill the parameters for [req] and call the controller.
  /// A path param that does not fit its type answers 404.
  /// Without a DTO it is sync and gives what the controller gives.
  FutureOr<dynamic> call(DoxRequest req) {
    int count = args.length;
    if (count == 1 && args[0].kind == ArgKind.request) {
      return fn(req);
    }
    List<dynamic> values = List<dynamic>.filled(count, null);
    ControllerArg? dtoArg;
    int dtoIndex = -1;
    for (int i = 0; i < count; i++) {
      ControllerArg arg = args[i];
      switch (arg.kind) {
        case ArgKind.request:
          values[i] = req;
        case ArgKind.path:
          values[i] = _path(arg, req.param[arg.param]);
        case ArgKind.dto:
          dtoArg = arg;
          dtoIndex = i;
      }
    }
    // path params first: when one is wrong, the DTO is not checked
    if (dtoArg != null) return _callWithDto(req, dtoArg, dtoIndex, values);
    return _apply(values);
  }

  Future<dynamic> _callWithDto(
    DoxRequest req,
    ControllerArg dtoArg,
    int dtoIndex,
    List<dynamic> values,
  ) async {
    values[dtoIndex] = await Dox().validator.validateDto(req, dtoArg.dto!);
    return _apply(values);
  }

  dynamic _apply(List<dynamic> values) {
    switch (values.length) {
      case 0:
        return fn();
      case 1:
        return fn(values[0]);
      case 2:
        return fn(values[0], values[1]);
      case 3:
        return fn(values[0], values[1], values[2]);
      case 4:
        return fn(values[0], values[1], values[2], values[3]);
    }
    return Function.apply(fn, values);
  }

  Object? _path(ControllerArg arg, Object? raw) {
    if (raw == null) {
      if (arg.nullable) return null;
      throw NotFoundHttpException();
    }
    String text = '$raw';
    switch (arg.pathType) {
      case PathType.string:
        return text;
      case PathType.integer:
        int? value = int.tryParse(text, radix: 10);
        if (value != null) return value;
      case PathType.decimal:
        double? value = double.tryParse(text);
        if (value != null && value.isFinite) return value;
      case PathType.number:
        num? value = int.tryParse(text, radix: 10) ?? double.tryParse(text);
        if (value != null && value.isFinite) return value;
      case PathType.boolean:
        if (text == 'true' || text == '1') return true;
        if (text == 'false' || text == '0') return false;
    }
    throw NotFoundHttpException();
  }
}

/// Reads the parameter types of a function from its runtime type,
/// like `(DoxRequest, int) => Future<User>`.
class ControllerTypes {
  const ControllerTypes._();

  /// The type names of the positional parameters of [fn].
  static List<String> parameters(Function fn, String where) {
    String text = fn.runtimeType.toString();
    if (text.startsWith('<')) {
      throw StateError('Route $where: a controller can not be generic.');
    }
    int start = text.indexOf('(');
    int end = _closing(text, start);
    if (start < 0 || end < 0) {
      throw StateError('Route $where: can not read the controller type $text.');
    }
    String inside = text.substring(start + 1, end).trim();
    if (inside.isEmpty) return <String>[];
    if (inside.contains('{') || inside.contains('[')) {
      throw StateError(
        'Route $where: only positional parameters are supported, '
        'not named or [optional] ones ($text).',
      );
    }
    return _split(inside);
  }

  static int _closing(String text, int start) {
    int depth = 0;
    for (int i = start; i >= 0 && i < text.length; i++) {
      String char = text[i];
      if (char == '(' || char == '<') depth++;
      if (char == ')' || char == '>') {
        // `=>` is not a closing bracket
        if (char == '>' && i > 0 && text[i - 1] == '=') continue;
        depth--;
        if (depth == 0 && char == ')') return i;
      }
    }
    return -1;
  }

  static List<String> _split(String text) {
    List<String> parts = <String>[];
    int depth = 0;
    int from = 0;
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      if (char == '<' || char == '(') depth++;
      if (char == '>' || char == ')') depth--;
      if (char == ',' && depth == 0) {
        parts.add(text.substring(from, i).trim());
        from = i + 1;
      }
    }
    parts.add(text.substring(from).trim());
    return parts;
  }
}
