import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxRequest {
  final HttpRequest httpRequest;
  final HttpResponse httpResponse;
  Map param = {};
  Map query = {};
  String method = 'GET';
  Uri uri;
  Map body = {};
  dynamic bodyString;

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
    return i;
  }

  Map<String, dynamic> all() {
    return {...query, ...body};
  }
}
