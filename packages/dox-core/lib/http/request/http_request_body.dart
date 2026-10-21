import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/form_data_visitor.dart';

class HttpBody {
  static Future<Map<String, dynamic>> read(HttpRequest request) async {
    ContentType? contentType = request.headers.contentType;

    if (HttpBody.isJson(contentType)) {
      Uint8List bytes = await readBytes(request, Dox().config.maxBodySize);
      try {
        dynamic data = _jsonUtf8.convert(bytes);
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      } catch (err) {
        return <String, dynamic>{};
      }
    }

    if (HttpBody.isFormData(contentType)) {
      int max = Dox().config.maxMultipartSize;
      _checkContentLength(request, max);
      FormDataVisitor visitor = FormDataVisitor(request, limit(request, max));
      await visitor.process();
      return visitor.inputs;
    }

    if (HttpBody.isUrlEncoded(contentType)) {
      Uint8List bytes = await readBytes(request, Dox().config.maxBodySize);
      try {
        return Uri.splitQueryString(utf8.decode(bytes, allowMalformed: true));
      } catch (err) {
        return <String, dynamic>{};
      }
    }

    return <String, dynamic>{};
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
