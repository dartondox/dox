import 'package:dox_app/app/http/controllers/web.controller.dart';
import 'package:dox_core/dox_core.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    WebController webController = WebController();
    Route.get('/redis', webController.testRedis);

    Route.get('/ping', (DoxRequest req) async {
      return 'pong';
    });

    /// serve files of the local disk with signed URLs:
    /// `String url = await Storage().signedUrl(path);`
    Route.files('files');

    /// stream a stored file as a download, from any disk
    Route.get('/download', (DoxRequest req) async {
      return Storage().download(req.input('path'));
    });

    Route.delete('/image', (DoxRequest req) async {
      try {
        print(req.input('image'));
        await Storage().delete(req.input('image'));
        return 'success';
      } catch (error) {
        return error.toString();
      }
    });

    Route.delete('/ping', (DoxRequest req) async {
      return await Cache().flush();
    });

    Route.post('/ping', (DoxRequest req) async {
      RequestFile file = req.input('image');
      return Storage().put('images', await file.bytes);
    });
  }
}
