import 'package:dox_core/dox_core.dart';

abstract class FormRequest {
  /// run on initial
  void setUp() {}

  /// set validation rules
  Map<String, String> rules() {
    return <String, String>{};
  }

  /// set validation messages
  Map<String, String> messages() {
    return <String, String>{};
  }

  /// use this function to change request input name
  Map<String, String> mapInputs() {
    return <String, String>{};
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

  /// check request data is form data
  bool isFormData() {
    return request.isFormData();
  }

  /// check request data is json data
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
  dynamic input(String key) {
    return request.input(key);
  }

  /// check if input is present
  bool has(String key) {
    return request.has(key);
  }

  // get cookie
  String? cookie(dynamic key, {bool decrypt = true}) {
    return request.cookie(key, decrypt: decrypt);
  }

  /// Get header value
  String? header(String key) {
    return request.header(key);
  }

  /// get user agent from header`
  String userAgent() {
    return request.userAgent();
  }

  /// get host
  String host() {
    return request.host();
  }

  /// get origin
  String? origin() {
    return request.origin();
  }

  /// get origin
  String? referer() {
    return request.referer();
  }

  Map<String, dynamic> toJson() {
    return request.toJson();
  }
}
