import 'dart:convert';
import 'dart:io';

import 'package:dox_core/http/request/form_data_visitor.dart';

class HttpBody {
  static Future<Map<String, dynamic>> read(HttpRequest request) async {
    if (HttpBody.isJson(request.headers.contentType)) {
      String bodyString = await utf8.decoder.bind(request).join();
      try {
        return jsonDecode(bodyString);
      } catch (err) {
        return <String, dynamic>{};
      }
    }

    if (HttpBody.isFormData(request.headers.contentType)) {
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
