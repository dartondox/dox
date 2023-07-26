import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/json.dart';

dynamic httpResponseHandler(
  dynamic payload,
  HttpRequest request,
) {
  /// websocket handler will return websocket payload
  /// and in this case we need to remain the connection open for
  /// websocket communication. so there is no `res.close()`;
  if (payload is WebSocket) {
    return;
  }

  /// if payload is DoxResponse, DoxResponse have process function
  /// which will set header and status code in the response
  /// and will pass payload/content back to this function `httpResponseHandler`
  /// where the payload is not DoxResponse anymore
  /// so it will continue belows process
  if (payload is DoxResponse) {
    return payload.process(request);
  }

  HttpResponse res = request.response;

  if (payload == null) {
    res.close();
    return;
  }

  /// if payload is stream
  if (payload is StreamFile) {
    res.headers.contentType = payload.contentType;
    res.addStream(payload.stream).then((_) => res.close());
    return;
  }

  // if payload is stream
  if (payload is Stream<List<int>>) {
    res.addStream(payload).then((_) => res.close());
    return;
  }

  /// if there is responseHandler we handle responseHandler and
  /// get new payload and override existing payload
  if (DoxServer().responseHandler != null) {
    dynamic result = DoxServer().responseHandler?.handle(DoxResponse(payload));
    if (result != null) {
      payload = result;
    }
  }

  /// if payload handle base Http Exception
  /// we set http status from exception and return as map
  /// which will parse into json and response as json
  if (payload is HttpException) {
    res.statusCode = payload.code;
    payload = payload.toResponse();
  }

  if (payload is Exception || payload is Error) {
    res.statusCode = HttpStatus.internalServerError;
    payload = payload.toString();
  }

  if (payload is DateTime) {
    payload = payload.toIso8601String();
  }

  String responseData;

  /// if payload is Map or List, parse into json
  /// and response as json
  if (payload is! String) {
    responseData = JSON.stringify(payload);
    res.headers.contentType = ContentType.json;
  } else {
    responseData = payload;
  }

  /// finally write and close http connection
  res.write(responseData);
  res.close();
}
