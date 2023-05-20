import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// this is the class to response HttpRequest
class RouterResponse {
  dynamic payload;

  final HttpResponse response;

  RouterResponse(this.response);

  static send(payload, HttpRequest request) {
    /// websocket handler will return websocket payload
    /// and in this case we need to remain the connection open for
    /// websocket communication. so there is no `res.close()`;
    if (payload is WebSocket) {
      return;
    }

    /// if payload is DoxResponse, DoxResponse have process function
    /// which pass payload again to this function `RouterResponse.send`
    /// where the payload is not DoxResponse anymore
    /// so it will continue belows process
    if (payload is DoxResponse) {
      return payload.process(request);
    }

    HttpResponse res = request.response;

    /// if there is responseHandler we handle responseHandler and
    /// get new payload and override existing payload
    if (DoxServer().responseHandler != null) {
      var result = DoxServer().responseHandler?.handle(DoxResponse(payload));
      if (result != null) {
        payload = result;
      }
    }

    /// if payload handle base Http Exception
    /// we set http status from exception and return as map
    /// which will parse into json and response as json
    if (payload is HttpException) {
      res.statusCode = payload.code;
      payload = payload.toString();
    }

    if (payload is Exception) {
      res.statusCode = HttpStatus.internalServerError;
      payload = payload.toString().split(': ')[1];
    }

    String responseData;

    /// if payload is Map or List, parse into json
    /// and response as json
    if (payload is Map || payload is List) {
      responseData = jsonEncode(payload);
      res.headers.contentType = ContentType.json;
    } else {
      responseData = payload.toString();
    }

    /// finally write and close http connection
    res.write(responseData);
    res.close();
  }
}
