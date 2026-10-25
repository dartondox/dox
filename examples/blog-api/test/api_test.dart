import 'dart:convert';

import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// The `curl` checks of the tutorial (docs/tutorial), as tests.
String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

Map<String, String> jsonHeaders = <String, String>{
  'Content-Type': 'application/json',
};

Future<http.Response> post(
  String path,
  Map<String, dynamic> body, {
  String? token,
}) {
  return http.post(
    Uri.parse('$baseUrl$path'),
    headers: <String, String>{
      ...jsonHeaders,
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
}

void main() {
  // a new email on each run, so the test works on an old database too
  String email = 'ann${DateTime.now().microsecondsSinceEpoch}@example.com';
  String token = '';
  int postId = 0;

  setUpAll(() async {
    // port 0: the OS picks a free port, so test files can run in parallel.
    // Set it before the app reads its env.
    Env().load();
    Env().env['APP_PORT'] = '0';
    Dox().initialize(appConfig);
    Dox().totalIsolate(1);
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test('step 1: GET /api/ping', () async {
    http.Response res = await http.get(Uri.parse('$baseUrl/api/ping'));
    expect(res.statusCode, 200);
    expect(res.body, 'pong');
  });

  test('step 5: register, then the same email again', () async {
    Map<String, dynamic> user = <String, dynamic>{
      'name': 'Ann',
      'email': email,
      'password': 'secret123',
    };
    http.Response res = await post('/api/auth/register', user);
    expect(res.statusCode, 201);
    Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['token'], isA<String>());
    expect(
      (body['user'] as Map<String, dynamic>).containsKey('password'),
      isFalse,
    );

    res = await post('/api/auth/register', user);
    expect(res.statusCode, 422);
    expect(jsonDecode(res.body), <String, dynamic>{
      'email': 'The email has already been taken',
    });
  });

  test('step 5: login', () async {
    http.Response res = await post('/api/auth/login', <String, dynamic>{
      'email': email,
      'password': 'wrong',
    });
    expect(res.statusCode, 401);
    expect(jsonDecode(res.body), <String, dynamic>{
      'code': 'unauthorized',
      'message': 'Wrong email or password',
    });

    res = await post('/api/auth/login', <String, dynamic>{
      'email': email,
      'password': 'secret123',
    });
    expect(res.statusCode, 200);
    token = (jsonDecode(res.body) as Map<String, dynamic>)['token'] as String;
  });

  test('step 5: a post without a token is refused', () async {
    http.Response res = await post('/api/posts', <String, dynamic>{
      'title': 'Third post',
      'body': 'Written with a token.',
    });
    expect(res.statusCode, 401);
    expect(jsonDecode(res.body), <String, dynamic>{
      'code': 'unauthorized',
      'message': 'Authentication failed',
    });
  });

  test('step 4: bad input gets 422', () async {
    http.Response res = await post('/api/posts', <String, dynamic>{
      'title': 'Hi',
      'body': 'Short',
    }, token: token);
    expect(res.statusCode, 422);
    expect(jsonDecode(res.body), <String, dynamic>{
      'title': 'The title must be between 3 and 100 characters',
      'body': 'The body must be at least 10 characters',
    });

    res = await post('/api/posts', <String, dynamic>{}, token: token);
    expect(res.statusCode, 422);
    expect(jsonDecode(res.body), <String, dynamic>{
      'title': 'The title is required',
      'body': 'The body is required',
    });
  });

  test('step 3 and 5: make a post with a token, then show it', () async {
    http.Response res = await post('/api/posts', <String, dynamic>{
      'title': 'Hello Dox',
      'body': 'My first post.',
    }, token: token);
    expect(res.statusCode, 201);
    Map<String, dynamic> created = jsonDecode(res.body) as Map<String, dynamic>;
    expect(created['title'], 'Hello Dox');
    postId = created['id'] as int;

    res = await http.get(Uri.parse('$baseUrl/api/posts/$postId'));
    expect(res.statusCode, 200);
    expect(
      (jsonDecode(res.body) as Map<String, dynamic>)['body'],
      'My first post.',
    );
  });

  test('step 4: update the post', () async {
    http.Response res = await http.put(
      Uri.parse('$baseUrl/api/posts/$postId'),
      headers: <String, String>{
        ...jsonHeaders,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'title': 'Hello Dox (edited)',
        'body': 'My first post, edited.',
      }),
    );
    expect(res.statusCode, 200);
    expect(
      (jsonDecode(res.body) as Map<String, dynamic>)['title'],
      'Hello Dox (edited)',
    );
  });

  test('step 3: a post that does not exist gives 404', () async {
    http.Response res = await http.get(Uri.parse('$baseUrl/api/posts/999999'));
    expect(res.statusCode, 404);
    res = await http.get(Uri.parse('$baseUrl/api/posts/abc'));
    expect(res.statusCode, 404);
  });

  test('step 5: GET /api/auth/user', () async {
    http.Response res = await http.get(
      Uri.parse('$baseUrl/api/auth/user'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    expect(res.statusCode, 200);
    Map<String, dynamic> user = jsonDecode(res.body) as Map<String, dynamic>;
    expect(user['email'], email);
    expect(user.containsKey('password'), isFalse);
  });
}
