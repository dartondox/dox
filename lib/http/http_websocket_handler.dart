import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_controller_handler.dart';
import 'package:dox_core/http/http_error_handler.dart';
import 'package:dox_core/http/http_request_handler.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/router/route_data.dart';

void httpWebSocketHandler(HttpRequest req, RouteData route) {
  getDoxRequest(req, route).then((DoxRequest doxReq) {
    doxReq.setHttpRequest(req);
    middlewareAndControllerHandler(doxReq).then((dynamic result) {
      httpResponseHandler(result, req);
    }).onError((Object? error, StackTrace stackTrace) {
      httpErrorHandler(req, error, stackTrace);
    });
  }).onError((Object? error, StackTrace stackTrace) {
    httpErrorHandler(req, error, stackTrace);
  });
}
