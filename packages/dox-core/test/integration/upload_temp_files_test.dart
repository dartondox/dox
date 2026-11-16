import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:dox_core/http/request/form_data_visitor.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';
import 'requirements/config/app.dart';

/// the temp files of big uploads that exist now
Set<String> tempFiles() {
  return Directory.systemTemp
      .listSync()
      .map((FileSystemEntity e) => e.path)
      .where((String p) => p.contains('dox-upload-'))
      .toSet();
}

Future<void> gone(Set<String> before) async {
  for (int i = 0; i < 100; i++) {
    if (tempFiles().difference(before).isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('temp files left: ${tempFiles().difference(before)}');
}

/// a multipart body with one file bigger than the memory limit
List<int> bigBody(String boundary) {
  String head =
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="f"; filename="a.bin"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n';
  return <int>[
    ...head.codeUnits,
    ...List<int>.filled(multipartMemoryLimit + 100, 65),
    ...'\r\n--$boundary--\r\n'.codeUnits,
  ];
}

void main() {
  group('Upload temp files |', () {
    String baseUrl() => 'http://localhost:${Dox().server.httpServer.port}';
    const String boundary = 'dox-boundary';
    late Set<String> before;

    setUpAll(() async {
      /// a short idle time: the server hears that a client left after it
      await startHttpServer(
        AppConfig(
          appKey: testAppKey,
          serverPort: 0,
          totalIsolate: 1,
          idleTimeout: const Duration(seconds: 1),
          cache: config.cache,
        ),
      );
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    setUp(() {
      before = tempFiles();
    });

    test('a normal upload deletes the file after the response', () async {
      String? path;
      Route.post('/up/normal', (DoxRequest req) {
        RequestFile file = req.file('f')!;
        path = file.file!.path;
        expect(File(path!).existsSync(), isTrue);
        return 'ok';
      });
      http.Response res = await http.post(
        Uri.parse('${baseUrl()}/up/normal'),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        body: bigBody(boundary),
      );
      expect(res.statusCode, 200);
      expect(path, isNotNull);
      await gone(before);
    });

    test('the file stays while the handler runs and the client left', () async {
      Completer<String> result = Completer<String>();
      Route.post('/up/gone', (DoxRequest req) async {
        RequestFile file = req.file('f')!;

        /// something waits for `done`, so the server tells it that the
        /// client left (AfterResponse, or the code of the app)
        unawaited(req.httpRequest.response.done);
        File temp = file.file!;
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          int size = temp.lengthSync();
          result.complete('read $size');
        } catch (e) {
          result.complete('failed $e');
        }
        return 'ok';
      });
      Socket socket = await Socket.connect(
        'localhost',
        Dox().server.httpServer.port,
      );
      List<int> body = bigBody(boundary);
      socket.write(
        'POST /up/gone HTTP/1.1\r\nHost: localhost\r\n'
        'Content-Type: multipart/form-data; boundary=$boundary\r\n'
        'Content-Length: ${body.length}\r\n\r\n',
      );
      socket.add(body);
      await socket.flush();

      /// the handler is waiting now. leave.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      socket.destroy();

      expect(await result.future, 'read ${multipartMemoryLimit + 100}');

      await gone(before);
    });

    test(
      'AfterResponse work waits for the handler and the file stays',
      () async {
        AfterResponse.enable();
        addTearDown(AfterResponse.disable);
        List<String> order = <String>[];
        Completer<void> finished = Completer<void>();
        Route.post('/up/after', (DoxRequest req) async {
          RequestFile file = req.file('f')!;
          AfterResponse.run(() {
            order.add('after ${file.file!.existsSync()}');
            finished.complete();
          });
          await Future<void>.delayed(const Duration(seconds: 3));
          order.add('handler ${file.file!.existsSync()}');
          return 'ok';
        });
        Socket socket = await Socket.connect(
          'localhost',
          Dox().server.httpServer.port,
        );
        List<int> body = bigBody(boundary);
        socket.write(
          'POST /up/after HTTP/1.1\r\nHost: localhost\r\n'
          'Content-Type: multipart/form-data; boundary=$boundary\r\n'
          'Content-Length: ${body.length}\r\n\r\n',
        );
        socket.add(body);
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        socket.destroy();

        await finished.future;
        expect(order, <String>['handler true', 'after true']);
        await gone(before);
      },
    );

    test('an error in the handler deletes the file', () async {
      Route.post('/up/error', (DoxRequest req) {
        req.file('f')!;
        throw StateError('boom');
      });
      http.Response res = await http.post(
        Uri.parse('${baseUrl()}/up/error'),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        body: bigBody(boundary),
      );
      expect(res.statusCode, 500);
      await gone(before);
    });

    test('a request timeout deletes the file', () async {
      Route.post('/up/timeout', (DoxRequest req) async {
        req.file('f')!;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return 'late';
      }).timeout(const Duration(milliseconds: 100));
      http.Response res = await http.post(
        Uri.parse('${baseUrl()}/up/timeout'),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        body: bigBody(boundary),
      );
      expect(res.statusCode, 503);
      await gone(before);
    });

    test('a failed body read deletes the file', () async {
      Route.post('/up/broken', (DoxRequest req) => 'ok');

      /// the second part has no Content-Disposition: 400 after the
      /// first part is on disk
      List<int> body = bigBody(boundary);
      body.removeRange(body.length - '--$boundary--\r\n'.length, body.length);
      body.addAll(
        '--$boundary\r\nContent-Type: text/plain\r\n\r\nx\r\n'
                '--$boundary--\r\n'
            .codeUnits,
      );
      http.Response res = await http.post(
        Uri.parse('${baseUrl()}/up/broken'),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        body: body,
      );
      expect(res.statusCode, 400);
      await gone(before);
    });
  });
}
