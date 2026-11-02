import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

/// a fallback in a domain, and no normal route with a domain
class DomainFallbackRouter extends Router {
  @override
  void register() {
    Route.get('ping', (DoxRequest req) => 'pong');
    Route.domain('admin.example.com', () {
      Route.fallback((DoxRequest req) => 'admin fallback');
    });
  }
}

Map<String, String> admin = <String, String>{'host': 'admin.example.com'};

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[DomainFallbackRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  test('a domain fallback works with no other domain route', () async {
    (await client.get('/nope', headers: admin)).expectBody('admin fallback');
    (await client.get('/nope')).expectStatus(404);
  });

  test('a domain fallback works next to other domain routes', () async {
    Route.domain('api.example.com', () {
      Route.get('status', (DoxRequest req) => 'api ok');
    });
    (await client.get(
      '/status',
      headers: <String, String>{'host': 'api.example.com'},
    )).expectBody('api ok');
    (await client.get('/nope', headers: admin)).expectBody('admin fallback');
    (await client.get('/nope')).expectStatus(404);
  });
}
