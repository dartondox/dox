import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import 'requirements/container/app.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    Dox().ioc.override<UserRepository>(FakeUserRepository());
    client = await DoxTestClient.start(containerConfig());
  });

  tearDownAll(() async {
    await client.close();
    Dox().ioc.clearOverrides();
  });

  test('typed route gets the controller from the container', () async {
    (await client.get('/api/users/5')).expectStatus(200).expectBody('fake 5');
  });

  test('a (Controller c) => c.method route without <T> works', () async {
    (await client.get('/api/untyped/7')).expectStatus(200).expectBody('fake 7');
  });

  test('a path param that is not an int is 404', () async {
    (await client.get('/api/users/abc')).expectStatus(404);
  });

  test('one controller per isolate, not per request', () async {
    String first = (await client.get('/api/hash')).body;
    String second = (await client.get('/api/hash')).body;
    expect(first, second);
  });

  test('handler parameters: model binder and injected service', () async {
    (await client.get('/api/posts/3'))
        .expectStatus(200)
        .expectJson(<String, Object>{'post': 3, 'same': true});
    (await client.get('/api/posts/500')).expectStatus(404);
    expect(
      route('posts.show', params: <String, Object>{'post': 3}),
      '/api/posts/3',
    );
  });

  test('a singleton: false class is made per request', () async {
    String first = (await client.get('/api/count')).body;
    String second = (await client.get('/api/count')).body;
    expect(int.parse(second), int.parse(first) + 1);
  });

  test('a plain function gets a service from the container', () async {
    (await client.get('/api/service/2')).expectStatus(200).expectBody('fake 2');
  });

  test('Route.resource with a controller class', () async {
    (await client.get('/api/blogs')).expectStatus(200).expectBody('blogs');
    (await client.get('/api/blogs/4')).expectStatus(200).expectBody('blog 4');
    (await client.post('/api/blogs')).expectStatus(404);
  });

  test('container services run at start', () {
    expect(Dox().ioc.get<SetupService>().ran, isTrue);
    expect(Dox().doxServices.whereType<SetupService>().length, 1);
  });
}
