import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/json.dart';

dynamic httpResponseHandler(
  dynamic payload,
  HttpRequest request,
) {
  /// Websocket handler will return websocket payload
  /// and in this case we need to remain the connection open for
  /// websocket communication. So there is no `res.close()` required.
  if (payload is WebSocket) {
    return;
  }

  /// If there is responseHandler set, handle responseHandler
  /// before DoxResponse process. The responseHandler will return
  /// DoxResponse to process
  ResponseHandlerInterface? customResponseHandler = DoxServer().responseHandler;
  if (customResponseHandler != null) {
    DoxResponse doxResponse = customResponseHandler
        .handle(payload is DoxResponse ? payload : DoxResponse(payload));
    payload = doxResponse;
  }

  /// If payload is DoxResponse, DoxResponse have process function
  /// which will set header and status code in the response
  /// and will pass payload/content to `responseDataHandler` function.
  if (payload is DoxResponse) {
    payload.process(request);
    return;
  }
}

/// Handle response for different types of data
/// such as string, stream, Model, List, encodable.
void responseDataHandler(dynamic payload, HttpRequest request) {
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

  /// if payload is downloadable file,
  /// we response contentDisposition header with stream data.
  if (payload is DownloadableFile) {
    res.headers.contentType = payload.contentType;
    res.headers.add(FILE_DOWNLOAD_HEADER, payload.contentDisposition);
    res.addStream(payload.stream).then((_) => res.close());
    return;
  }

  // if payload is stream
  if (payload is Stream<List<int>>) {
    res.addStream(payload).then((_) => res.close());
    return;
  }

  /// if payload handle base Http Exception
  /// we set http status from exception and return as map
  /// which will parse into json and response as json
  if (payload is IHttpException) {
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
