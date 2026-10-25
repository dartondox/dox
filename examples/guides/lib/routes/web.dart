import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/static.controller.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_storage/dox_storage.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    // docker health check: 503 when the database does not answer
    Route.health(
      '/health',
      checks: <String, HealthCheckFunction>{
        'database': () => QueryBuilder.query('select 1'),
      },
    );

    // uploads: GET /files/{key*}, any file of the default disk
    Storage.route('files', signed: false);

    // static files guide, "serve a folder": GET /static/{key*}
    Storage.route('static', disk: 'public', signed: false);

    // the SPA: assets with a long cache, every other URL gets index.html
    Route.get('/assets/{path*}', (StaticController c) => c.asset);
    Route.get('/', (StaticController c) => c.index);
    Route.get('/{path*}', (StaticController c) => c.index);
  }
}
