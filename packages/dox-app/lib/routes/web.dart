import 'package:dox_core/dox_core.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) async {
      return 'pong';
    });

    Route.get('/download', (DoxRequest req) async {
      try {
        DownloadableFile file = await Storage()
            .download('/images/3d975270-2bbb-11ee-9f99-ddd56a1df7a6.jpeg');
        return response(file);
      } catch (error) {
        return error.toString();
      }
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
