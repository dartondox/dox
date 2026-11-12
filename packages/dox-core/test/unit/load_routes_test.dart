import 'dart:io';

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
    Route.fallback((DoxRequest req) => 'none');
    Route.mount('raw', _raw, middleware: true);
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

Future<void> _raw(HttpRequest req) async {}

void main() {
  void init() {
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
  }

  test('loadRoutes registers the routers, not the providers', () {
    init();
    AppRoutes loaded = Dox().loadRoutes();
    List<RouteData> routes = loaded.routes;

    expect(routes.map((RouteData r) => '${r.method} ${r.path}'), <String>[
      'GET /api/ping',
      'POST /users',
    ]);
    expect(routes.first.name, 'api.ping');
    expect(routes.first.preMiddleware.map((dynamic m) => m.runtimeType), <Type>[
      _Global,
      _Api,
    ]);
    expect(loaded.fallbacks.single.path, '/api');
    expect(loaded.mounts.keys, <String>['raw']);
    expect(loaded.mountsWithMiddleware, <String>{'raw'});
    expect(_Provider.setups, 0);
  });

  test('loadRoutes twice, then a normal start: no duplicates', () async {
    init();
    Dox().loadRoutes();
    AppRoutes second = Dox().loadRoutes();
    expect(second.routes, hasLength(2));
    // Route() is empty again, so the server start registers clean
    expect(Route().routes, isEmpty);
    expect(Route().fallbacks, isEmpty);
    expect(Route().mounts, isEmpty);

    // what startServer does: providers, then the routes. A named route
    // that was there already would throw "is used twice".
    Dox().addProviders(Dox().config.providers);
    await Dox().startProviders();
    expect(
      Route().routes.where((RouteData r) => r.name == 'api.ping'),
      hasLength(1),
    );
    expect(Route().fallbacks, hasLength(1));
    expect(_Provider.setups, greaterThan(0));
  });
}
