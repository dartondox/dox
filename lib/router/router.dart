abstract class Router {
  String get prefix => '';
  Map<Type, Function()> get requests => {};
  List get middleware => [];
  register();
}
