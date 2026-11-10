import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_input.dart';
import 'package:dox_core/http/request/form_data_visitor.dart';
import 'package:dox_http_native/dox_http_native.dart';

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

  /// The body as a map (`req.body`). A repeated form key keeps the last
  /// value. Bracket keys nest: `tags[]=a&tags[]=b` gives a list.
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
  /// [contentType] is the `Content-Type` of [request] when the caller
  /// already read it. Else it is read here.
  static Future<RequestBody> read(
    HttpRequest request, [
    ContentType? contentType,
  ]) async {
    contentType ??= request.headers.contentType;
    if (contentType == null) return RequestBody.empty();

    RequestBody? now = readNow(request, contentType);
    if (now != null) return now;

    if (HttpBody.isJson(contentType)) {
      return _json(await readBytes(request, Dox().config.maxBodySize));
    }

    if (HttpBody.isFormData(contentType)) {
      int max = Dox().config.maxMultipartSize;
      _checkContentLength(request, max);
      FormDataVisitor visitor = FormDataVisitor(
        request,
        limit(request, max),
        boundary: contentType.parameters['boundary'],
      );
      await visitor.process();
      return RequestBody(
        const FormInput().nested(visitor.inputs, () => visitor.parts),
        kind: BodyKind.multipart,
        parts: visitor.parts,
      );
    }

    return _urlEncoded(await readBytes(request, Dox().config.maxBodySize));
  }

  /// The body, when it can be made with no wait: a JSON or urlencoded body
  /// on the native server (it holds the whole body already), or a body
  /// type that Dox does not read. null when it needs [read] (dart:io, or
  /// multipart). Throws 413 like [read].
  static RequestBody? readNow(HttpRequest request, ContentType contentType) {
    bool json = HttpBody.isJson(contentType);
    bool urlEncoded = !json && HttpBody.isUrlEncoded(contentType);
    if (!json && !urlEncoded) {
      if (HttpBody.isFormData(contentType)) return null;
      return RequestBody(<String, dynamic>{}, kind: BodyKind.other);
    }
    if (request is! NativeRequest) return null;
    int max = Dox().config.maxBodySize;
    _checkContentLength(request, max);
    Uint8List bytes = request.body;
    if (bytes.length > max) throw PayloadTooLargeException();
    return json ? _json(bytes) : _urlEncoded(bytes);
  }

  static RequestBody _json(Uint8List bytes) {
    if (bytes.isEmpty) return RequestBody.empty();
    try {
      Object? data = JSON.parseBytes(bytes);
      return RequestBody(
        data is Map<String, dynamic> ? data : <String, dynamic>{},
        kind: BodyKind.json,
        json: data,
      );
    } catch (err) {
      return RequestBody(<String, dynamic>{}, kind: BodyKind.invalidJson);
    }
  }

  static RequestBody _urlEncoded(Uint8List bytes) {
    String text = utf8.decode(bytes, allowMalformed: true);
    Map<String, dynamic> map = <String, dynamic>{};
    try {
      map = Uri.splitQueryString(text);
    } catch (err) {
      /// bad percent encoding: an empty body
    }
    map = const FormInput().nested(map, () => const FormInput().pairs(text));
    return RequestBody(map, kind: BodyKind.urlEncoded, text: text);
  }

  /// read the whole body, but stop with 413 once it passes [max] bytes.
  static Future<Uint8List> readBytes(HttpRequest request, int max) async {
    _checkContentLength(request, max);

    /// the native server already holds the whole body. no stream needed.
    if (request is NativeRequest) {
      if (request.body.length > max) throw PayloadTooLargeException();
      return request.body;
    }
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
