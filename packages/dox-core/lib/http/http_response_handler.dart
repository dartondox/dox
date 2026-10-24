import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/json.dart';

dynamic httpResponseHandler(dynamic payload, HttpRequest request) {
  /// Websocket handler will return websocket payload
  /// and in this case we need to remain the connection open for
  /// websocket communication. So there is no `res.close()` required.
  if (payload is WebSocket) {
    return;
  }

  ResponseHandlerInterface? customResponseHandler = DoxServer().responseHandler;

  /// a plain value (text, map, list...) with no custom handler needs no
  /// DoxResponse: it would set no header and no status. files keep the
  /// DoxResponse path, which sets their content type.
  if (customResponseHandler == null &&
      payload is! DoxResponse &&
      payload is! File &&
      payload is! StreamFile &&
      payload is! DownloadableFile) {
    responseDataHandler(payload, request);
    return;
  }

  DoxResponse doxResponse = payload is DoxResponse
      ? payload
      : DoxResponse(payload);

  /// If there is responseHandler set, handle responseHandler
  /// before DoxResponse process. The responseHandler will return
  /// DoxResponse to process
  if (customResponseHandler != null) {
    doxResponse = customResponseHandler.handle(doxResponse);
  }

  /// DoxResponse have process function
  /// which will set header and status code in the response
  /// and will pass payload/content to `responseDataHandler` function.
  doxResponse.process(request);
}

/// A stored file can be html, svg, xml or js that a user uploaded.
/// Shown inline, its script runs on the app origin (stored XSS).
/// So such a file is sent as a download, in a sandbox.
/// `nosniff` stops the browser from guessing html in other files.
/// A `Content-Disposition` set by the app (eg. `inline`) is kept.
void _guardActiveFile(HttpResponse res, ContentType type) {
  res.headers.set('X-Content-Type-Options', 'nosniff');
  if (res.headers.value(FILE_DOWNLOAD_HEADER) != null) return;
  String mime = type.mimeType.toLowerCase();
  if (mime.contains('html') ||
      mime.contains('xml') ||
      mime.contains('javascript')) {
    res.headers.set(FILE_DOWNLOAD_HEADER, 'attachment');
    res.headers.set('Content-Security-Policy', 'sandbox');
  }
}

/// encodes json straight to utf8 bytes, without building a String first.
/// 8 KB chunks: most bodies fit in one, so there is no join.
final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder(null, advanceEncode, 8192);

/// Handle response for different types of data
/// such as string, stream, file, Model, List, encodable.
void responseDataHandler(dynamic payload, HttpRequest request) {
  HttpResponse res = request.response;

  if (payload == null) {
    res.close();
    return;
  }

  /// file on disk: streamed, with Content-Length and Range support
  if (payload is File) {
    _pipe(request, _sendFile(payload, request));
    return;
  }

  /// if payload is stream
  if (payload is StreamFile) {
    res.headers.contentType = payload.contentType;
    _guardActiveFile(res, payload.contentType);
    if (payload.length != null) res.contentLength = payload.length!;
    _pipe(request, res.addStream(payload.stream));
    return;
  }

  /// if payload is downloadable file,
  /// we response contentDisposition header with stream data.
  if (payload is DownloadableFile) {
    res.headers.contentType = payload.contentType;
    res.headers.add(FILE_DOWNLOAD_HEADER, payload.contentDisposition);
    if (payload.length != null) res.contentLength = payload.length!;
    _pipe(request, res.addStream(payload.stream));
    return;
  }

  // if payload is stream, pipe it chunk by chunk (no buffering)
  if (payload is Stream<List<int>>) {
    _pipe(request, res.addStream(payload));
    return;
  }

  /// if payload handle base Http Exception
  /// we set http status from exception and return as map
  /// which will parse into json and response as json
  if (payload is IHttpException) {
    res.statusCode = payload.code;
    payload = payload.toResponse();
  }

  /// the text of an error can hold SQL, file paths or hosts. send it only
  /// in development. it is logged by `errorHandler` in every env.
  if (payload is Exception || payload is Error) {
    res.statusCode = HttpStatus.internalServerError;
    payload = _showErrors()
        ? payload.toString()
        : InternalErrorException().toResponse();
  }

  if (payload is DateTime) {
    payload = payload.toIso8601String();
  }

  List<int> bytes;

  /// if payload is Map or List, parse into json
  /// and response as json
  if (payload is! String) {
    bytes = _jsonUtf8.convert(payload);
    res.headers.contentType = ContentType.json;
  } else {
    bytes = res.encoding.encode(payload);
  }

  /// finally write and close http connection.
  /// known length lets the client skip chunked decoding.
  /// dart:io only gzips when the length is not set, so skip it then.
  if (!Dox().config.compress) res.contentLength = bytes.length;
  res.add(bytes);
  res.close();
}

/// the APP_ENV value [_show] was made from. the answer is made again
/// only when the value changes, so most errors skip the string work.
String? _shownFor;
bool _show = false;

bool _showErrors() {
  String env = Env.get<String>('APP_ENV');
  if (!identical(env, _shownFor)) {
    String lower = env.toLowerCase();
    _show = lower == 'development' || lower == 'local';
    _shownFor = env;
  }
  return _show;
}

/// wait for a streamed body, then close the response.
/// a failing stream is logged and the connection is closed,
/// instead of crashing the isolate with an unhandled error.
Future<void> _pipe(HttpRequest request, Future<dynamic> body) async {
  HttpResponse res = request.response;
  try {
    await body;
  } catch (error, stackTrace) {
    Dox().config.errorHandler(error, stackTrace);
  }
  try {
    await res.close();
  } catch (_) {
    /// client already gone
  }
}

final RegExp _rangePattern = RegExp(r'^bytes=(\d*)-(\d*)$');

/// stream a file. supports a single `Range: bytes=a-b`
/// so video players and download managers can seek and resume.
Future<void> _sendFile(File file, HttpRequest request) async {
  HttpResponse res = request.response;
  if (!await file.exists()) {
    res.statusCode = HttpStatus.notFound;
    res.headers.contentType = ContentType.text;
    res.write('file not found');
    return;
  }
  int length = await file.length();
  int start = 0;
  int end = length - 1;
  res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

  String? range = request.headers.value(HttpHeaders.rangeHeader);
  Match? match = range == null ? null : _rangePattern.firstMatch(range.trim());
  if (match != null && (match[1]!.isNotEmpty || match[2]!.isNotEmpty)) {
    if (match[1]!.isEmpty) {
      /// `bytes=-500` means the last 500 bytes
      start = max(0, length - int.parse(match[2]!));
    } else {
      start = int.parse(match[1]!);
      if (match[2]!.isNotEmpty) end = min(int.parse(match[2]!), length - 1);
    }
    if (start > end || start >= length) {
      res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      res.contentLength = 0;
      return;
    }
    res.statusCode = HttpStatus.partialContent;
    res.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$length',
    );
  }

  res.contentLength = end - start + 1;
  await res.addStream(file.openRead(start, end + 1));
}
