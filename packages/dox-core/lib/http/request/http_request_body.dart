import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_data_visitor.dart';

/// What kind of body a request has.
enum BodyKind {
  /// no `Content-Type`
  none,

  /// JSON (`application/json` or any `+json` type)
  json,

  /// a `Content-Type` of JSON, but the bytes are not valid JSON
  invalidJson,

  /// `application/x-www-form-urlencoded`
  urlEncoded,

  /// `multipart/form-data`
  multipart,

  /// any other `Content-Type`
  other,
}

/// The body of a request, read once.
class RequestBody {
  RequestBody(
    this.map, {
    this.kind = BodyKind.none,
    this.json,
    this.text,
    this.parts,
  });

  /// An empty body.
  RequestBody.empty() : this(<String, dynamic>{});

  /// The body as a map (`req.body`). Repeated form keys keep the last value.
  final Map<String, dynamic> map;

  final BodyKind kind;

  /// The decoded JSON value, any type (a DTO reads this).
  final Object? json;

  /// The raw text of an urlencoded body.
  final String? text;

  /// The parts of a multipart body, in order, with repeated keys.
  final List<MapEntry<String, Object>>? parts;
}

class HttpBody {
  static Future<RequestBody> read(HttpRequest request) async {
    ContentType? contentType = request.headers.contentType;

    if (contentType == null) return RequestBody.empty();

    if (HttpBody.isJson(contentType)) {
      Uint8List bytes = await readBytes(request, Dox().config.maxBodySize);
      if (bytes.isEmpty) {
        return RequestBody.empty();
      }
      try {
        Object? data = _jsonUtf8.convert(bytes);
        return RequestBody(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
          kind: BodyKind.json,
          json: data,
        );
      } catch (err) {
        return RequestBody(<String, dynamic>{}, kind: BodyKind.invalidJson);
      }
    }

    if (HttpBody.isFormData(contentType)) {
      int max = Dox().config.maxMultipartSize;
      _checkContentLength(request, max);
      FormDataVisitor visitor = FormDataVisitor(request, limit(request, max));
      await visitor.process();
      return RequestBody(
        visitor.inputs,
        kind: BodyKind.multipart,
        parts: visitor.parts,
      );
    }

    if (HttpBody.isUrlEncoded(contentType)) {
      Uint8List bytes = await readBytes(request, Dox().config.maxBodySize);
      String text = utf8.decode(bytes, allowMalformed: true);
      Map<String, dynamic> map = <String, dynamic>{};
      try {
        map = Uri.splitQueryString(text);
      } catch (err) {
        /// bad percent encoding: an empty body
      }
      return RequestBody(map, kind: BodyKind.urlEncoded, text: text);
    }

    return RequestBody(<String, dynamic>{}, kind: BodyKind.other);
  }

  /// read the whole body, but stop with 413 once it passes [max] bytes.
  static Future<Uint8List> readBytes(HttpRequest request, int max) async {
    _checkContentLength(request, max);
    BytesBuilder builder = BytesBuilder(copy: false);
    await for (List<int> chunk in limit(request, max)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// pass the body through, but throw 413 once it passes [max] bytes.
  /// this catches clients that lie about or skip Content-Length.
  static Stream<List<int>> limit(Stream<List<int>> body, int max) async* {
    int total = 0;
    await for (List<int> chunk in body) {
      total += chunk.length;
      if (total > max) throw PayloadTooLargeException();
      yield chunk;
    }
  }

  /// cheap early check: refuse before reading a single byte.
  static void _checkContentLength(HttpRequest request, int max) {
    if (request.contentLength > max) throw PayloadTooLargeException();
  }

  /// http request data is form data
  static bool isFormData(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('form-data') == true;
  }

  /// http request data is json
  static bool isJson(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('json') == true;
  }

  /// http request data is application/x-www-form-urlencoded
  static bool isUrlEncoded(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase() ==
        'application/x-www-form-urlencoded';
  }
}

/// decodes utf8 bytes straight into json, without a middle String.
final Converter<List<int>, Object?> _jsonUtf8 = utf8.decoder.fuse(json.decoder);
