import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxRequest {
  final HttpRequest httpRequest;
  final HttpResponse httpResponse;
  Map<String, dynamic> param = {};
  Map<String, dynamic> query = {};
  String method = 'GET';
  Uri uri;
  Map body = {};
  dynamic bodyString;
  Map<String, dynamic> _allRequest = {};

  DoxRequest(this.httpRequest, this.httpResponse, this.uri);

  static DoxRequest modify(DoxRequest i, {required Map body}) {
    i.body = body;
    return i;
  }

  static Future<DoxRequest> httpRequestToDoxRequest(
    HttpRequest request,
    RouteData route,
  ) async {
    DoxRequest i = DoxRequest(request, request.response, request.uri);
    i.param = route.params;
    i.method = route.method;
    i.query = request.uri.queryParameters;
    var bodyString = await utf8.decoder.bind(request).join();
    if (request.headers.contentType.toString().contains('json')) {
      i.body = jsonDecode(bodyString);
    }
    i.bodyString = bodyString;
    i._allRequest = {...i.query, ...i.body};
    return i;
  }

  Map<String, dynamic> all() {
    return _allRequest;
  }

  dynamic input(key) {
    return _allRequest[key];
  }
}
