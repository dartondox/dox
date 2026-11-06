import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

const Map<String, String> form = <String, String>{
  'content-type': 'application/x-www-form-urlencoded',
};

class FormRouter extends Router {
  @override
  void register() {
    Route.put('post/{id}', (DoxRequest req) {
      return 'put ${req.param['id']} ${req.method} ${req.input('title')}';
    });
    Route.delete('post/{id}', (DoxRequest req) => 'delete ${req.method}');
    Route.post('post/{id}', (DoxRequest req) => 'post ${req.method}');
    Route.get('post/{id}', (DoxRequest req) => 'get ${req.method}');
  }
}

class CsrfRouter extends Router {
  @override
  String get prefix => 'safe';

  @override
  List<dynamic> get middleware => <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(),
  ];

  @override
  void register() {
    Route.get('form', (DoxRequest req) => 'form');
    Route.put('save', (DoxRequest req) => 'saved ${req.method}');
  }
}

AppConfig config(List<dynamic> global) {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    globalMiddleware: global,
    routers: <Router>[FormRouter(), CsrfRouter()],
  );
}

void main() {
  group('with MethodOverride', () {
    late DoxTestClient client;

    setUpAll(() async {
      client = await DoxTestClient.start(
        config(<dynamic>[const MethodOverride()]),
      );
    });

    tearDownAll(() async {
      await client.close();
    });

    test('a form POST with _method=PUT reaches the PUT route', () async {
      (await client.post(
        '/post/5',
        body: '_method=PUT&title=Hi',
        headers: form,
      )).expectStatus(200).expectBody('put 5 PUT Hi');
    });

    test('_method in lower case and in a JSON body works', () async {
      (await client.post(
        '/post/5',
        body: '_method=delete',
        headers: form,
      )).expectBody('delete DELETE');
      (await client.post(
        '/post/5',
        body: <String, dynamic>{'_method': 'PUT', 'title': 'J'},
      )).expectBody('put 5 PUT J');
    });

    test('a POST with no or an unknown _method stays POST', () async {
      (await client.post('/post/5')).expectBody('post POST');
      (await client.post(
        '/post/5',
        body: '_method=GET',
        headers: form,
      )).expectBody('post POST');
      (await client.post(
        '/post/5',
        body: '_method=OPTIONS',
        headers: form,
      )).expectBody('post POST');
    });

    test('405 names the method of _method', () async {
      (await client.post('/safe/form', body: '_method=PATCH', headers: form))
          .expectStatus(405)
          .expectBody(contains('PATCH is not allowed for /safe/form'));
    });

    test('a POST to an unknown path is 404 before the body is read', () async {
      // a broken multipart body gives an error when it is read
      (await client.post(
        '/nowhere',
        body: 'not multipart',
        headers: <String, String>{'content-type': 'multipart/form-data'},
      )).expectStatus(404);
    });

    test('the X-HTTP-Method-Override header is off by default', () async {
      (await client.post(
        '/post/5',
        headers: <String, String>{'X-HTTP-Method-Override': 'DELETE'},
      )).expectBody('post POST');
    });

    test('a GET with _method is not changed', () async {
      (await client.get('/post/5?_method=DELETE')).expectBody('get GET');
    });

    test('CSRF still checks the changed request', () async {
      (await client.post(
        '/safe/save',
        body: '_method=PUT',
        headers: form,
      )).expectStatus(419);

      DoxTestClient browser = client.withSession();
      TestResponse page = await browser.get('/safe/form');
      String token = page.cookies[CsrfMiddleware.cookieName]!;
      (await browser.post(
        '/safe/save',
        body: '_method=PUT&_token=$token',
        headers: form,
      )).expectStatus(200).expectBody('saved PUT');
    });
  });

  group('without MethodOverride', () {
    late DoxTestClient client;

    setUpAll(() async {
      client = await DoxTestClient.start(config(<dynamic>[]));
    });

    tearDownAll(() async {
      await client.close();
    });

    test('_method does nothing', () async {
      (await client.post(
        '/post/5',
        body: '_method=PUT&title=Hi',
        headers: form,
      )).expectStatus(200).expectBody('post POST');
    });
  });

  group('with MethodOverride(header: true)', () {
    late DoxTestClient client;

    setUpAll(() async {
      client = await DoxTestClient.start(
        config(<dynamic>[const MethodOverride(header: true)]),
      );
    });

    tearDownAll(() async {
      await client.close();
    });

    test('the header changes a POST, and wins over _method', () async {
      (await client.post(
        '/post/5',
        headers: <String, String>{'X-HTTP-Method-Override': 'delete'},
      )).expectBody('delete DELETE');
      (await client.post(
        '/post/5',
        body: '_method=DELETE&title=H',
        headers: <String, String>{...form, 'X-HTTP-Method-Override': 'PUT'},
      )).expectBody('put 5 PUT H');
    });

    test('an unknown header value falls back to _method', () async {
      (await client.post(
        '/post/5',
        body: '_method=DELETE',
        headers: <String, String>{...form, 'X-HTTP-Method-Override': 'GET'},
      )).expectBody('delete DELETE');
    });

    test('a GET with the header is not changed', () async {
      (await client.get(
        '/post/5',
        headers: <String, String>{'X-HTTP-Method-Override': 'DELETE'},
      )).expectBody('get GET');
    });
  });
}
