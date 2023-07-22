import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/http_route_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/multi_thread/multi_thread.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/utils/logger.dart';

/// this is a class which get matched routes and
/// pass http request to route middleware and controllers
/// and response from controllers is passed to `httpResponseHandler`
Future<void> httpRequestHandler(HttpRequest req) async {
  try {
    // return 200 status on preflight
    if (req.method == 'OPTIONS') {
      await httpResponseHandler(null, req);
      return;
    }

    RouteData? route = await httpRouteHandler(req);
    if (route == null) return;

    bool isWebSocket = WebSocketTransformer.isUpgradeRequest(req);

    Map<String, dynamic> body = await HttpBody.read(req);

    DoxRequest doxReq = DoxRequest(
      route: route,
      uri: req.uri,
      body: body,
      contentType: req.headers.contentType,
      clientIp: req.connectionInfo?.remoteAddress.address,
      httpHeaders: req.headers,
    );

    /// form data do not support isolate or multithread
    if (HttpBody.isFormData(req.headers.contentType)) {
      dynamic result = await middlewareAndControllerHandler(route, doxReq);
      await httpResponseHandler(result, req);
      return;
    }

    /// websocket requests required http request and do not support isolate
    if (isWebSocket) {
      doxReq.setHttpRequest(req);
      dynamic result = await middlewareAndControllerHandler(route, doxReq);
      await httpResponseHandler(result, req);
      return;
    }

    DoxMultiThread().handleRequest(
      route,
      doxReq,
      (dynamic response) {
        httpResponseHandler(response, req);
      },
    );
  } catch (error, stackTrace) {
    if (error is Exception || error is Error) {
      DoxLogger.warn(error);
      DoxLogger.danger(stackTrace.toString());
    }
    await httpResponseHandler(error, req);
    return;
  }
}
