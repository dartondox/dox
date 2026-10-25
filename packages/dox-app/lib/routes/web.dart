import 'package:dox_app/app/http/controllers/web.controller.dart';
import 'package:dox_core/dox_core.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get<WebController>('/redis', (WebController c) => c.testRedis);

    Route.get('/ping', (DoxRequest req) async {
      return 'pong';
    });

    /// serve files of the local disk with signed URLs:
    /// `String url = await Storage().signedUrl(path);`
    Route.files('files');
  }
}
