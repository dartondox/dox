import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/file_upload.dart';
import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      await startHttpServer(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
      Directory storage = Directory('${Directory.current.path}/storage/images');
      if (storage.existsSync()) {
        storage.deleteSync(recursive: true);
      }
    });

    test('file upload | stream | download', () async {
      /// clear storage image folder

      /// upload image
      Route.post('/image', (DoxRequest req) async {
        req.validate(<String, String>{
          'image': 'file:png|image:png',
        });
        RequestFile file = req.input('image');
        String url = await Storage().putRequestFile('images', file);
        return <String, dynamic>{
          'url': url,
          'size': await file.size,
          'extension': file.extension,
        };
      });

      /// stream image
      Route.get('/image/stream', (DoxRequest req) async {
        return await Storage().stream(req.input('image'));
      });

      /// stream image
      Route.get('/image/download', (DoxRequest req) async {
        return await Storage().disk('file').download(req.input('image'));
      });

      /// stream image
      Route.get('/image/stream2', (DoxRequest req) async {
        StreamFile file = await Storage().stream(req.input('image'));
        return response(file.stream).contentType(file.contentType);
      });

      // check file exists
      Route.get('/image', (DoxRequest req) async {
        bool exists = await Storage().exists(req.input('image'));
        return exists ? 'yes' : 'no';
      });

      /// stream image
      Route.delete('/image', (DoxRequest req) async {
        await Storage().delete(req.input('image'));
        return 'success';
      });

      /// upload image from client
      String dir = Directory.current.path;
      File imageFile = File('$dir/test/integration/storage/dox.png');
      String? result = await uploadImage('$baseUrl/image', imageFile);
      Map<String, dynamic> data = jsonDecode(result!);

      /// fetch image from client
      http.Response res = await http
          .get(Uri.parse("$baseUrl/image/stream?image=${data['url']}"));
      expect(res.headers['content-type'], 'image/png');

      http.Response res2 = await http
          .get(Uri.parse("$baseUrl/image/stream2?image=${data['url']}"));
      expect(res2.headers['content-type'], 'image/png');

      http.Response res3 = await http
          .get(Uri.parse("$baseUrl/image/download?image=${data['url']}"));
      expect(res3.headers['content-type'], 'image/png');
      expect(res3.headers['content-disposition'],
          'attachment; filename="${data['url'].toString().split('/').last}"');

      http.Response res4 =
          await http.get(Uri.parse("$baseUrl/image?image=${data['url']}"));
      expect(res4.statusCode, 200);
      expect(res4.body, 'yes');

      http.Response res5 =
          await http.delete(Uri.parse("$baseUrl/image?image=${data['url']}"));
      expect(res5.statusCode, 200);
      expect(res5.body, 'success');

      File file = File("${Directory.current.path}/storage${data['url']}");
      expect(file.existsSync(), false);

      http.Response res6 =
          await http.get(Uri.parse("$baseUrl/image?image=${data['url']}"));
      expect(res6.statusCode, 200);
      expect(res6.body, 'no');
    });

    test('store', () async {
      /// upload image
      Route.post('/image/store', (DoxRequest req) async {
        RequestFile file = req.input('image');
        return await file.store('images');
      });

      /// upload image from client
      String dir = Directory.current.path;
      File imageFile = File('$dir/test/integration/storage/dox.png');
      String? url = await uploadImage('$baseUrl/image/store', imageFile);
      expect(url is String, true);
    });

    test('put', () async {
      /// upload image
      Route.post('/image/put', (DoxRequest req) async {
        RequestFile file = req.input('image');
        return await Storage().put('images', await file.bytes);
      });

      /// upload image from client
      String dir = Directory.current.path;
      File imageFile = File('$dir/test/integration/storage/dox.png');
      String? url = await uploadImage('$baseUrl/image/put', imageFile);
      expect(url is String, true);
    });

    test('get non-existent file', () async {
      Route.get('/image/non-existent', (DoxRequest req) async {
        StreamFile file = await Storage().stream(req.input('image'));
        return response(file.stream).contentType(file.contentType);
      });

      http.Response res = await http
          .get(Uri.parse('$baseUrl/image/non-existent?image=non-existent.png'));

      expect(res.statusCode, 404);
      expect(res.body, 'file not found');
    });

    /// test invalid file
    /// test invalid file type
    /// test non-existent image
  });
}
