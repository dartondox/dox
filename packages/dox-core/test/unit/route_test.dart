import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:test/test.dart';

import '../integration/requirements/controllers/admin.controller.dart';
import '../integration/requirements/controllers/blog.controller.dart';

void main() {
  group('Route |', () {
    setUp(() {
      Route().setRoutes(<RouteData>[]);
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
  });
}
