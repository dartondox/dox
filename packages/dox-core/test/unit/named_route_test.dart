import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:test/test.dart';

import '../integration/requirements/controllers/blog.controller.dart';

void main() {
  group('named routes |', () {
    setUp(() {
      Route().setRoutes(<RouteData>[]);
    });

    test('builds the path with params and query', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(
        route('users.show', params: <String, Object>{'id': 5}),
        '/users/5',
      );
      expect(
        route(
          'users.show',
          params: <String, Object>{'id': 'a b'},
          query: <String, Object?>{'tab': 'posts', 'skip': null},
        ),
        '/users/a%20b?tab=posts',
      );
    });

    test('optional and rest params', () {
      Route.get('blog/{id?}', (DoxRequest req) {}).name('blog');
      Route.get('files/{path*}', (DoxRequest req) {}).name('files');
      expect(route('blog'), '/blog');
      expect(route('blog', params: <String, Object>{'id': 2}), '/blog/2');
      expect(
        route('files', params: <String, Object>{'path': 'a/b c.png'}),
        '/files/a/b%20c.png',
      );
    });

    test('group name prefix', () {
      Route.group('admin', () {
        Route.get('users', (DoxRequest req) {}).name('users');
      }, name: 'admin.');
      expect(route('admin.users'), '/admin/users');
    });

    test('resource routes get names', () {
      Route.resource('blogs', BlogController());
      expect(route('blogs.index'), '/blogs');
      expect(
        route('blogs.update', params: <String, Object>{'id': 3}),
        '/blogs/3',
      );
      expect(
        Route().routes.where((RouteData r) => r.name == 'blogs.update').length,
        1,
      );
    });

    test('unknown name, missing param and extra param throw', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(() => route('nope'), throwsArgumentError);
      expect(() => route('users.show'), throwsArgumentError);
      expect(
        () => route('users.show', params: <String, Object>{'id': 1, 'x': 2}),
        throwsArgumentError,
      );
    });

    test('a name used twice throws', () {
      Route.get('a', (DoxRequest req) {}).name('same');
      expect(
        () => Route.get('b', (DoxRequest req) {}).name('same'),
        throwsStateError,
      );
    });
  });
}
