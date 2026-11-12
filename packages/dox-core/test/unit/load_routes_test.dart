import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:test/test.dart';

class _Global implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

class _Api implements IDoxMiddleware {
  @override
  dynamic handle(IDoxRequest req) => req;
}

class _ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[_Api()];

  @override
  void register() {
    Route.get('ping', (DoxRequest req) => 'pong').name('api.ping');
  }
}

class _ContainerRouter extends Router {
  @override
  void register() {
    Route.post('users', (DoxRequest req) => 'ok');
  }
}

class _Provider extends DoxProvider {
  static int setups = 0;

  @override
  void setup() {
    setups++;
    Route.get('from-provider', (DoxRequest req) => 'no');
  }
}

void main() {
  test('loadRoutes registers the routers, not the providers', () {
    Route().setRoutes(<RouteData>[]);
    Dox().initialize(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        globalMiddleware: <dynamic>[_Global()],
        routers: <Router>[_ApiRouter()],
        providers: <DoxProvider>[_Provider()],
        container: (IocContainer c) {
          c.router<_ContainerRouter>((IocContainer c) => _ContainerRouter());
        },
      ),
    );

    List<RouteData> routes = Dox().loadRoutes();

    expect(routes.map((RouteData r) => '${r.method} ${r.path}'), <String>[
      'GET /api/ping',
      'POST /users',
    ]);
    expect(routes.first.name, 'api.ping');
    expect(routes.first.preMiddleware.map((dynamic m) => m.runtimeType), <Type>[
      _Global,
      _Api,
    ]);
    expect(_Provider.setups, 0);
  });
}
