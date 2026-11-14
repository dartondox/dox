import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

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
    await Directory('${public.path}/.well-known/acme-challenge')
        .create(recursive: true);
    await File('${public.path}/.well-known/acme-challenge/tok123')
        .writeAsString('tok123.key');
    await File('${public.path}/.well-known/security.txt')
        .writeAsString('Contact: x');
    await File('${public.path}/.well-known/.env').writeAsString('APP_KEY=x');
    await Directory('${public.path}/.git').create();
    await File('${public.path}/.git/config').writeAsString('[core]');
    await Directory('${public.path}/sub/.well-known').create();
    await File('${public.path}/sub/.well-known/a.txt').writeAsString('deep');
    await File('${dir.path}/secret.txt').writeAsString('TOP-SECRET-CONTENT');
    Directory root = Directory('${dir.path}/root');
    await root.create();
    await File('${root.path}/robots.txt').writeAsString('User-agent: *');
    await File('${public.path}/locked.js').writeAsString('locked');
    await Process.run('chmod', <String>['000', '${public.path}/locked.js']);

    Route.get('/assets/route.js', (DoxRequest req) => 'from route');
    Route.staticFiles('assets', public.path);
    Route.staticFiles('cached', public.path, maxAge: const Duration(days: 365));
    Route.staticFiles('/', root.path);
    Route.group('api', () {
      Route.staticFiles('docs', public.path);
    });
    Route.domain('files.test', () {
      Route.staticFiles('only-host', public.path);
    });
    await File('${public.path}/route.js').writeAsString('from file');
    await startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        cors: const CORSConfig(origin: '*'),
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

    // a date in the future is not valid: the file is sent
    req = await client.get('127.0.0.1', port, '/assets/app.js');
    req.headers.set(
      'if-modified-since',
      HttpDate.format(DateTime.now().add(const Duration(days: 30))),
    );
    res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
  });

  Future<HttpClientResponse> getWith(String path, Map<String, String> h) async {
    HttpClientRequest req = await client.get('127.0.0.1', port, path);
    h.forEach(req.headers.set);
    return req.close();
  }

  test('a file gets a weak ETag, and 304 when it matches', () async {
    HttpClientResponse first = await get('/assets/app.js');
    String etag = first.headers.value('etag')!;
    String modified = first.headers.value('last-modified')!;
    await first.drain<void>();
    expect(etag, startsWith('W/"'));

    HttpClientResponse res = await getWith('/assets/app.js', <String, String>{
      'if-none-match': etag,
    });
    expect(res.statusCode, 304);
    expect(res.headers.value('etag'), etag);
    expect(await res.toList(), isEmpty);

    // a list with the tag, and the strong form, also match
    res = await getWith('/assets/app.js', <String, String>{
      'if-none-match': '"other", ${etag.substring(2)}',
    });
    expect(res.statusCode, 304);
    await res.drain<void>();

    // another tag sends the file
    res = await getWith('/assets/app.js', <String, String>{
      'if-none-match': 'W/"other"',
    });
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), 'console.log(1)');

    // If-None-Match wins over If-Modified-Since
    res = await getWith('/assets/app.js', <String, String>{
      'if-none-match': 'W/"other"',
      'if-modified-since': modified,
    });
    expect(res.statusCode, 200);
    await res.drain<void>();

    // HEAD works the same, with no body
    HttpClientRequest req = await client.open(
      'HEAD',
      '127.0.0.1',
      port,
      '/assets/app.js',
    );
    req.headers.set('if-none-match', etag);
    res = await req.close();
    expect(res.statusCode, 304);
    expect(await res.toList(), isEmpty);
    res = await get('/assets/app.js', method: 'HEAD');
    expect(res.headers.value('etag'), etag);
    expect(await res.toList(), isEmpty);
  });

  test('If-None-Match and If-Modified-Since on two lines: no 500', () async {
    HttpClientResponse first = await get('/assets/app.js');
    String etag = first.headers.value('etag')!;
    String modified = first.headers.value('last-modified')!;
    await first.drain<void>();
    String res = await raw(
      port,
      'GET /assets/app.js HTTP/1.1\r\nHost: x\r\n'
      'If-None-Match: W/"a"\r\nIf-None-Match: $etag\r\n'
      'Connection: close\r\n\r\n',
    );
    expect(res, startsWith('HTTP/1.1 304'));
    res = await raw(
      port,
      'GET /assets/app.js HTTP/1.1\r\nHost: x\r\n'
      'If-Modified-Since: $modified\r\nIf-Modified-Since: $modified\r\n'
      'Connection: close\r\n\r\n',
    );
    expect(res, startsWith('HTTP/1.1 200'));
    expect(res, contains('console.log(1)'));
  });

  test('a 304 has the real content type', () async {
    HttpClientResponse first = await get('/assets/app.js');
    String etag = first.headers.value('etag')!;
    await first.drain<void>();
    HttpClientResponse res = await getWith('/assets/app.js', <String, String>{
      'if-none-match': etag,
    });
    expect(res.statusCode, 304);
    expect(res.headers.contentType?.mimeType, 'text/javascript');
    await res.drain<void>();
  });

  test('If-Range: Range only for the same Last-Modified', () async {
    HttpClientResponse first = await get('/assets/app.js');
    String etag = first.headers.value('etag')!;
    String modified = first.headers.value('last-modified')!;
    await first.drain<void>();

    HttpClientResponse res = await getWith('/assets/app.js', <String, String>{
      'range': 'bytes=0-6',
      'if-range': modified,
    });
    expect(res.statusCode, 206);
    expect(await utf8.decodeStream(res), 'console');

    for (String ifRange in <String>[
      etag,
      'W/"stale"',
      HttpDate.format(DateTime.utc(2000)),
      'not a date',
    ]) {
      res = await getWith('/assets/app.js', <String, String>{
        'range': 'bytes=0-6',
        'if-range': ifRange,
      });
      expect(res.statusCode, 200, reason: ifRange);
      expect(await utf8.decodeStream(res), 'console.log(1)', reason: ifRange);
    }
  });

  test('the ETag changes when the file changes', () async {
    File f = File('${dir.path}/public/changing.txt');
    await f.writeAsString('one');
    HttpClientResponse res = await get('/assets/changing.txt');
    String before = res.headers.value('etag')!;
    await res.drain<void>();
    await f.writeAsString('one two');
    res = await get('/assets/changing.txt');
    expect(res.headers.value('etag'), isNot(before));
    await res.drain<void>();
  });

  test('.well-known files are sent', () async {
    HttpClientResponse res = await get(
      '/assets/.well-known/acme-challenge/tok123',
    );
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), 'tok123.key');
    res = await get('/assets/.well-known/security.txt');
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), 'Contact: x');
  });

  test('other dot names, also inside .well-known, get 404', () async {
    for (String path in <String>[
      '/assets/.git/config',
      '/assets/.well-known/.env',
      '/assets/.well-known',
      '/assets/.well-known/',
      '/assets/.well-known/acme-challenge',
      '/assets/sub/.well-known/a.txt',
      '/assets/.well-known/../.env',
      '/assets/.well-known/%2e%2e/.env',
      '/assets/.well-known/..%2f.env',
      '/assets/.Well-Known/security.txt',
    ]) {
      String res = await raw(
        port,
        'GET $path HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      expect(res, startsWith('HTTP/1.1 404'), reason: path);
      expect(res, isNot(contains('APP_KEY')), reason: path);
    }
  });

  test('a Range request gets part of the file', () async {
    HttpClientRequest req = await client.get(
      '127.0.0.1',
      port,
      '/assets/app.js',
    );
    req.headers.set('range', 'bytes=0-6');
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 206);
    expect(await utf8.decodeStream(res), 'console');
  });

  test('prefix / serves the root of the site', () async {
    HttpClientResponse res = await get('/robots.txt');
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), 'User-agent: *');
  });

  test('the prefix follows Route.group', () async {
    HttpClientResponse res = await get('/api/docs/app.js');
    expect(res.statusCode, 200);
    await res.drain<void>();
    res = await get('/docs/app.js');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('Route.domain: only that host gets the files', () async {
    HttpClientRequest req = await client.get(
      '127.0.0.1',
      port,
      '/only-host/app.js',
    );
    req.headers.host = 'files.test';
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
    res = await get('/only-host/app.js');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('a file gets the global CORS headers', () async {
    HttpClientRequest req = await client.get(
      '127.0.0.1',
      port,
      '/assets/app.js',
    );
    req.headers.set('origin', 'http://other.test');
    HttpClientResponse res = await req.close();
    expect(res.headers.value('access-control-allow-origin'), '*');
    await res.drain<void>();
  });

  test('a file that can not be read is 404, not an empty 200', () async {
    File locked = File('${dir.path}/public/locked.js');
    try {
      await (await locked.open()).close();
      markTestSkipped('running as root: every file can be read');
      return;
    } on FileSystemException {
      // expected: no permission
    }
    HttpClientResponse res = await get('/cached/locked.js');
    expect(res.statusCode, 404);
    expect(res.headers.value('cache-control'), isNull);
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
