import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/http/http_static_handler.dart';
import 'package:test/test.dart';

import '../integration/requirements/controllers/admin.controller.dart';
import '../integration/requirements/controllers/blog.controller.dart';

void main() {
  group('Route |', () {
    setUp(() {
      Route().setRoutes(<RouteData>[]);
    });

    test('setStatics with its own list keeps the folders', () {
      Route().setStatics(<StaticFolder>[]);
      Route.staticFiles('/', 'public');
      Route().setStatics(Route().statics);
      expect(Route().statics.length, 1);
      Route().setStatics(<StaticFolder>[]);
    });

    test('a throw inside a group does not leak its state', () {
      void boom() => throw StateError('boom');
      expect(
        () => Route.group('admin', boom, name: 'admin.'),
        throwsStateError,
      );
      expect(
        () => Route.middleware(<dynamic>[(DoxRequest req) => req], boom),
        throwsStateError,
      );
      expect(() => Route.domain('a.example.com', boom), throwsStateError);
      expect(() => Route.enabledCors(boom), throwsStateError);

      Route.get('/ping', (DoxRequest req) {}).name('ping');
      RouteData route = Route().routes.single;
      expect(route.path, '/ping');
      expect(route.name, 'ping');
      expect(route.preMiddleware, isEmpty);
      expect(route.domain, isNull);
      expect(route.corsEnabled, isNull);
    });

    test('isWebSocket is true only for Route.websocket', () {
      Route.websocket('ws', (WebSocket socket, DoxRequest req) {});
      // a user callable that also gives Future<WebSocket>
      Route.get('fake', (DoxRequest req) async => Future<WebSocket>.error(1));
      expect(Route().routes.map((RouteData r) => r.isWebSocket), <bool>[
        true,
        false,
      ]);
    });

    test('get', () {
      Route.get('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'GET');
    });

    test('post', () {
      Route.post('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'POST');
    });

    test('put', () {
      Route.put('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'PUT');
    });

    test('patch', () {
      Route.patch('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'PATCH');
    });

    test('delete', () {
      Route.delete('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'DELETE');
    });

    test('purge', () {
      Route.purge('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'PURGE');
    });

    test('options', () {
      Route.options('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'OPTIONS');
    });

    test('copy', () {
      Route.copy('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'COPY');
    });

    test('view', () {
      Route.view('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'VIEW');
    });

    test('link', () {
      Route.link('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'LINK');
    });

    test('unlink', () {
      Route.unlink('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'UNLINK');
    });

    test('lock', () {
      Route.lock('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'LOCK');
    });

    test('propfind', () {
      Route.propfind('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'PROPFIND');
    });

    test('unlock', () {
      Route.unlock('/ping', (DoxRequest req) {});
      List<RouteData> routes = Route().routes;
      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'UNLOCK');
    });

    test('group', () {
      Route.get('/ping', (DoxRequest req) {});

      Route.group('blog', () {
        Route.post('/info', (DoxRequest req) {});
        Route.get('/activate', (DoxRequest req) {});
      });

      Route.post('admin', (DoxRequest req) {});

      List<RouteData> routes = Route().routes;

      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'GET');

      expect(routes[1].path, '/blog/info');
      expect(routes[1].method, 'POST');

      expect(routes[2].path, '/blog/activate');
      expect(routes[2].method, 'GET');

      expect(routes[3].path, '/admin');
      expect(routes[3].method, 'POST');
    });

    test('group joins parts with one slash', () {
      Route.group('blogs', () {
        Route.get('all', (DoxRequest req) {});
        Route.get('', (DoxRequest req) {});
        Route.group('/admin/', () {
          Route.get('/users/', (DoxRequest req) {});
          Route.resource('posts', AdminController());
        });
      });
      Route.group('', () {
        Route.get('', (DoxRequest req) {});
      });
      Route.prefix('api');
      Route.get('ping', (DoxRequest req) {});
      Route.prefix('');

      List<String> paths = Route().routes.map((RouteData r) => r.path).toList();
      expect(paths[0], '/blogs/all');
      expect(paths[1], '/blogs');
      expect(paths[2], '/blogs/admin/users');
      expect(paths[3], '/blogs/admin/posts');
      expect(paths[4], '/blogs/admin/posts/create');
      expect(paths.reversed.elementAt(1), '/');
      expect(paths.last, '/api/ping');
    });

    test('resource route does not hide errors', () {
      expect(
        () => Route.resource('broken', _BrokenController()),
        throwsStateError,
      );
    });

    test('resource route', () {
      Route.resource('admins', AdminController());

      List<RouteData> routes = Route().routes;

      expect(routes[0].path, '/admins');
      expect(routes[0].method, 'GET');

      expect(routes[1].path, '/admins/create');
      expect(routes[1].method, 'GET');

      expect(routes[2].path, '/admins');
      expect(routes[2].method, 'POST');

      expect(routes[3].path, '/admins/{id}');
      expect(routes[3].method, 'GET');

      expect(routes[4].path, '/admins/{id}/edit');
      expect(routes[4].method, 'GET');

      expect(routes[5].path, '/admins/{id}');
      expect(routes[5].method, 'PUT');

      expect(routes[6].path, '/admins/{id}');
      expect(routes[6].method, 'PATCH');

      expect(routes[7].path, '/admins/{id}');
      expect(routes[7].method, 'DELETE');
    });

    test('resource route with missing method', () {
      Route.resource('blogs', BlogController());

      List<RouteData> routes = Route().routes;

      expect(routes[0].path, '/blogs');
      expect(routes[0].method, 'GET');

      expect(routes[1].path, '/blogs/create');
      expect(routes[1].method, 'GET');

      expect(routes[2].path, '/blogs/{id}');
      expect(routes[2].method, 'GET');

      expect(routes[3].path, '/blogs/{id}/edit');
      expect(routes[3].method, 'GET');

      expect(routes[4].path, '/blogs/{id}');
      expect(routes[4].method, 'PUT');

      expect(routes[5].path, '/blogs/{id}');
      expect(routes[5].method, 'PATCH');

      expect(routes[6].path, '/blogs/{id}');
      expect(routes[6].method, 'DELETE');
    });

    test('domain route', () {
      Route.domain('dartondox.dev', () {
        Route.get('ping', (DoxRequest req) {});
        Route.post('pong', (DoxRequest req) {});
      });

      List<RouteData> routes = Route().routes;

      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'GET');
      expect(routes[0].domain, 'dartondox.dev');

      expect(routes[1].path, '/pong');
      expect(routes[1].method, 'POST');
      expect(routes[1].domain, 'dartondox.dev');
    });

    test('match adds one route per method', () {
      Route.match(<String>['get', 'POST'], '/ping', (DoxRequest req) {});
      expect(Route().routes.map((RouteData r) => r.method), <String>[
        'GET',
        'POST',
      ]);
    });

    test('match throws on an unknown method and on HEAD', () {
      expect(
        () => Route.match(<String>['FOO'], '/ping', (DoxRequest req) {}),
        throwsArgumentError,
      );
      expect(
        () => Route.match(<String>['HEAD'], '/ping', (DoxRequest req) {}),
        throwsArgumentError,
      );
    });

    test('any adds GET, POST, PUT, PATCH and DELETE', () {
      Route.any('/ping', (DoxRequest req) {});
      expect(Route().routes.map((RouteData r) => r.method), <String>[
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
    });

    test('where sets the param regex on every route of match', () {
      Route.match(
        <String>['GET', 'PUT'],
        '/users/{id}',
        (DoxRequest req) {},
      ).where('id', '[0-9]+');
      for (RouteData route in Route().routes) {
        expect(route.pattern!.hasMatch('/users/12'), isTrue);
        expect(route.pattern!.hasMatch('/users/ab'), isFalse);
      }
    });

    test('where with a|b keeps the alternation inside the param', () {
      Route.get('/f/{type}', (DoxRequest req) {}).where('type', 'png|jpg');
      RegExp pattern = Route().routes.first.pattern!;
      expect(pattern.hasMatch('/f/png'), isTrue);
      expect(pattern.hasMatch('/f/jpg'), isTrue);
      expect(pattern.hasMatch('/f/gif'), isFalse);
    });

    test('where throws on an unknown param, a bad regex or a group', () {
      Route.get('/users/{id}', (DoxRequest req) {});
      expect(() => Route().where('nope', '[0-9]+'), throwsArgumentError);
      expect(() => Route().where('id', '[0-9'), throwsArgumentError);
      expect(() => Route().where('id', '([0-9]+)'), throwsArgumentError);
      Route().where('id', '(?:[0-9]+)');
    });

    test('timeout covers every route of any', () {
      Route.any('/slow', (DoxRequest req) {}).timeout(Duration(seconds: 1));
      for (RouteData route in Route().routes) {
        expect(route.controllers.first, isA<RequestTimeout>());
      }
    });

    test('fallback is kept apart from the routes', () {
      Route().setFallbacks(<RouteData>[]);
      Route.group('admin', () {
        Route.fallback((DoxRequest req) {});
      });
      expect(Route().routes, isEmpty);
      expect(Route().fallbacks.single.path, '/admin');
      expect(Route().fallbacks.single.method, 'GET');
    });
  });
}

/// `index` throws a real error, not a missing method
class _BrokenController {
  dynamic get index => throw StateError('broken');
}
