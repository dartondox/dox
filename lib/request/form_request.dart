import 'package:dox_core/request/dox_request.dart';

abstract class FormRequest {
  bool get useAsControllerRequest => true;

  void setUp() {}

  Map<String, String> rules() {
    return {};
  }

  Map<String, String> messages() {
    return {};
  }

  Map<String, String> mapInputs() {
    return {};
  }

  late DoxRequest request;

  void setRequest(DoxRequest req) {
    request = req;
  }

  String get method => request.method;
  Uri get uri => request.uri;

  Map<String, dynamic> get param => request.param;
  Map<String, dynamic> get query => request.query;
  Map<String, dynamic> get body => request.body;
  Map<String, dynamic> get headers => request.headers;

  bool isFormData() {
    return request.isFormData();
  }

  bool isJson() {
    return request.isJson();
  }

  /// Get all request from body and query
  Map<String, dynamic> all() {
    return request.all();
  }

  /// Get Only specific request from body and query
  Map<String, dynamic> only(List<String> keys) {
    return request.only(keys);
  }

  /// Get user IP
  String ip() {
    return request.ip();
  }

  /// Get request value
  dynamic input(key) {
    return request.input(key);
  }

  /// check if input is present
  bool has(String key) {
    return request.has(key);
  }

  // get cookie
  String cookie(dynamic key, {bool decrypt = true}) {
    return request.cookie(key, decrypt: decrypt);
  }

  /// Get header value
  String? header(key) {
    return request.header(key);
  }
}