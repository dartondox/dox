import 'package:dox_openapi/dox_openapi.dart';
import 'package:test/test.dart';

const OpenApiRegistry registry = OpenApiRegistry(
  operations: <OpenApiOperation>[
    OpenApiOperation(
      controller: 'BlogController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
    ),
    OpenApiOperation(
      controller: 'UserController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
    ),
    OpenApiOperation(
      controller: 'UserController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
    ),
  ],
  routes: <OpenApiRouteBinding>[
    OpenApiRouteBinding('GET', 'blogs', 'BlogController.index'),
    OpenApiRouteBinding('GET', '/users', 'UserController.index'),
    OpenApiRouteBinding('GET', null, 'UserController.index'),
  ],
);

List<String> request = <String>['DoxRequest'];

void main() {
  group('OpenApiRegistry |', () {
    test('a route call with the same path end wins', () {
      expect(
        registry.find('GET', '/api/blogs', 'index', request)?.id,
        'BlogController.index',
      );
      expect(
        registry.find('get', '/api/v1/users/', 'index', request)?.id,
        'UserController.index',
      );
    });

    test('a route call without a plain path matches any path', () {
      expect(
        registry.find('GET', '/people', 'index', request)?.id,
        'UserController.index',
      );
    });

    test('else one method with the same name and types', () {
      expect(
        registry.find('GET', '/x/{id}', 'show', <String>[
          'DoxRequest',
          'String',
        ])?.id,
        'UserController.show',
      );
      expect(
        registry.find('GET', '/x/{id}', 'show', <String>['DoxRequest']),
        isNull,
      );
    });

    test('two methods with the same name and no route call: none', () {
      expect(registry.find('POST', '/blogs', 'index', request), isNull);
    });

    test('two controllers with the same method name never mix', () {
      // `/login` ends both live paths. Without the controller, the docs
      // of WebAuthController.login went to POST /api/auth/login.
      const OpenApiRegistry logins = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(
            controller: 'AuthController',
            method: 'login',
            argumentTypes: <String>['DoxRequest'],
          ),
          OpenApiOperation(
            controller: 'WebAuthController',
            method: 'login',
            argumentTypes: <String>['DoxRequest'],
          ),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('POST', 'api/login', 'AuthController.login'),
          OpenApiRouteBinding('POST', '/login', 'WebAuthController.login'),
        ],
      );
      expect(
        logins
            .find(
              'POST',
              '/api/auth/login',
              'login',
              request,
              controller: 'AuthController',
            )
            ?.id,
        'AuthController.login',
      );
      expect(
        logins
            .find(
              'POST',
              '/web-auth/login',
              'login',
              request,
              controller: 'WebAuthController',
            )
            ?.id,
        'WebAuthController.login',
      );
    });
  });
}
