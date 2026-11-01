import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_cors_handler.dart';
import 'package:dox_core/http/http_error_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/http_route_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/router/route_data.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
void httpRequestHandler(HttpRequest req) {
  try {
    /// raw handlers like Socket.IO. empty map when nothing is mounted.
    Map<String, RawRequestHandler> mounts = Route().mounts;
    if (mounts.isNotEmpty && _mounted(req, mounts)) return;

    RouteMatch? match = httpRouteHandler(req);
    if (match == null) return;
    RouteData route = match.route;
    Map<String, dynamic>? params = match.params;

    httpCorsHandler(route.corsEnabled, req);

    /// no Content-Type means no body to read. a body the native server
    /// already holds is read at once too. then the request is made with
    /// no Future in between. read the header once and pass it on.
    ContentType? contentType = req.headers.contentType;
    RequestBody? now = contentType == null
        ? RequestBody.empty()
        : HttpBody.readNow(req, contentType);
    if (now != null) {
      _run(req, _doxRequest(req, route, params, now, contentType));
    } else {
      HttpBody.read(req, contentType).then(
        (RequestBody body) {
          try {
            _run(req, _doxRequest(req, route, params, body, contentType));
          } catch (error, stackTrace) {
            httpErrorHandler(req, error, stackTrace);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          httpErrorHandler(req, error, stackTrace);
        },
      );
    }

    /// form data do not support isolate or multithread
  } catch (error, stackTrace) {
    httpErrorHandler(req, error, stackTrace);
  }
}

/// hand the request to a mounted handler. it writes the response itself.
bool _mounted(HttpRequest req, Map<String, RawRequestHandler> mounts) {
  String path = req.uri.path;
  for (MapEntry<String, RawRequestHandler> mount in mounts.entries) {
    String prefix = mount.key;
    if (!_underPrefix(path, prefix)) continue;
    if (Route().mountsWithMiddleware.contains(prefix)) {
      _runMount(req, prefix, mount.value);
      return true;
    }

    /// report the error and answer 500, so the client does not hang
    mount.value(req).catchError((Object error, StackTrace stackTrace) {
      httpErrorHandler(req, error, stackTrace);
    });
    return true;
  }
  return false;
}

/// true when [path] is [prefix] or a path under it. a trailing `/` on
/// the prefix does not matter: `/admin` and `/admin/` both match
/// `/admin`, `/admin/` and `/admin/users`, but never `/administrator`.
bool _underPrefix(String path, String prefix) {
  int end = prefix.endsWith('/') ? prefix.length - 1 : prefix.length;
  if (!path.startsWith(prefix.substring(0, end))) return false;
  return path.length == end || path.codeUnitAt(end) == 0x2F;
}

/// prefix => the route that runs the global middleware, then the raw
/// handler, with the handler and the middleware list it was made from.
/// made again when either one changes (a new mount, or
/// `Dox().initialize` with a new config).
final Map<String, (RawRequestHandler, List<dynamic>, RouteData)> _mountRoutes =
    <String, (RawRequestHandler, List<dynamic>, RouteData)>{};

/// what the mount route gives when the raw handler is done. the handler
/// wrote the answer itself, so nothing more is sent.
const Object _handled = Object();

/// run the global middleware, then the mount handler. a middleware that
/// gives a response sends it, and the handler never runs. the body is not
/// read here, so the handler can still read it. `terminate` steps run
/// once the answer is sent.
void _runMount(HttpRequest req, String prefix, RawRequestHandler handler) {
  List<dynamic> global = Dox().config.globalMiddleware;
  (RawRequestHandler, List<dynamic>, RouteData)? cached = _mountRoutes[prefix];
  RouteData route;
  if (cached != null &&
      identical(cached.$1, handler) &&
      identical(cached.$2, global)) {
    route = cached.$3;
  } else {
    route = _mountRoute(prefix, handler, global);
    _mountRoutes[prefix] = (handler, global, route);
  }
  DoxRequest doxReq = _doxRequest(
    req,
    route,
    null,
    RequestBody.empty(),
    req.headers.contentType,
  );
  List<IDoxTerminableMiddleware> ends = route.terminable;
  Future<dynamic>.sync(() => runMiddlewareAndController(doxReq)).then(
    (dynamic value) {
      /// a `next` middleware wraps the result in a DoxResponse
      bool sent =
          identical(value, _handled) ||
          (value is DoxResponse && identical(value.getContent(), _handled));
      if (sent) {
        value = null;
      } else {
        _send(req, value);
      }
      if (ends.isNotEmpty) _terminate(req, doxReq, value, ends);
    },
    onError: (Object error, StackTrace stackTrace) {
      if (ends.isEmpty) {
        httpErrorHandler(req, error, stackTrace);
        return;
      }
      dynamic value = renderError(req, error, stackTrace);
      _send(req, value);
      _terminate(req, doxReq, value, ends);
    },
  );
}

RouteData _mountRoute(
  String prefix,
  RawRequestHandler handler,
  List<dynamic> global,
) {
  return RouteData(
    method: '*',
    path: prefix,
    controllers: <dynamic>[
      ...global,
      (DoxRequest req) async {
        await handler(req.httpRequest);
        return _handled;
      },
    ],
    preMiddleware: List<dynamic>.unmodifiable(global),
  );
}

/// run middleware and controller, then send the result.
/// a plain value is sent at once. only a Future waits.
void _run(HttpRequest req, DoxRequest doxReq) {
  /// read once per route: most routes have no terminate step
  List<IDoxTerminableMiddleware> ends = doxReq.route.terminable;
  if (ends.isNotEmpty) {
    _runThenTerminate(req, doxReq, ends);
    return;
  }
  FutureOr<dynamic> result = runMiddlewareAndController(doxReq);
  if (result is Future<dynamic>) {
    /// one Future: `then` with `onError`, not `then().onError()`
    result.then(
      (dynamic value) {
        _send(req, value);
      },
      onError: (Object error, StackTrace stackTrace) {
        httpErrorHandler(req, error, stackTrace);
      },
    );
  } else {
    httpResponseHandler(result, req);
  }
}

/// like [_run], then call `terminate` of [ends] once the answer is sent
void _runThenTerminate(
  HttpRequest req,
  DoxRequest doxReq,
  List<IDoxTerminableMiddleware> ends,
) {
  Future<dynamic>.sync(() => runMiddlewareAndController(doxReq)).then(
    (dynamic value) {
      _send(req, value);
      _terminate(req, doxReq, value, ends);
    },
    onError: (Object error, StackTrace stackTrace) {
      dynamic value = renderError(req, error, stackTrace);
      _send(req, value);
      _terminate(req, doxReq, value, ends);
    },
  );
}

/// wait until the answer is sent, then run each `terminate`. an error
/// in one is reported, and the next one still runs.
Future<void> _terminate(
  HttpRequest req,
  DoxRequest doxReq,
  dynamic value,
  List<IDoxTerminableMiddleware> ends,
) async {
  HttpResponse res = req.response;
  try {
    await res.done;
  } catch (_) {
    /// the answer failed (eg. the client left). terminate still runs.
  }
  DoxResponse sent = asResponse(value).statusCode(res.statusCode);
  ExceptionHandler handler = Dox().config.exceptionHandler;
  for (IDoxTerminableMiddleware end in ends) {
    try {
      await end.terminate(doxReq, sent);
    } catch (error, stackTrace) {
      try {
        handler.report(error, stackTrace);
      } catch (_) {
        Logger.danger('terminate failed: $error\n$stackTrace');
      }
    }
  }
}

/// send the result. an error while sending gets the error response.
void _send(HttpRequest req, dynamic value) {
  try {
    httpResponseHandler(value, req);
  } catch (error, stackTrace) {
    httpErrorHandler(req, error, stackTrace);
  }
}

@Deprecated('Not used by Dox. Will be removed in 4.0.')
Future<DoxRequest> getDoxRequest(HttpRequest req, RouteData route) async {
  ContentType? contentType = req.headers.contentType;
  RequestBody body = await HttpBody.read(req, contentType);
  return _doxRequest(req, route, null, body, contentType);
}

DoxRequest _doxRequest(
  HttpRequest req,
  RouteData route,
  Map<String, dynamic>? params,
  RequestBody body,
  ContentType? contentType,
) {
  return DoxRequest(
    route: route,
    uri: req.uri,
    body: body.map,
    requestBody: body,
    contentType: contentType,
    httpHeaders: req.headers,
    httpRequest: req,
    params: params,
    // the client ip needs a socket call, so it is read on first use only
    readClient: true,
  );
}
