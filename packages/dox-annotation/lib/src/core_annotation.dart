import 'dart:io';

import 'package:dox_annotation/dox_annotation.dart';

abstract class IDoxRequest {
  late Uri uri;
  String method = 'GET';
  HttpRequest get httpRequest;
  ContentType? get contentType;
  String getRouteIdentifier();
  dynamic getRouteData();
  Map<String, dynamic> get headers;
  String? header(String key);
  void add(String key, dynamic value);
  void merge(Map<String, dynamic> values);
  dynamic input(String key);
  bool isFormData();
  bool isJson();
  Map<String, dynamic> all();
  Map<String, dynamic> only(List<String> keys);
  String ip();

  /// the logged in user of the request. It is kept apart from the
  /// input, so a client field can not change it.
  IAuth? auth;
  bool has(String key);
  String? cookie(String key, {bool decrypt = true});
  String userAgent();
  String host();
  String? origin();
  String? referer();
  Map<String, dynamic> toJson();
}

abstract class IHttpException {
  int code = 500;
  String errorCode = 'server_error';
  dynamic message = 'Server Error';

  /// the JSON body of the error answer:
  /// `{"code": "not_found", "message": "Not Found"}`.
  /// a `Map` message is sent as it is, so validation errors and
  /// custom JSON keep their own shape.
  dynamic toResponse() {
    if (message is Map) {
      return message;
    }
    return <String, dynamic>{'code': errorCode, 'message': message.toString()};
  }
}

abstract class IDoxMiddleware {
  dynamic handle(IDoxRequest req);
}
