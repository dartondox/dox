import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:test/test.dart';

import 'core/controllers/admin.controller.dart';

void main() {
  group('Route |', () {
    setUp(() {
      Route().routes = [];
    });

    test('group', () {
      Route.get('/ping', (req) {});

      Route.group('blog', () {
        Route.post('/info', (req) {});
        Route.get('/activate', (req) {});
      });

      Route.post('admin', (req) {});

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

    test('domain route', () {
      Route.domain('dartondox.dev', () {
        Route.get('ping', (req) {});
        Route.post('pong', (req) {});
      });

      List<RouteData> routes = Route().routes;

      expect(routes[0].path, '/ping');
      expect(routes[0].method, 'GET');
      expect(routes[0].domain, 'dartondox.dev');

      expect(routes[1].path, '/pong');
      expect(routes[1].method, 'POST');
      expect(routes[1].domain, 'dartondox.dev');
    });
  });
}
