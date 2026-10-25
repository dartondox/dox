import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_error_handler.dart';
import 'package:dox_core/router/route_data.dart';

/// Handle middleware and controllers
Future<dynamic> middlewareAndControllerHandler(DoxRequest doxReq) async {
  return await runMiddlewareAndController(doxReq);
}

/// Run middleware and controllers. It stays sync while every step gives
/// a plain value, so a simple route needs no Future. At the first Future
/// it waits, then goes on with the next item.
FutureOr<dynamic> runMiddlewareAndController(DoxRequest doxReq) {
  /// a route with a `next` middleware takes the slower async chain.
  /// other routes never pay for it.
  if (doxReq.route.usesNext) return _chain(doxReq, 0);
  return _runFrom(doxReq, 0, null);
}

FutureOr<dynamic> _runFrom(DoxRequest doxReq, int start, dynamic result) {
  RouteData route = doxReq.route;
  List<dynamic> controllers = route.controllers;
  int last = controllers.length - 1;

  for (int i = start; i <= last; i++) {
    dynamic fn = controllers[i];
    if (fn is Function || fn is ControllerAction) {
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

/// Run the items from [start] for a route with a `next` middleware
/// ([IDoxNextMiddleware] or a [NextMiddlewareFunction]). Before-only
/// middleware run like in [_runFrom]. A next middleware gets a [Next]
/// that runs the items after it. The result is always a [DoxResponse],
/// so the middleware can change its status and headers. An error is
/// turned into its response here, so the middleware sees that too.
Future<DoxResponse> _chain(DoxRequest req, int start) async {
  try {
    RouteData route = req.route;
    List<dynamic> items = route.controllers;
    int last = items.length - 1;
    for (int i = start; i <= last; i++) {
      dynamic fn = items[i];
      int after = i + 1;
      dynamic result;
      if (fn is IDoxNextMiddleware) {
        DoxRequest current = req;
        result = await fn.handle(req, () => _chain(current, after));
        return asResponse(result);
      }
      if (i < last && fn is NextMiddlewareFunction) {
        DoxRequest current = req;
        result = await fn(req, () => _chain(current, after));
        return asResponse(result);
      }
      if (fn is Function || fn is ControllerAction) {
        if (i == last) return asResponse(await route.handler!.call(req));
        result = fn(req);
      } else if (fn is IDoxMiddleware) {
        result = fn.handle(req);
      }
      if (result is Future<dynamic>) result = await result;
      if (result is! DoxRequest) return asResponse(result);
      req = result;
    }
    return asResponse(null);
  } catch (error, stackTrace) {
    return asResponse(renderError(req.httpRequest, error, stackTrace));
  }
}

/// [value] as a [DoxResponse]. An http exception becomes its JSON body
/// with its status, so a middleware can still change the status.
DoxResponse asResponse(dynamic value) {
  if (value is DoxResponse) return value;
  if (value is IHttpException) {
    return DoxResponse(value.toResponse()).statusCode(value.code);
  }
  return DoxResponse(value);
}

/// What Dox gives to one parameter of a controller.
enum ArgKind { request, dto, path, bound, inject }

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
    this.value,
    this.type,
  });

  final ArgKind kind;

  /// the DTO, for [ArgKind.dto]
  final DtoSchema<Object>? dto;

  /// the type of a path param
  final PathType pathType;

  /// `int?`: the param may be missing (`{id?}`)
  final bool nullable;

  /// the name of the path param, also for [ArgKind.bound]
  final String param;

  /// [ArgKind.inject]: the instance from the container, made at start.
  /// null for a `singleton: false` class: then [type] is made each time.
  final Object? value;

  /// [ArgKind.inject]: the container type
  final Type? type;
}

/// One route param that a binder turns into a value before the
/// controller runs.
class RouteParamBinder {
  const RouteParamBinder(this.param, this.resolve);

  final String param;
  final RouteBinder<Object> resolve;
}

/// How to call one controller: what goes in each parameter.
///
/// It is made once per route, at start. Dox reads the parameter types
/// from the function type (no `dart:mirrors`), and finds DTOs in
/// `AppConfig(dtos: dtos)`. Each request only fills the list and calls
/// the function.
class ControllerPlan {
  ControllerPlan(
    this.fn,
    this.args, [
    this.binders = const <RouteParamBinder>[],
  ]);

  final Function fn;
  final List<ControllerArg> args;

  /// route params with a binder (`Route.bind`, or a `@DoxModel` from the
  /// container). resolved before [fn] runs.
  final List<RouteParamBinder> binders;

