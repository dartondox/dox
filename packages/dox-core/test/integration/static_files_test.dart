import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

/// sends [request] as is, reads until the server closes
Future<String> raw(int port, String request) async {
  Socket s = await Socket.connect('127.0.0.1', port);
  s.write(request);
  String out = await utf8.decoder.bind(s).join();
  s.destroy();
  return out;
}

void main() {
  late Directory dir;
  late int port;
  late HttpClient client;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dox_static_');
    Directory public = Directory('${dir.path}/public');
    await Directory('${public.path}/sub').create(recursive: true);
    await File('${public.path}/app.js').writeAsString('console.log(1)');
    await File('${public.path}/.env').writeAsString('APP_KEY=secret');
    await File('${public.path}/sub/x.css').writeAsString('a{}');
    await File('${dir.path}/secret.txt').writeAsString('TOP-SECRET-CONTENT');

    Route.get('/assets/route.js', (DoxRequest req) => 'from route');
    Route.staticFiles('assets', public.path);
    Route.staticFiles('cached', public.path, maxAge: const Duration(days: 365));
    await File('${public.path}/route.js').writeAsString('from file');
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
      ),
    );
    port = Dox().server.httpServer.port;
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close();
    await Dox().server.close();
    await dir.delete(recursive: true);
  });

  Future<HttpClientResponse> get(String path, {String method = 'GET'}) async {
    HttpClientRequest req = await client.open(method, '127.0.0.1', port, path);
    return req.close();
  }

  test('a file is sent with its type and Last-Modified', () async {
    HttpClientResponse res = await get('/assets/app.js');
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'text/javascript');
    expect(res.headers.value('x-content-type-options'), 'nosniff');
    expect(res.headers.value('last-modified'), isNotNull);
    expect(res.headers.value('cache-control'), isNull);
    expect(await utf8.decodeStream(res), 'console.log(1)');
  });

  test('a file in a sub folder is sent', () async {
    HttpClientResponse res = await get('/assets/sub/x.css');
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), 'a{}');
  });

  test('304 when the browser has this version', () async {
    HttpClientResponse first = await get('/assets/app.js');
    String modified = first.headers.value('last-modified')!;
    await first.drain<void>();

    HttpClientRequest req = await client.get(
      '127.0.0.1',
      port,
      '/assets/app.js',
    );
    req.headers.set('if-modified-since', modified);
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 304);
    await res.drain<void>();

    // a date that is not a date sends the file
    req = await client.get('127.0.0.1', port, '/assets/app.js');
    req.headers.set('if-modified-since', 'yesterday');
    res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
  });

  test('maxAge sends Cache-Control', () async {
    HttpClientResponse res = await get('/cached/app.js');
    expect(res.statusCode, 200);
    expect(res.headers.value('cache-control'), 'public, max-age=31536000');
    await res.drain<void>();
  });

  test('HEAD sends the headers with no body', () async {
    HttpClientResponse res = await get('/assets/app.js', method: 'HEAD');
    expect(res.statusCode, 200);
    expect(res.contentLength, 'console.log(1)'.length);
    expect(await res.toList(), isEmpty);
  });

  test('a route wins over a file', () async {
    HttpClientResponse res = await get('/assets/route.js');
    expect(await utf8.decodeStream(res), 'from route');
  });

  test('dot files, folders and missing files get 404', () async {
    for (String path in <String>[
      '/assets/.env',
      '/assets/sub',
      '/assets/sub/',
      '/assets/',
      '/assets',
      '/assets/missing.js',
      '/assets//app.js',
    ]) {
      HttpClientResponse res = await get(path);
      expect(res.statusCode, 404, reason: path);
      await res.drain<void>();
    }
  });

  test('no file outside the folder, however the path is written', () async {
    for (String path in <String>[
      '/assets/../secret.txt',
      '/assets/%2e%2e/secret.txt',
      '/assets/..%2fsecret.txt',
      '/assets/..%5csecret.txt',
      '/assets/%ff',
    ]) {
      String res = await raw(
        port,
        'GET $path HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      expect(res, isNot(contains('TOP-SECRET-CONTENT')), reason: path);
      expect(res, startsWith('HTTP/1.1 404'), reason: path);
    }
  });

  test('only GET and HEAD read files', () async {
    for (String method in <String>['POST', 'PUT', 'DELETE']) {
      HttpClientResponse res = await get('/assets/app.js', method: method);
      expect(res.statusCode, 404, reason: method);
      await res.drain<void>();
    }
  });
}
