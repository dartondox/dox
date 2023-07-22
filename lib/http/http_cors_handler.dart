import 'dart:io';

import 'package:dox_core/dox_core.dart';

void httpCorsHandler(HttpRequest req) {
  CORSConfig cors = Dox().config.cors;

  Map<String, dynamic> headers = <String, dynamic>{
    HttpHeaders.accessControlAllowOriginHeader: cors.allowOrigin,
    HttpHeaders.accessControlAllowMethodsHeader: cors.allowMethods,
    HttpHeaders.accessControlAllowHeadersHeader: cors.allowHeaders,
    HttpHeaders.accessControlExposeHeadersHeader: cors.exposeHeaders,
    HttpHeaders.accessControlAllowCredentialsHeader: cors.allowCredentials,
  };

  headers.forEach((String key, dynamic value) {
    _setCorsValue(req.response, key, value);
  });
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
