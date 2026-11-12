import 'dart:io';

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

    test('resource with another parameter name', () {
      Route.resource('photos', BlogController(), parameter: 'photo');
      expect(
        Route().routes.map((RouteData r) => '${r.method} ${r.path}').toList(),
        <String>[
          'GET /photos',
          'GET /photos/create',
          'GET /photos/{photo}',
          'GET /photos/{photo}/edit',
          'PUT /photos/{photo}',
          'PATCH /photos/{photo}',
          'DELETE /photos/{photo}',
        ],
      );
      expect(
        route('photos.edit', params: <String, Object>{'photo': 3}),
        '/photos/3/edit',
      );
      expect(() => route('photos.show'), throwsArgumentError);
    });

    test('nested resource keeps the parent param', () {
      Route.group('admin', () {
        Route.resource(
          'users/{user}/photos',
          BlogController(),
          parameter: 'photo',
        );
      }, name: 'admin.');
      expect(
        route(
          'admin.users.photos.show',
          params: <String, Object>{'user': 1, 'photo': 2},
        ),
        '/admin/users/1/photos/2',
      );
      Route.resource('posts', BlogController());
      expect(
        route('posts.show', params: <String, Object>{'id': 4}),
        '/posts/4',
      );
    });

    test('unknown name and missing param throw', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(() => route('nope'), throwsArgumentError);
      expect(() => route('users.show'), throwsArgumentError);
    });

    test('an extra param goes to the query string, encoded', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(
        route(
          'users.show',
          params: <String, Object?>{'id': 1, 'a b': 'x&y=z', 'skip': null},
        ),
        '/users/1?a+b=x%26y%3Dz',
      );
    });

    test('query wins over an extra param with the same key', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(
        route(
          'users.show',
          params: <String, Object>{'id': 1, 'tab': 'a', 'page': 2},
          query: <String, Object>{'tab': 'b'},
        ),
        '/users/1?tab=b&page=2',
      );
      expect(
        route(
          'users.show',
          params: <String, Object>{'id': 1, 'tab': 'a'},
          query: <String, Object?>{'tab': null},
        ),
        '/users/1',
      );
    });

    test('absolute url from baseUrl or APP_URL', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(
        route(
          'users.show',
          params: <String, Object>{'id': 1, 'tab': 'a'},
          absolute: true,
          baseUrl: 'https://example.com/',
        ),
        'https://example.com/users/1?tab=a',
      );
      Env().env['APP_URL'] = 'https://app.test';
      addTearDown(() => Env().env.remove('APP_URL'));
      expect(
        Route.url(
          'users.show',
          params: <String, Object>{'id': 2},
          absolute: true,
        ),
        'https://app.test/users/2',
      );
      Env().env.remove('APP_URL');
      if (Platform.environment['APP_URL'] == null) {
        expect(
          () => route(
            'users.show',
            params: <String, Object>{'id': 1},
            absolute: true,
          ),
          throwsArgumentError,
        );
      }
    });

    test('signedUrl does not take signature as an extra param', () {
      Route.get('users/{id}', (DoxRequest req) {}).name('users.show');
      expect(
        () => Route.signedUrl(
          'users.show',
          params: <String, Object>{'id': 1, 'signature': 'x'},
          absolute: false,
        ),
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
