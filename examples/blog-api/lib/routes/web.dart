import 'package:blog/app/http/controllers/web.controller.dart';
import 'package:dox_core/dox_core.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get<WebController>('/ping', (WebController c) => c.pong);
  }
}
