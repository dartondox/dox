import 'dart:convert';
import 'dart:io';

import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_queue/dox_queue.dart';
import 'package:dox_scheduler/dox_scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/config/schedule.dart';
import 'package:my_app/generated/jobs.g.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// The "Check it" steps of docs/guides, as tests.
/// Uses the database of `.env` (copy it from `.env.example`).
late DoxTestClient client;

/// a 1x1 PNG image
List<int> png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Future<void> deleteDbFile() async {
  if (env.dbConnection != 'sqlite') return;
  for (String suffix in <String>['', '-wal', '-shm']) {
    File file = File('${env.dbName}$suffix');
    if (await file.exists()) await file.delete();
  }
}

void main() {
  setUpAll(() async {
    // start each run with an empty database
    await deleteDbFile();
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
    await deleteDbFile();
  });

  group('jwt-auth.md', () {
    String token = '';

    test('register', () async {
      TestResponse res = await client.post(
        '/api/auth/register',
        body: <String, dynamic>{
          'name': 'Ann',
          'email': 'ann@example.com',
          'password': 'secret123',
        },
      );
      expect(res.status, 200);
      expect(res.json['token'], isA<String>());
      expect(res.json['user']['email'], 'ann@example.com');
      expect(
        (res.json['user'] as Map<String, dynamic>).keys,
        isNot(contains('password')),
      );
    });

    test('a wrong password gives 401', () async {
      TestResponse res = await client.post(
        '/api/auth/login',
        body: <String, dynamic>{
          'email': 'ann@example.com',
          'password': 'wrong',
        },
      );
      expect(res.status, 401);
      expect(res.json, <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Wrong email or password',
        },
      });
    });

    test('log in and use the token', () async {
      TestResponse res = await client.post(
        '/api/auth/login',
        body: <String, dynamic>{
          'email': 'ann@example.com',
          'password': 'secret123',
        },
      );
      expect(res.status, 200);
      token = res.json['token'] as String;

      res = await client.withToken(token).get('/api/auth/me');
      expect(res.status, 200);
      expect(res.json['name'], 'Ann');

      res = await client.withToken(token).post('/api/auth/logout');
      expect(res.json, <String, dynamic>{
        'message': 'Delete the token on the client',
      });
    });

    test('no token gives 401', () async {
      TestResponse res = await client.get('/api/auth/me');
      expect(res.status, 401);
    });
  });

  group('pagination.md', () {
    setUpAll(() async {
      for (int i = 2; i <= 3; i++) {
        await client.post(
          '/api/auth/register',
          body: <String, dynamic>{
            'name': 'User $i',
            'email': 'user$i@example.com',
            'password': 'secret123',
          },
        );
      }
    });

    test('page 2 of 2', () async {
      TestResponse res = await client.get('/api/users?page=2&per_page=2');
      expect(res.status, 200);
      Map<String, dynamic> page = res.json as Map<String, dynamic>;
      expect(page['total'], 3);
      expect(page['per_page'], 2);
      expect(page['last_page'], 2);
      expect(page['current_page'], 2);
      expect((page['data'] as List<dynamic>).single['id'], 1);
    });

    test('a page after the last one has no data', () async {
      TestResponse res = await client.get('/api/users?page=9&per_page=2');
      expect(res.json['data'], isEmpty);
    });

    test('bad input gives 422', () async {
      TestResponse res = await client.get('/api/users?page=0&per_page=500');
      expect(res.status, 422);
      expect(res.json['errors'], <String, dynamic>{
        'page': 'The page must be greater than or equal 1',
        'per_page': 'The per_page must be between 1 and 100',
      });
    });
  });

  group('custom-errors.md', () {
    test('GET /api/users/999 gives 404', () async {
      TestResponse res = await client.get('/api/users/999');
      expect(res.status, 404);
      expect(res.json, <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'not_found',
          'message': 'User 999 not found',
        },
      });
    });

    test('GET /api/users/abc gives 404', () async {
      TestResponse res = await client.get('/api/users/abc');
      expect(res.status, 404);
      expect(res.json['error']['code'], 'not_found');
    });

    test('DELETE /api/users/1 gives 403', () async {
      TestResponse res = await client.delete('/api/users/1');
      expect(res.status, 403);
      expect(res.json, <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'forbidden',
          'message': 'The first user can not be deleted',
        },
      });
    });

    test('register with {} gives 422', () async {
      TestResponse res = await client.post(
        '/api/auth/register',
        body: <String, dynamic>{},
      );
      expect(res.status, 422);
      expect(res.json['error'], <String, dynamic>{
        'code': 'validation_failed',
        'message': 'The input is not valid',
      });
      expect(res.json['errors']['name'], 'The name is required');
    });

    test('GET /api/boom gives 500 with no details', () async {
      TestResponse res = await client.get('/api/boom');
      expect(res.status, 500);
      expect(res.json, <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'Something went wrong',
        },
      });
    });
  });

  group('file-upload.md', () {
    Future<TestResponse> upload(List<int> bytes, String name) async {
      http.MultipartRequest req =
          http.MultipartRequest('POST', client.baseUri.resolve('/api/upload'))
            ..files.add(
              http.MultipartFile.fromBytes('image', bytes, filename: name),
            );
      http.Response res = await http.Response.fromStream(await req.send());
      return TestResponse(res.statusCode, res.headers, res.bodyBytes);
    }

    test('upload a PNG and get it back', () async {
      TestResponse res = await upload(png, 'photo.png');
      expect(res.status, 200);
      String path = res.json['path'] as String;
      expect(path, matches(RegExp(r'^/images/[0-9a-f-]+\.png$')));
      expect(res.json['url'], '${env.appUrl}/files$path');

      res = await client.get('/files$path');
      expect(res.status, 200);
      expect(res.bodyBytes, png);
      await File('storage$path').delete();
    });

    test('a text file gives 422', () async {
      TestResponse res = await upload(utf8.encode('hello'), 'notes.txt');
      expect(res.status, 422);
      expect(res.json['errors'], <String, dynamic>{
        'image': 'The image must be an image',
      });
    });
  });

  group('background-work.md', () {
    test('POST /api/reports answers at once', () async {
      TestResponse res = await client.post('/api/reports');
      expect(res.status, 200);
      expect(res.json['status'], 'queued');
    });

    test('POST /api/reports/queued saves a job, the worker runs it', () async {
      TestResponse res = await client.post('/api/reports/queued');
      expect(res.status, 200);
      expect(res.json['status'], 'queued');
      expect(await QueryBuilder.table('jobs').count(), 1);

      await Worker(
        driver: Queue.driver,
        jobs: jobRegistry,
        options: WorkerOptions(stopWhenEmpty: true),
      ).run();
      expect(await QueryBuilder.table('jobs').count(), 0);
    });

    test('the cleanup task runs every hour', () async {
      Schedule s = Schedule();
      schedule(s);
      ScheduledTask cleanup = s.tasks.single;
      expect(cleanup.name, 'cleanup');
      expect(cleanup.isDue(DateTime.utc(2026, 10, 25, 2)), isTrue);
      expect(cleanup.isDue(DateTime.utc(2026, 10, 25, 2, 30)), isFalse);
      await cleanupUsers();
    });

    test('GET /api/primes/100000', () async {
      TestResponse res = await client.get('/api/primes/100000');
      expect(res.json, <String, dynamic>{'limit': 100000, 'primes': 9592});
    });
  });

  group('docker.md', () {
    test('GET /health', () async {
      TestResponse res = await client.get('/health');
      expect(res.status, 200);
      expect(res.json, <String, dynamic>{
        'status': 'ok',
        'checks': <String, dynamic>{'database': 'ok'},
      });
    });
  });

  group('static-files.md', () {
    test('GET /static/app.js serves the file', () async {
      TestResponse res = await client.get('/static/app.js');
      expect(res.status, 200);
      expect(res.body, File('public/app.js').readAsStringSync());
    });

    test('GET / and an SPA URL give index.html with no cache', () async {
      for (String path in <String>['/', '/settings/profile']) {
        TestResponse res = await client.get(path);
        expect(res.status, 200);
        expect(res.headers['cache-control'], 'max-age=0');
        expect(res.body, contains('<div id="app">'));
      }
    });

    test('GET /assets/app.js has a long cache', () async {
      TestResponse res = await client.get('/assets/app.js');
      expect(res.status, 200);
      expect(res.headers['cache-control'], 'max-age=31536000');
    });

    test('missing files and unknown API URLs give 404', () async {
      expect((await client.get('/assets/nope.js')).status, 404);
      expect((await client.get('/assets/..%2Fpubspec.yaml')).status, 404);
      expect((await client.get('/api/nothing')).status, 404);
    });
  });

  group('cors-for-spa.md', () {
    test('the preflight request', () async {
      TestResponse res = await client.send(
        'OPTIONS',
        '/api/users',
        headers: <String, String>{
          'Origin': 'http://localhost:5173',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'Authorization',
        },
      );
      expect(res.status, 204);
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
      TestResponse res = await client.get(
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
