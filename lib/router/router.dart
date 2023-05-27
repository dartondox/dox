abstract class Router {
  String get prefix => '';
  List get middleware => [];
  register();
}
