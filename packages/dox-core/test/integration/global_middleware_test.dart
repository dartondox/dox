import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

List<String> calls = <String>[];

Future<DoxResponse> fromPackage(DoxRequest req, Next next) async {
  calls.add('package');
  DoxResponse res = await next();
  return res.header('X-Package', 'yes');
}

/// only plain types
Future<Object?> plain(Object? req, Future<Object?> Function() next) async {
  calls.add('plain');
  return next();
}

dynamic appFirst(DoxRequest req) {
  calls.add('app');
  return req;
}

class PackageProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    Dox().addGlobalMiddleware(fromPackage);
    Dox().addGlobalMiddleware(fromPackage);
    Dox().addGlobalMiddleware(plain);
  }
}

class Inst implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => null;
}

class InstanceProvider extends DoxProvider {
  @override
  Future<void> setup() async => Dox().addGlobalMiddleware(Inst());
}

class TestRouter extends Router {
  @override
  void register() {
    Route.get('/one', (DoxRequest req) {
      calls.add('controller');
      return 'one';
    });
    Route.get('/two', (DoxRequest req) => 'two');
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    GlobalMiddleware.clear();
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        globalMiddleware: <dynamic>[appFirst],
        providers: <DoxProvider>[PackageProvider()],
        routers: <Router>[TestRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
    GlobalMiddleware.clear();
  });

  setUp(calls.clear);

  test('runs before the app globalMiddleware, once, on every route', () async {
    (await client.get('/one'))
        .expectStatus(200)
        .expectBody('one')
        .expectHeader('x-package', 'yes');
    expect(calls, <String>['package', 'plain', 'app', 'controller']);
    (await client.get('/two'))
        .expectBody('two')
        .expectHeader('x-package', 'yes');
  });

  test('starting twice does not add a new instance twice', () async {
    GlobalMiddleware.clear();
    DoxTestClient second = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        providers: <DoxProvider>[InstanceProvider(), InstanceProvider()],
        routers: <Router>[TestRouter()],
      ),
    );
    await second.close();
    expect(GlobalMiddleware.items.whereType<Inst>().length, 2);
    GlobalMiddleware.clear();
    DoxTestClient third = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        providers: <DoxProvider>[InstanceProvider()],
        routers: <Router>[TestRouter()],
      ),
    );
    await third.close();
    expect(GlobalMiddleware.items.whereType<Inst>().length, 1);
  });

  test('clear then add gives the new list', () {
    GlobalMiddleware.clear();
    GlobalMiddleware.add(fromPackage);
    expect(Dox().allGlobalMiddleware.first, fromPackage);
    GlobalMiddleware.clear();
    GlobalMiddleware.add(plain);
    expect(Dox().allGlobalMiddleware.first, plain);
  });

  test('a function with plain types is a next middleware', () {
    // this line does not compile unless it matches
    NextMiddlewareFunction asNext = plain;
    expect(asNext, isNotNull);
  });
}
