import 'dart:convert';
import 'dart:io';

import 'package:dox_core/request/form_data_visitor.dart';

class HttpBodyParser {
  static Future<Map<String, dynamic>> process(HttpRequest request) async {
    if (HttpBodyParser.isJson(request.headers.contentType)) {
      String bodyString = await utf8.decoder.bind(request).join();
      return jsonDecode(bodyString);
    }

    if (HttpBodyParser.isFormData(request.headers.contentType)) {
      FormDataVisitor visitor = FormDataVisitor(request);
      await visitor.process();
      return visitor.inputs;
    }

    return <String, dynamic>{};
  }

  /// http request data is form data
  static bool isFormData(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('form-data') == true;
  }

  /// http request data is json
  static bool isJson(ContentType? contentType) {
    return contentType.toString().toLowerCase().contains('json') == true;
  }
}
