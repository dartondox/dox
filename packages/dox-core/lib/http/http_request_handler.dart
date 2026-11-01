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
    if (path.startsWith(prefix) ||
        (prefix.endsWith('/') &&
            path == prefix.substring(0, prefix.length - 1))) {
      /// report the error and answer 500, so the client does not hang
      mount.value(req).catchError((Object error, StackTrace stackTrace) {
        httpErrorHandler(req, error, stackTrace);
      });
      return true;
    }
  }
  return false;
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
