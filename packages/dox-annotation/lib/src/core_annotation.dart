import 'dart:io';

import 'package:dox_annotation/dox_annotation.dart';

abstract class IDox {
  void setWebsocket(IDoxWebsocket ws);
}

abstract class IDoxRequest {
  String method = 'GET';
  HttpRequest get httpRequest;
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
  IAuth? get auth;
  bool has(String key);
  String? cookie(String key, {bool decrypt = true});
  String userAgent();
  String host();
  String? origin();
  String? referer();
  void validate(Map<String, String> rules,
      {Map<String, String> messages = const <String, String>{}});
  void mapInputs(Map<String, String> mapper);
}

abstract class IStorageDriver {
  Future<String> put(String filePath, List<int> bytes, {String? extension});
  Future<List<int>?> get(String filepath);
  Future<bool> exists(String filepath);
  Future<dynamic> delete(String filepath);
}

abstract class ICacheDriver {
  String tag = '';
  String get prefix => 'dox-framework-cache-$tag:';
  Future<void> put(String key, String value, {Duration? duration});
  Future<void> forever(String key, String value);
  Future<void> forget(String key);
  Future<void> flush();
  void setTag(String tagName);
  Future<dynamic> get(String key);
  Future<bool> has(String key);
}

abstract class IHttpException {
  int code = 500;
  String errorCode = 'server_error';
  dynamic message = 'Server Error';

  dynamic toResponse() {
    if (message is Map) {
      return message;
    }
    return message.toString();
  }
}
