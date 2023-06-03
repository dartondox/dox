import 'package:dox_core/dox_core.dart';

class RouteData {
  final String method;
  String path;
  final dynamic controllers;
  Map<String, dynamic> params = <String, dynamic>{};
  final List<dynamic> preMiddleware;
  final List<dynamic> postMiddleware;
  FormRequest Function()? formRequest;

  final String? domain;

  RouteData({
    required this.method,
    required this.path,
    required this.controllers,
    this.preMiddleware = const <dynamic>[],
    this.postMiddleware = const <dynamic>[],
    this.domain,
  });
}
