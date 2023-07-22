abstract class Router {
  String get prefix => '';
  List<dynamic> get middleware => <dynamic>[];
  void register();
}
