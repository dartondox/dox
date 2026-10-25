import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// The `curl` checks of the tutorial (docs/tutorial), as tests.
void main() {
  // a new email on each run, so the test works on an old database too
  String email = 'ann${DateTime.now().microsecondsSinceEpoch}@example.com';
  String token = '';
  int postId = 0;

  late DoxTestClient client;

  setUpAll(() async {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('step 1: GET /api/ping', () async {
    (await client.get('/api/ping')).expectStatus(200).expectBody('pong');
  });

  test('step 5: register, then the same email again', () async {
    Map<String, dynamic> user = <String, dynamic>{
      'name': 'Ann',
      'email': email,
      'password': 'secret123',
    };
    TestResponse res = await client.post('/api/auth/register', body: user);
    res.expectStatus(201);
    expect(res.json['token'], isA<String>());
    expect(
      (res.json['user'] as Map<String, dynamic>).keys,
      isNot(contains('password')),
    );

    res = await client.post('/api/auth/register', body: user);
    res.expectStatus(422).expectJson(<String, dynamic>{
      'email': 'The email has already been taken',
    });
  });

  test('step 5: login', () async {
    TestResponse res = await client.post(
      '/api/auth/login',
      body: <String, dynamic>{'email': email, 'password': 'wrong'},
    );
    res.expectStatus(401).expectJson(<String, dynamic>{
      'code': 'unauthorized',
      'message': 'Wrong email or password',
    });

    res = await client.post(
      '/api/auth/login',
      body: <String, dynamic>{'email': email, 'password': 'secret123'},
    );
    res.expectStatus(200);
    token = res.json['token'] as String;
  });

  test('step 5: a post without a token is refused', () async {
    TestResponse res = await client.post(
      '/api/posts',
      body: <String, dynamic>{
        'title': 'Third post',
        'body': 'Written with a token.',
      },
    );
    res.expectStatus(401).expectJson(<String, dynamic>{
      'code': 'unauthorized',
      'message': 'Authentication failed',
    });
  });

  test('step 4: bad input gets 422', () async {
    DoxTestClient ann = client.withToken(token);
    TestResponse res = await ann.post(
      '/api/posts',
      body: <String, dynamic>{'title': 'Hi', 'body': 'Short'},
    );
    res.expectStatus(422).expectJson(<String, dynamic>{
      'title': 'The title must be between 3 and 100 characters',
      'body': 'The body must be at least 10 characters',
    });

    res = await ann.post('/api/posts', body: <String, dynamic>{});
    res.expectStatus(422).expectJson(<String, dynamic>{
      'title': 'The title is required',
      'body': 'The body is required',
    });
  });

  test('step 3 and 5: make a post with a token, then show it', () async {
    TestResponse res = await client
        .withToken(token)
        .post(
          '/api/posts',
          body: <String, dynamic>{
            'title': 'Hello Dox',
            'body': 'My first post.',
          },
        );
    res.expectStatus(201).expectJson(containsPair('title', 'Hello Dox'));
    postId = res.json['id'] as int;

    res = await client.get('/api/posts/$postId');
    res.expectStatus(200).expectJson(containsPair('body', 'My first post.'));
  });

  test('step 4: update the post', () async {
    TestResponse res = await client
        .withToken(token)
        .put(
          '/api/posts/$postId',
          body: <String, dynamic>{
            'title': 'Hello Dox (edited)',
            'body': 'My first post, edited.',
          },
        );
    res
        .expectStatus(200)
        .expectJson(containsPair('title', 'Hello Dox (edited)'));
  });

  test('step 3: a post that does not exist gives 404', () async {
    (await client.get('/api/posts/999999')).expectStatus(404);
    (await client.get('/api/posts/abc')).expectStatus(404);
  });

  test('step 5: GET /api/auth/user', () async {
    TestResponse res = await client.withToken(token).get('/api/auth/user');
    res.expectStatus(200).expectJson(containsPair('email', email));
    expect(
      (res.json as Map<String, dynamic>).keys,
      isNot(contains('password')),
    );
  });
}
