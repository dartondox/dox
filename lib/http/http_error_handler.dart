import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';

void httpErrorHandler(HttpRequest req, Object? error, StackTrace stackTrace) {
  if (error is Exception || error is Error) {
    Dox().config.errorHandler(error, stackTrace);
  }
  httpResponseHandler(error, req);
}
