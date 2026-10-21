import 'package:dox_openapi/dox_openapi.dart';
import 'package:test/test.dart';

class UserSchema implements JsonSchemaSource {
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{'type': 'string'},
      },
    };
  }
}

/// Has toJsonSchema() but does not implement the interface.
class DuckSchema {
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'type': 'integer'};
  }
}

class BadDuck {
  String toJsonSchema() {
    return 'nope';
  }
}

void main() {
  SchemaResolver resolver = const SchemaResolver();

  group('SchemaResolver', () {
    test('accepts a raw map', () {
      expect(
        resolver.resolve(<String, dynamic>{'type': 'string'}),
        <String, dynamic>{'type': 'string'},
      );
    });

    test('accepts a JsonSchemaSource', () {
      expect(resolver.resolve(UserSchema())['type'], 'object');
    });

    test('accepts any object with toJsonSchema()', () {
      expect(resolver.resolve(DuckSchema()), <String, dynamic>{
        'type': 'integer',
      });
    });

    test('rejects other objects', () {
      expect(() => resolver.resolve(Object()), throwsArgumentError);
      expect(() => resolver.resolve(BadDuck()), throwsArgumentError);
    });

    test('makes a ref', () {
      expect(resolver.ref('User'), <String, dynamic>{
        r'$ref': '#/components/schemas/User',
      });
    });
  });

  group('PathConverter', () {
    test('turns colon params into braces', () {
      expect(
        PathConverter.path('/users/:id/posts/:postId'),
        '/users/{id}/posts/{postId}',
      );
    });

    test('cleans slashes', () {
      expect(PathConverter.path('users//{id}/'), '/users/{id}');
      expect(PathConverter.path(''), '/');
      expect(PathConverter.path('/'), '/');
    });

    test('reads param names in order', () {
      expect(PathConverter.paramNames('/a/{x}/b/{y}'), <String>['x', 'y']);
      expect(PathConverter.paramNames('/plain'), isEmpty);
    });

    test('checks methods', () {
      expect(PathConverter.method('GET'), 'get');
      expect(PathConverter.isSupportedMethod('PURGE'), isFalse);
      expect(() => PathConverter.method('PURGE'), throwsArgumentError);
    });

    test('makes operation ids', () {
      expect(PathConverter.operationId('get', '/users/{id}'), 'getUsersById');
      expect(
        PathConverter.operationId('post', '/api/blog-posts'),
        'postApiBlogPosts',
      );
      expect(PathConverter.operationId('get', '/'), 'get');
    });
  });

  group('RouteDoc.toOperation', () {
    test('a body with a file field uses multipart/form-data', () {
      Map<String, dynamic> file = <String, dynamic>{
        'type': 'string',
        'format': 'binary',
      };
      for (Object field in <Object>[
        file,
        <String, dynamic>{'type': 'array', 'items': file},
        <String, dynamic>{
          'anyOf': <dynamic>[
            file,
            <String, dynamic>{'type': 'null'},
          ],
        },
      ]) {
        RouteDoc doc = RouteDoc(
          method: 'post',
          path: '/files',
          body: <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{
              'file': field,
              'note': <String, dynamic>{'type': 'string'},
            },
          },
        );
        Map<String, dynamic> content =
            doc.toOperation(resolver)['requestBody']['content']
                as Map<String, dynamic>;
        expect(content.keys, <String>['multipart/form-data']);
      }
    });

    test('a body without a file field uses JSON', () {
      RouteDoc doc = RouteDoc(
        method: 'post',
        path: '/users',
        body: UserSchema(),
      );
      Map<String, dynamic> content =
          doc.toOperation(resolver)['requestBody']['content']
              as Map<String, dynamic>;
      expect(content.keys, <String>['application/json']);
    });

    test('bodyMediaType wins over the guess', () {
      RouteDoc doc = RouteDoc(
        method: 'post',
        path: '/users',
        body: UserSchema(),
        bodyMediaType: 'multipart/form-data',
      );
      Map<String, dynamic> content =
          doc.toOperation(resolver)['requestBody']['content']
              as Map<String, dynamic>;
      expect(content.keys, <String>['multipart/form-data']);
    });

    test('adds path params with a default string schema', () {
      RouteDoc doc = RouteDoc(
        method: 'GET',
        path: '/users/:id/posts/{postId}',
        params: <String, Object>{
          'id': <String, dynamic>{'type': 'integer'},
        },
      );
      Map<String, dynamic> op = doc.toOperation(resolver);
      expect(doc.path, '/users/{id}/posts/{postId}');
      expect(op['parameters'], <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': <String, dynamic>{'type': 'integer'},
        },
        <String, dynamic>{
          'name': 'postId',
          'in': 'path',
          'required': true,
          'schema': <String, dynamic>{'type': 'string'},
        },
      ]);
    });

    test('expands a query schema into query params', () {
      RouteDoc doc = RouteDoc(
        method: 'get',
        path: '/users',
        query: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'page': <String, dynamic>{'type': 'integer'},
            'search': <String, dynamic>{'type': 'string'},
          },
          'required': <String>['page'],
        },
      );
      List<dynamic> params =
          doc.toOperation(resolver)['parameters'] as List<dynamic>;
      expect(params.length, 2);
      expect((params[0] as Map<dynamic, dynamic>)['required'], isTrue);
      expect((params[1] as Map<dynamic, dynamic>)['required'], isFalse);
      expect((params[1] as Map<dynamic, dynamic>)['in'], 'query');
    });

    test('rejects a query schema without properties', () {
      RouteDoc doc = RouteDoc(
        method: 'get',
        path: '/x',
        query: <String, dynamic>{'type': 'string'},
      );
      expect(() => doc.toOperation(resolver), throwsArgumentError);
    });

    test('writes body, responses, security and extensions', () {
      RouteDoc doc = RouteDoc(
        method: 'post',
        path: '/users',
        summary: 'Create user',
        tags: <String>['users'],
        body: UserSchema(),
        responses: <int, ResponseDoc>{
          201: ResponseDoc(schema: resolver.ref('User'), description: 'Made'),
          422: const ResponseDoc(description: 'Invalid'),
        },
        security: <Map<String, List<String>>>[
          <String, List<String>>{'bearerAuth': <String>[]},
        ],
        extensions: <String, dynamic>{'x-internal': true},
      );
      Map<String, dynamic> op = doc.toOperation(resolver);
      expect(op['summary'], 'Create user');
      expect(op['tags'], <String>['users']);
      expect(op['operationId'], 'postUsers');
      expect(
        ((op['requestBody'] as Map<dynamic, dynamic>)['content']
            as Map<dynamic, dynamic>)['application/json'],
        <String, dynamic>{'schema': UserSchema().toJsonSchema()},
      );
      Map<dynamic, dynamic> responses =
          op['responses'] as Map<dynamic, dynamic>;
      expect(responses.keys, <String>['201', '422']);
      expect(
        (responses['422'] as Map<dynamic, dynamic>).containsKey('content'),
        isFalse,
      );
      expect(op['security'], isNotNull);
      expect(op['x-internal'], isTrue);
      expect(op.containsKey('parameters'), isFalse);
    });

    test('gives a default 200 response', () {
      Map<String, dynamic> op = RouteDoc(
        method: 'get',
        path: '/ping',
      ).toOperation(resolver);
      expect(op['responses'], <String, dynamic>{
        '200': <String, dynamic>{'description': 'Successful response'},
      });
    });
  });

  group('ApiDoc', () {
    test('replaces docs for the same route', () {
      ApiDoc docs = ApiDoc();
      docs.route('GET', '/users/:id', summary: 'old');
      docs.route('get', '/users/{id}', summary: 'new');
      expect(docs.routes.length, 1);
      expect(docs.routes.first.summary, 'new');
      expect(docs.has('GET', '/users/:id'), isTrue);
      expect(docs.has('POST', '/users/:id'), isFalse);
    });

    test('stores named schemas and returns refs', () {
      ApiDoc docs = ApiDoc();
      Map<String, dynamic> ref = docs.schema('User', UserSchema());
      expect(ref, docs.ref('User'));
      expect(docs.schemas.keys, <String>['User']);
    });
  });
}
