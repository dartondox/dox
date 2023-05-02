abstract class Router {
  String get prefix => '';
  register();
}

class RouteData {
  final String method;
  String path;
  final dynamic controllers;
  Map<String, dynamic> params = {};
  RouteData(this.method, this.path, this.controllers);
}
