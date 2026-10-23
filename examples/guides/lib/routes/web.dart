import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/health.controller.dart';
import 'package:my_app/app/http/controllers/static.controller.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    // docker health check
    Route.get('/health', healthController.check);

    // uploads: GET /files/{key*}, any file of the default disk
    Route.files('files', signed: false);

    // static files guide, "serve a folder": GET /static/{key*}
    Route.files('static', disk: 'public', signed: false);

    // the SPA: assets with a long cache, every other URL gets index.html
    Route.get('/assets/{path*}', staticController.asset);
    Route.get('/', staticController.index);
    Route.get('/{path*}', staticController.index);
  }
}
