import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const int port = 50022;
const String baseUrl = 'http://localhost:$port';
const String root = 'storage/test-disk';

class FileRouter extends Router {
  @override
  void register() {
    Route.files('files');
    Route.files('public-files', signed: false);
    Route.get('/download', (DoxRequest req) {
      return Storage().download(req.input('key'));
    });
    Route.get('/memory', (DoxRequest req) {
      return Storage().disk('memory').stream(req.input('key'));
    });
  }
}

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  serverPort: port,
  totalIsolate: 1,
  routers: <Router>[FileRouter()],
  cache: CacheConfig(
    defaultStore: 'memory',
    stores: <String, Map<String, dynamic>>{
      'memory': <String, dynamic>{'driver': 'memory'},
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/test-cache'},
    },
  ),
  storage: StorageConfig(
    disks: <String, Map<String, dynamic>>{
      'local': <String, dynamic>{
        'driver': 'local',
        'root': root,
        'url': '$baseUrl/files',
      },
      'memory': <String, dynamic>{'driver': 'memory'},
    },
  ),
  errorHandler: (Object? error, StackTrace stackTrace) {},
);

void main() {
  setUpAll(() async {
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close(force: true);
    for (String dir in <String>[root, 'storage/test-cache']) {
      if (Directory(dir).existsSync()) {
        Directory(dir).deleteSync(recursive: true);
      }
    }
  });

  group('Cache facade |', () {
    for (String store in <String>['memory', 'file']) {
      test('$store: put, get, has, forget, JSON values', () async {
        await Cache().store(store).put('name', 'Dox');
        expect(await Cache().store(store).get('name'), 'Dox');
        expect(await Cache().store(store).has('name'), isTrue);

        await Cache().store(store).put('user', <String, dynamic>{'id': 1});
        expect(await Cache().store(store).get('user'), <String, dynamic>{
          'id': 1,
        });

        await Cache().store(store).forget('name');
        expect(await Cache().store(store).get('name'), isNull);
        expect(await Cache().store(store).get('name', 'fallback'), 'fallback');
      });

      test('$store: ttl, tags, remember, increment', () async {
        await Cache()
            .store(store)
            .put('short', 'x', duration: const Duration(milliseconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await Cache().store(store).get('short'), isNull);

        await Cache().store(store).tag('posts').put('p1', 'Post');
        await Cache().store(store).put('keep', 'yes');
        await Cache().store(store).tag('posts').flush();
        expect(await Cache().store(store).tag('posts').get('p1'), isNull);
        expect(await Cache().store(store).get('keep'), 'yes');

        int calls = 0;
        Future<int> compute() async => ++calls;
        expect(await Cache().store(store).rememberForever('r', compute), 1);
        expect(await Cache().store(store).rememberForever('r', compute), 1);

        expect(await Cache().store(store).increment('n', 2), 2);
        expect(await Cache().store(store).decrement('n'), 1);
      });
    }

    test('default store comes from the config', () async {
      await Cache().put('default', 'memory');
      expect(await Cache().store('memory').get('default'), 'memory');
    });
  });

  group('Storage facade |', () {
    test('put keeps the uuid file name and the old path shape', () async {
      String path = await Storage().put('images', <int>[
        1,
        2,
        3,
      ], extension: 'bin');
      expect(path, matches(RegExp(r'^/images/[0-9a-f-]+\.bin$')));
      expect(await Storage().exists(path), isTrue);
      expect(await Storage().get(path), <int>[1, 2, 3]);
      expect(File('$root$path').existsSync(), isTrue);

      await Storage().delete(path);
      expect(await Storage().exists(path), isFalse);
      expect(await Storage().get(path), isNull);
    });

    test('download streams with length and file name', () async {
      List<int> bytes = List<int>.generate(300000, (int i) => i % 256);
      String path = await Storage().put('big', bytes, extension: 'bin');
      http.Response res = await http.get(
        Uri.parse('$baseUrl/download?key=$path'),
      );
      expect(res.statusCode, 200);
      expect(res.bodyBytes, bytes);
      expect(res.headers['content-length'], '300000');
      expect(
        res.headers['content-disposition'],
        'attachment; filename="${path.split('/').last}"',
      );
    });

    test('missing file is 404', () async {
      http.Response res = await http.get(
        Uri.parse('$baseUrl/download?key=/nope/missing.png'),
      );
      expect(res.statusCode, 404);
    });

    test('memory disk works through the same facade', () async {
      String path = await Storage()
          .disk('memory')
          .put('notes', utf8.encode('hello'), extension: 'txt');
      http.Response res = await http.get(
        Uri.parse('$baseUrl/memory?key=$path'),
      );
      expect(res.body, 'hello');
      expect(res.headers['content-type'], startsWith('text/plain'));
    });

    test('signed local URL is served, a bad one is 403', () async {
      String path = await Storage().put(
        'secret',
        utf8.encode('top'),
        extension: 'txt',
      );
      String url = await Storage().signedUrl(path);
      expect(url, startsWith('$baseUrl/files/secret/'));

      http.Response ok = await http.get(Uri.parse(url));
      expect(ok.statusCode, 200);
      expect(ok.body, 'top');

      http.Response bad = await http.get(
        Uri.parse(url.replaceFirst('signature=', 'signature=x')),
      );
      expect(bad.statusCode, 403);

      http.Response unsigned = await http.get(Uri.parse('$baseUrl/files$path'));
      expect(unsigned.statusCode, 403);

      http.Response open = await http.get(
        Uri.parse('$baseUrl/public-files$path'),
      );
      expect(open.body, 'top');
    });
  });
}
