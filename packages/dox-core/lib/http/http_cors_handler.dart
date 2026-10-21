import 'dart:io';

import 'package:dox_core/dox_core.dart';

void httpCorsHandler(bool? enabled, HttpRequest req) {
  CORSConfig cors = Dox().config.cors;
  if (!(enabled ?? cors.enabled)) return;
  HttpResponse res = req.response;

  /// call each one directly, no map per request.
  /// null values are skipped inside `_setCorsValue`.
  _setCorsValue(res, HttpHeaders.accessControlAllowOriginHeader, cors.origin);
  _setCorsValue(res, HttpHeaders.accessControlAllowMethodsHeader, cors.methods);
  _setCorsValue(res, HttpHeaders.accessControlAllowHeadersHeader, cors.headers);
  _setCorsValue(
    res,
    HttpHeaders.accessControlExposeHeadersHeader,
    cors.exposeHeaders,
  );
  _setCorsValue(
    res,
    HttpHeaders.accessControlAllowCredentialsHeader,
    cors.credentials,
  );
  _setCorsValue(res, HttpHeaders.accessControlMaxAgeHeader, cors.maxAge);
}

// set cors in header
void _setCorsValue(HttpResponse res, String key, dynamic data) {
  if (data == null) {
    return;
  }

  /// when data is list of string, eg. ['GET', 'POST']
  if (data is List<String> && data.isNotEmpty) {
    res.headers.add(key, data.join(','));
    return;
  }

  /// when data is string, eg. 'GET'
  if (data is String && data.isNotEmpty) {
    res.headers.add(key, data);
    return;
  }

  /// when data is other type and has value, just convert to string
  if (data != null) {
    res.headers.add(key, data.toString());
  }
}
