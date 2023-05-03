import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

abstract class DoxResponse {
  dynamic payload;

  final HttpResponse response;

  DoxResponse(this.response);

  contentType(ContentType data) {
    response.headers.contentType = data;
  }

  write(data) {
    response.write(data);
  }

  close() {
    response.close();
  }

  static send(payload, HttpRequest request) {
    HttpResponse res = request.response;

    if (DoxServer().exceptionHandler != null) {
      var exceptionHandlerResponse =
          DoxServer().exceptionHandler?.handle(payload, res);
      if (exceptionHandlerResponse != null) {
        payload = exceptionHandlerResponse;
      }
    }

    String responseData;

    if (payload is Map) {
      responseData = jsonEncode(payload as Map<String, dynamic>);
      res.headers.contentType = ContentType.json;
    } else if (payload is Model) {
      responseData = jsonEncode((payload).toJson());
      res.headers.contentType = ContentType.json;
    } else {
      responseData = payload.toString();
    }

    res.write(responseData);
    print(
        "\x1B[34m[${res.statusCode}]\x1B[0m \x1B[32m${request.method} ${request.uri.path}\x1B[0m");
    res.close();
  }
}
