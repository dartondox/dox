import 'package:dox_core/dox_core.dart';

abstract class Router {
  String get prefix => '';
  List get middleware => [];
  register();
}

class RouteData {
  final String method;
  String path;
  final dynamic controllers;
  Map<String, dynamic> params = {};
  final List preMiddleware;
  final List postMiddleware;
  final FormRequest? formRequest;

  RouteData(
    this.method,
    this.path,
    this.controllers, {
    this.preMiddleware = const [],
    this.postMiddleware = const [],
    this.formRequest,
  });
}
