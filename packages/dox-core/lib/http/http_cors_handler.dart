import 'dart:io';

import 'package:dox_core/dox_core.dart';

void httpCorsHandler(bool? enabled, HttpRequest req) {
  CORSConfig cors = Dox().config.cors;
  if (!(enabled ?? cors.enabled)) return;
  HttpResponse res = req.response;

  /// call each one directly, no map per request.
  /// null values are skipped inside `_setCorsValue`.
  if (cors.origin is List) {
    /// the answer depends on the request Origin, so caches must know it.
    res.headers.add(HttpHeaders.varyHeader, 'Origin');
  }
  _setCorsValue(
    res,
    HttpHeaders.accessControlAllowOriginHeader,
    corsAllowOrigin(cors.origin, req.headers.value('origin')),
  );
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

/// Get the value for the Access-Control-Allow-Origin header.
///
/// A browser accepts only one origin or `*` in this header.
/// So when [origin] is a list, we look for [requestOrigin] in the list.
/// We send back only that origin. If it is not in the list, we send nothing.
/// A list that has `*` allows every origin.
dynamic corsAllowOrigin(dynamic origin, String? requestOrigin) {
  if (origin is! List) return origin;
  if (origin.contains('*')) return '*';
  if (requestOrigin != null && origin.contains(requestOrigin)) {
    return requestOrigin;
  }
  return null;
}

/// a config list joined once, eg. `GET,POST`. the config does not change.
final Expando<String> _joined = Expando<String>();

// set cors in header
void _setCorsValue(HttpResponse res, String key, dynamic data) {
  if (data == null) {
    return;
  }

  /// when data is list of string, eg. ['GET', 'POST']
  if (data is List<String> && data.isNotEmpty) {
    res.headers.add(key, _joined[data] ??= data.join(','));
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