  /// the names of the params in [binders]
  List<String> get bindings {
    return <String>[for (RouteParamBinder b in binders) b.param];
  }

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
    IocContainer ioc = Dox().ioc;
    Map<String, RouteBinding> explicit = Route().bindings;
    List<RouteParamBinder> binders = <RouteParamBinder>[
      for (String param in route.paramNames)
        if (explicit.containsKey(param))
          RouteParamBinder(param, explicit[param]!.resolve),
    ];
    // a parameter of a bound type takes its param, the others take the
    // rest of the params in order
    Map<int, String> boundArgs = <int, String>{};
    for (int i = 0; i < types.length; i++) {
      String name = _withoutNull(types[i]);
      for (RouteParamBinder binder in binders) {
        String param = binder.param;
        if (explicit[param]!.type == name && !boundArgs.containsValue(param)) {
          boundArgs[i] = param;
          break;
        }
      }
    }
    // a parameter of a @DoxModel type takes the param with its name
    // (`{user}` for `User`), else the next param in order
    Map<int, RouteBinder<Object>> models = <int, RouteBinder<Object>>{};
    for (int i = 0; i < types.length; i++) {
      if (boundArgs.containsKey(i)) continue;
      String name = _withoutNull(types[i]);
      if (_pathTypes.containsKey(name) || name == 'dynamic') continue;
      RouteBinder<Object>? find = ioc.modelBinderNamed(name);
      if (find == null) continue;
      models[i] = find;
      String param = name[0].toLowerCase() + name.substring(1);
      if (route.paramNames.contains(param) &&
          !explicit.containsKey(param) &&
          !boundArgs.containsValue(param)) {
        boundArgs[i] = param;
        binders.add(RouteParamBinder(param, find));
      }
    }
    List<String> params = <String>[
      for (String param in route.paramNames)
        if (!boundArgs.containsValue(param)) param,
    ];
    List<ControllerArg> args = <ControllerArg>[];
    int paths = 0;
    bool hasDto = false;
    for (int i = 0; i < types.length; i++) {
      String type = types[i];
      bool nullable = type.endsWith('?');
      String name = _withoutNull(type);
      String? boundParam = boundArgs[i];
      if (boundParam != null) {
        args.add(ControllerArg(ArgKind.bound, param: boundParam));
        continue;
      }
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
      RouteBinder<Object>? model = models[i];
      if (pathType != null || model != null) {
        if (paths >= params.length) {
          throw StateError(
            'Route $where: the controller has more path params than the '
            'route has {...} params (${params.length}).',
          );
        }
        String param = params[paths++];
        if (model != null) {
          if (!explicit.containsKey(param)) {
            binders.add(RouteParamBinder(param, model));
          }
          args.add(ControllerArg(ArgKind.bound, param: param));
          continue;
        }
        args.add(
          ControllerArg(
            ArgKind.path,
            pathType: pathType!,
            nullable: nullable || name == 'dynamic',
            param: param,
          ),
        );
        continue;
      }
      DtoSchema<Object>? dto = Dox().dtos.ofName(name);
      if (dto != null) {
        if (hasDto) {
          throw StateError(
            'Route $where: a controller can have one @Dto only.',
          );
        }
        hasDto = true;
        args.add(ControllerArg(ArgKind.dto, dto: dto));
        continue;
      }
      Type? injected = ioc.typeNamed(name);
      if (injected != null) {
        args.add(
          ControllerArg(
            ArgKind.inject,
            type: injected,
            value: ioc.isShared(injected) ? ioc.getByType(injected) : null,
          ),
        );
        continue;
      }
      throw StateError(
        'Route $where: the controller parameter type $type is not known. '
        'Use DoxRequest, a @Dto class, an @Inject class, a @DoxModel, a '
        'type from Route.bind, or String, int, double, num, bool for path '
        'params. Did you run `dart run build_runner build` and set '
        '`dtos: dtos` and `container: registerContainer` in AppConfig?',
      );
    }
    return ControllerPlan(fn, args, binders);
  }

  static String _withoutNull(String type) {
    return type.endsWith('?') ? type.substring(0, type.length - 1) : type;
  }

  /// Fill the parameters for [req] and call the controller.
  /// A path param that does not fit its type answers 404.
  /// Without a DTO or a binder it is sync and gives what the controller
  /// gives.
  FutureOr<dynamic> call(DoxRequest req) {
    if (binders.isNotEmpty) return _bindThenCall(req);
    return _call(req);
  }

  /// run the binders of the route, then the controller.
  /// a binder that gives null answers 404.
  Future<dynamic> _bindThenCall(DoxRequest req) async {
    for (RouteParamBinder binder in binders) {
      Object? raw = req.param[binder.param];
      if (raw == null) continue; // an optional `{param?}` that is not set
      Object? value = await binder.resolve('$raw');
      if (value == null) throw NotFoundHttpException();
      req.boundValues[binder.param] = value;
    }
    return await _call(req);
  }

  FutureOr<dynamic> _call(DoxRequest req) {
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
        case ArgKind.bound:
          values[i] = req.boundValues[arg.param];
        case ArgKind.inject:
          values[i] = arg.value ?? Dox().ioc.getByType(arg.type!);
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

  /// For a function like `(UserController c) => c.index`, the method it
  /// picks, with the controller from [ioc]. Null for a normal controller.
  /// Dox sees it from the type: the function gives a function.
  static Function? select(Function fn, IocContainer ioc, String where) {
    String text = fn.runtimeType.toString();
    int start = text.indexOf('(');
    int end = _closing(text, start);
    if (start != 0 || end < 0) return null;
    String result = text.substring(end + 1).trim();
    if (!result.startsWith('=>')) return null;
    result = result.substring(2).trim();
    if (!result.startsWith('(') && !result.startsWith('<')) return null;
    List<String> types = parameters(fn, where);
    Type? type = types.length == 1 ? ioc.typeNamed(types.first) : null;
    if (type == null) {
      throw StateError(
        'Route $where: the action gives a function. Give it one '
        'controller parameter from the container, like '
        '(UserController c) => c.index. Is the controller class marked '
        'with @Inject()?',
      );
    }
    Object? method = (fn as dynamic)(ioc.getByType(type));
    return method as Function;
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
