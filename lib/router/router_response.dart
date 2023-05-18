import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class RouterResponse {
  dynamic payload;

  final HttpResponse response;

  RouterResponse(this.response);

  static send(payload, HttpRequest request) {
    if (payload is WebSocket) {
      return;
    }

    if (payload is DoxResponse) {
      return payload.process(request);
    }

    HttpResponse res = request.response;

    if (DoxServer().responseHandler != null) {
      var responseHandler =
          DoxServer().responseHandler?.handle(DoxResponse(payload));
      if (responseHandler != null) {
        payload = responseHandler;
      }
    }

    String responseData;

    if (payload is Map || payload is List) {
      responseData = jsonEncode(payload);
      res.headers.contentType = ContentType.json;
    } else {
      responseData = payload.toString();
    }

    res.write(responseData);
    res.close();
  }
}
