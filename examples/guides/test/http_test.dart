import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:my_app/config/env.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// The "Check it" steps of docs/guides, as tests.
/// Uses the database of `.env` (copy it from `.env.example`).
String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

/// a 1x1 PNG image
List<int> png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Future<http.Response> postJson(
  String path,
  Map<String, dynamic> body, {
  Map<String, String>? headers,
}) {
  return http.post(
    Uri.parse('$baseUrl$path'),
    headers: <String, String>{'Content-Type': 'application/json', ...?headers},
    body: jsonEncode(body),
  );
}

Future<http.Response> get(String path, {Map<String, String>? headers}) {
  return http.get(Uri.parse('$baseUrl$path'), headers: headers);
}

dynamic json(http.Response res) => jsonDecode(res.body);

Future<void> deleteDbFile() async {
  if (env.dbConnection != 'sqlite') return;
  for (String suffix in <String>['', '-wal', '-shm']) {
    File file = File('${env.dbName}$suffix');
    if (await file.exists()) await file.delete();
  }
}

void main() {
  setUpAll(() async {
    // port 0: the OS picks a free port, so test files can run in parallel.
    // Set it before the app reads its env.
    Env().load();
    Env().env['APP_PORT'] = '0';
    // start each run with an empty database
    await deleteDbFile();
    Dox().initialize(appConfig);
    Dox().totalIsolate(1);
    await Migrator(
      migrations: migrations,
      connection: await databaseConfig
          .getConnectionConfig()
          .getDatabaseConnection(),
    ).migrate();
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close();
    await deleteDbFile();
  });

  group('jwt-auth.md', () {
    String token = '';

    test('register', () async {
      http.Response res = await postJson(
        '/api/auth/register',
        <String, dynamic>{
          'name': 'Ann',
          'email': 'ann@example.com',
          'password': 'secret123',
        },
      );
      expect(res.statusCode, 200);
      expect(json(res)['token'], isA<String>());
      expect(json(res)['user']['email'], 'ann@example.com');
      expect(
        (json(res)['user'] as Map<String, dynamic>).keys,
        isNot(contains('password')),
      );
    });

    test('a wrong password gives 401', () async {
      http.Response res = await postJson('/api/auth/login', <String, dynamic>{
        'email': 'ann@example.com',
        'password': 'wrong',
      });
      expect(res.statusCode, 401);
      expect(json(res), <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Wrong email or password',
        },
      });
    });

    test('log in and use the token', () async {
      http.Response res = await postJson('/api/auth/login', <String, dynamic>{
        'email': 'ann@example.com',
        'password': 'secret123',
      });
      expect(res.statusCode, 200);
      token = json(res)['token'] as String;

      res = await get(
        '/api/auth/me',
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      expect(res.statusCode, 200);
      expect(json(res)['name'], 'Ann');

      res = await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      expect(json(res), <String, dynamic>{
        'message': 'Delete the token on the client',
      });
    });

    test('no token gives 401', () async {
      http.Response res = await get('/api/auth/me');
      expect(res.statusCode, 401);
    });
  });

  group('pagination.md', () {
    setUpAll(() async {
      for (int i = 2; i <= 3; i++) {
        await postJson('/api/auth/register', <String, dynamic>{
          'name': 'User $i',
          'email': 'user$i@example.com',
          'password': 'secret123',
        });
      }
    });

    test('page 2 of 2', () async {
      http.Response res = await get('/api/users?page=2&per_page=2');
      expect(res.statusCode, 200);
      Map<String, dynamic> page = json(res) as Map<String, dynamic>;
      expect(page['total'], 3);
      expect(page['per_page'], 2);
      expect(page['last_page'], 2);
      expect(page['current_page'], 2);
      expect((page['data'] as List<dynamic>).single['id'], 1);
    });

    test('a page after the last one has no data', () async {
      http.Response res = await get('/api/users?page=9&per_page=2');
      expect(json(res)['data'], isEmpty);
    });

    test('bad input gives 422', () async {
      http.Response res = await get('/api/users?page=0&per_page=500');
      expect(res.statusCode, 422);
      expect(json(res)['errors'], <String, dynamic>{
        'page': 'The page must be greater than or equal 1',
        'per_page': 'The per_page must be between 1 and 100',
      });
    });
  });

  group('custom-errors.md', () {
    test('GET /api/users/999 gives 404', () async {
      http.Response res = await get('/api/users/999');
      expect(res.statusCode, 404);
      expect(json(res), <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'not_found',
          'message': 'User 999 not found',
        },
      });
    });

    test('GET /api/users/abc gives 404', () async {
      http.Response res = await get('/api/users/abc');
      expect(res.statusCode, 404);
      expect(json(res)['error']['code'], 'not_found');
    });

    test('DELETE /api/users/1 gives 403', () async {
      http.Response res = await http.delete(Uri.parse('$baseUrl/api/users/1'));
      expect(res.statusCode, 403);
      expect(json(res), <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'forbidden',
          'message': 'The first user can not be deleted',
        },
      });
    });

    test('register with {} gives 422', () async {
      http.Response res = await postJson(
        '/api/auth/register',
        <String, dynamic>{},
      );
      expect(res.statusCode, 422);
      expect(json(res)['error'], <String, dynamic>{
        'code': 'validation_failed',
        'message': 'The input is not valid',
      });
      expect(json(res)['errors']['name'], 'The name is required');
    });

    test('GET /api/boom gives 500 with no details', () async {
      http.Response res = await get('/api/boom');
      expect(res.statusCode, 500);
      expect(json(res), <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'Something went wrong',
        },
      });
    });
  });

  group('file-upload.md', () {
    Future<http.Response> upload(List<int> bytes, String name) async {
      http.MultipartRequest req =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'))
            ..files.add(
              http.MultipartFile.fromBytes('image', bytes, filename: name),
            );
      return http.Response.fromStream(await req.send());
    }

    test('upload a PNG and get it back', () async {
      http.Response res = await upload(png, 'photo.png');
      expect(res.statusCode, 200);
      String path = json(res)['path'] as String;
      expect(path, matches(RegExp(r'^/images/[0-9a-f-]+\.png$')));
      expect(json(res)['url'], '${env.appUrl}/files$path');

      res = await get('/files$path');
      expect(res.statusCode, 200);
      expect(res.bodyBytes, png);
      await File('storage$path').delete();
    });

    test('a text file gives 422', () async {
      http.Response res = await upload(utf8.encode('hello'), 'notes.txt');
      expect(res.statusCode, 422);
      expect(json(res)['errors'], <String, dynamic>{
        'image': 'The image must be an image',
      });
    });
  });

  group('background-work.md', () {
    test('POST /api/reports answers at once', () async {
      http.Response res = await http.post(Uri.parse('$baseUrl/api/reports'));
      expect(res.statusCode, 200);
      expect(json(res)['status'], 'queued');
    });

    test('GET /api/primes/100000', () async {
      http.Response res = await get('/api/primes/100000');
      expect(json(res), <String, dynamic>{'limit': 100000, 'primes': 9592});
    });
  });

  group('docker.md', () {
    test('GET /health', () async {
      http.Response res = await get('/health');
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{'status': 'ok'});
    });
  });

  group('static-files.md', () {
    test('GET /static/app.js serves the file', () async {
      http.Response res = await get('/static/app.js');
      expect(res.statusCode, 200);
      expect(res.body, File('public/app.js').readAsStringSync());
    });

    test('GET / and an SPA URL give index.html with no cache', () async {
      for (String path in <String>['/', '/settings/profile']) {
        http.Response res = await get(path);
        expect(res.statusCode, 200);
        expect(res.headers['cache-control'], 'max-age=0');
        expect(res.body, contains('<div id="app">'));
      }
    });

    test('GET /assets/app.js has a long cache', () async {
      http.Response res = await get('/assets/app.js');
      expect(res.statusCode, 200);
      expect(res.headers['cache-control'], 'max-age=31536000');
    });

    test('missing files and unknown API URLs give 404', () async {
      expect((await get('/assets/nope.js')).statusCode, 404);
      expect((await get('/assets/..%2Fpubspec.yaml')).statusCode, 404);
      expect((await get('/api/nothing')).statusCode, 404);
    });
  });

  group('cors-for-spa.md', () {
    test('the preflight request', () async {
      http.Request req =
          http.Request('OPTIONS', Uri.parse('$baseUrl/api/users'))
            ..headers.addAll(<String, String>{
              'Origin': 'http://localhost:5173',
              'Access-Control-Request-Method': 'POST',
              'Access-Control-Request-Headers': 'Authorization',
            });
      http.Response res = await http.Response.fromStream(await req.send());
      expect(res.statusCode, 204);
      expect(
        res.headers['access-control-allow-origin'],
        'http://localhost:5173',
      );
      expect(
        res.headers['access-control-allow-methods'],
        'GET,POST,PUT,PATCH,DELETE',
      );
      expect(
        res.headers['access-control-allow-headers'],
        'Content-Type,Authorization',
      );
      expect(res.headers['access-control-max-age'], '600');
    });

    test('a normal request gets the origin header', () async {
      http.Response res = await get(
        '/api/ping',
        headers: <String, String>{'Origin': 'http://localhost:5173'},
      );
      expect(res.body, 'pong');
      expect(
        res.headers['access-control-allow-origin'],
        'http://localhost:5173',
      );
    });
  });
}
