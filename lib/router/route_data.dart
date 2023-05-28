import 'package:dox_core/dox_core.dart';

class RouteData {
  final String method;
  String path;
  final dynamic controllers;
  Map<String, dynamic> params = {};
  final List preMiddleware;
  final List postMiddleware;
  FormRequest Function()? formRequest;

  final String? domain;

  RouteData({
    required this.method,
    required this.path,
    required this.controllers,
    this.preMiddleware = const [],
    this.postMiddleware = const [],
    this.domain,
  });
}
