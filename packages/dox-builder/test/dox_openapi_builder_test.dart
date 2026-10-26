import 'dart:io';
import 'dart:isolate';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// a small copy of dox_core: the builder finds things by class name.
const String _core = '''
export 'package:dox_annotation/dox_annotation.dart';
export 'package:dox_validation/src/dto/dto_annotations.dart';

class DoxRequest {
  T validate<T>() => throw UnimplementedError();
}
abstract class IHttpException {}
class UnAuthorizedException extends IHttpException {}
class DoxResponse {}
class Serializer<T> {
  Serializer(dynamic data);
  Map<String, dynamic> convert(T m) => <String, dynamic>{};
}
class Pagination {}
class Column {
  final String? name;
  const Column({this.name});
}
class Computed {
  const Computed();
}
class BelongsTo {
  final Type model;
  const BelongsTo(this.model);
}
class Router {}
class Route {
  static void group(String prefix, Function() callback) {}
  static Route get<T extends Object>(String path, dynamic c) => Route();
  static Route post(String path, dynamic c, {Object? body}) => Route();
  static Route resource(String path, dynamic c) => Route();
  static Route delete(String path, dynamic c) => Route();
  static void middleware(List<dynamic> m, Function() callback) {}
}
''';

const String _models = '''
import 'package:dox_core/dox_core.dart';

/// A person.
@DoxModel(table: 'users')
class User {
  List<String> get hidden => <String>['password'];

  @Column()
  String? name;

  @Column(name: 'mail')
  String? email;

  @Column()
  String? password;

  @BelongsTo(User)
  User? parent;

  @Computed()
  String get fullName => name ?? '';
}

enum Role { admin, user }

@Dto()
class Address {
  final String city;
  const Address({required this.city});
}

@Dto()
class CreateUser {
  @Length(min: 2, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  /// Short text about the user.
  final String? bio;

  @Min(18)
  @Max(130)
  final int age;

  final Role role;

  @Regex('[a-z]+')
  final String host;

  final String? firstName;

  @MinItems(1)
  @MaxItems(3)
  final List<Address> addresses;

  const CreateUser({
    required this.name,
    required this.email,
    this.bio,
    this.age = 18,
    this.role = Role.user,
    required this.host,
    required this.addresses,
    this.firstName,
  });
}

class UserSerializer extends Serializer<User> {
  UserSerializer(super.data);

  @override
  Map<String, dynamic> convert(User m) {
    return <String, dynamic>{'id': 1, 'name': m.name};
  }
}
''';

const String _controllers = '''
import 'package:dox_core/dox_core.dart';
import 'models.dart';

class UserController {
  /// List users
  ///
  /// All users, newest first.
  Future<List<User>> index(DoxRequest req) async => <User>[];

  /// Create a user
  Future<User> store(CreateUser body) async => User();

  Future<User?> show(DoxRequest req, int id) async => null;

  Future<dynamic> update(DoxRequest req, String id) async {
    CreateUser data = req.validate<CreateUser>();
    if (data.name.isEmpty) return UnAuthorizedException();
    return <String, dynamic>{'status': 'ok', 'count': 1};
  }

  @summary('Remove a user')
  @tags(<String>['Admin'])
  @ApiDeprecated()
  @Response(204, null, description: 'Deleted')
  Future<void> destroy(DoxRequest req, String id) async {}

  @ApiIgnore()
  String secret(DoxRequest req) => 'x';

  String _helper() => '';
}

@DoxController(tag: 'Me')
class ProfileController {
  @Request(Address)
  UserSerializer me(DoxRequest req) => UserSerializer(User());

  @Query(CreateUser)
  @Response(200, List<User>)
  dynamic search(DoxRequest req) => null;

  Pagination page(DoxRequest req) => Pagination();
}

class Routes {
  void register() {
    UserController users = UserController();
    Route.resource('users', users);
    Route.get('/users/{id}/again', <dynamic>[Object(), users.show]);
  }
}

class TeamController {
  /// List teams
  Future<List<User>> index() async => <User>[];
}

class ApiRoutes extends Router {
  String get prefix => 'api';

  void register() {
    Route.group('/teams', () {
      Route.get('/', TeamController().index);
    });
    Route.group('blogs', () {
      Route.get('all', TeamController().index);
    });
    Route.get<TeamController>('typed', (TeamController c) => c.index);
    Route.get<TeamController>('untyped', (c) => c.index);
    Route.resource('teams', TeamController);
    Route.group('/auth', registerAuth);
  }

  void registerAuth() {
    Route.post('/login', (AuthController c) => c.login);
  }
}

class AuthController {
  /// Token login
  Map<String, dynamic> login(DoxRequest req) => <String, dynamic>{};
}

class WebAuthController {
  /// Session login
  Map<String, dynamic> login(DoxRequest req) => <String, dynamic>{};
}

/// The callback is above its group call, and has a group of its own.
void registerWebAuth() {
  Route.post('/login', (WebAuthController c) => c.login);
  Route.group('v2', registerWebAuthV2);
}

void registerWebAuthV2() {
  Route.post('login', (WebAuthController c) => c.login);
}

class WebRoutes extends Router {
  void register() {
    Route.group('/web-auth', registerWebAuth);
  }
}
''';

/// like the your-qr app: an `api` router and a web router with the
/// same paths and the same method names on two controllers, and a
/// bearer API key middleware
const String _qrApp = '''
import 'package:dox_core/dox_core.dart';

@Security.bearer(format: 'API key')
class ApiKeyAuthMiddleware {}

@Security.apiKey(header: 'X-Key', scheme: 'keyHeader')
class HeaderKeyMiddleware {}

class LinkApiController {
  /// API links
  List<String> index(DoxRequest req) => <String>[];

  /// API delete
  void destroy(DoxRequest req, String id) {}
}

class LinkPageController {
  /// Page links
  List<String> index(DoxRequest req) => <String>[];

  /// Page delete
  void destroy(DoxRequest req, String id) {}
}

class ApiRouter extends Router {
  String get prefix => 'api';

  void register() {
    Route.get('/links', (LinkApiController c) => c.index);
    Route.delete('/links/{id}', (LinkApiController c) => c.destroy);
  }
}

class WebRouter extends Router {
  void register() {
    Route.middleware(<dynamic>[Object()], registerDashboard);
  }

  void registerDashboard() {
    Route.get('/links', (LinkPageController c) => c.index);
    Route.delete('/links/{id}', (LinkPageController c) => c.destroy);
  }
}
''';

String _annotationFile(String name) {
  return File('../dox-annotation/lib/src/$name').readAsStringSync();
}

Future<String> _generate(Map<String, String> sources) async {
  String output = '';
  await testBuilder(
    buildDoxOpenApi(BuilderOptions.empty),
    <String, String>{
      'dox_annotation|lib/dox_annotation.dart': '''
export 'src/dox_model.dart';
export 'src/openapi_annotation.dart';
''',
      'dox_annotation|lib/src/dox_model.dart': _annotationFile(
        'dox_model.dart',
      ),
      'dox_validation|lib/src/dto/dto_annotations.dart': File.fromUri(
        // dox_validation lives in its own repo: find it through the package config
        Isolate.resolvePackageUriSync(
          Uri.parse('package:dox_validation/src/dto/dto_annotations.dart'),
        )!,
      ).readAsStringSync(),
      'dox_annotation|lib/src/openapi_annotation.dart': _annotationFile(
        'openapi_annotation.dart',
      ),
      'dox_core|lib/dox_core.dart': _core,
      ...sources,
    },
    rootPackage: 'a',
    outputs: <String, Object>{
      'a|lib/generated/openapi.g.dart': decodedMatches(
        predicate<String>((String s) {
          output = s;
          return true;
        }),
      ),
    },
  );
  return _flat(output);
}

/// [code] without white space, to compare with the generated file
/// and without trailing commas, so formatting does not matter
String _flat(String code) {
  return code
      .replaceAll(RegExp(r'\s'), '')
      .replaceAllMapped(RegExp(r',([\]})])'), _closing);
}

String _closing(Match match) {
  return match.group(1)!;
}

void main() {
  group('DoxOpenApiBuilder |', () {
    late String out;

    setUpAll(() async {
      out = await _generate(<String, String>{
        'a|lib/models.dart': _models,
        'a|lib/controllers.dart': _controllers,
      });
    });

    test('route calls give the controller of each route', () {
      expect(out, startsWith(_flat('// GENERATED CODE')));
      expect(
        out,
        contains(
          _flat("OpenApiRouteBinding('GET', 'users', 'UserController.index')"),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('PATCH', 'users/{id}', 'UserController.update')",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', '/users/{id}/again', 'UserController.show')",
          ),
        ),
      );
      // the router prefix and the group are in the path
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', 'api/teams/', 'TeamController.index')",
          ),
        ),
      );
      // typed routes and a resource of a controller class
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', 'api/typed', 'TeamController.index')",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', 'api/untyped', 'TeamController.index')",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', 'api/teams', 'TeamController.index')",
          ),
        ),
      );
      // a group without slashes still gets one between the parts
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('GET', 'api/blogs/all', 'TeamController.index')",
          ),
        ),
      );
    });

    test('a group callback that is a method or function gets the prefix', () {
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('POST', 'api/auth/login', 'AuthController.login')",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('POST', '/web-auth/login', "
            "'WebAuthController.login')",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "OpenApiRouteBinding('POST', '/web-auth/v2/login', "
            "'WebAuthController.login')",
          ),
        ),
      );
      // no binding without the group prefix
      expect(out, isNot(contains(_flat("'POST', '/login'"))));
      expect(out, isNot(contains(_flat("'POST', 'api/login'"))));
    });

    test('doc comment gives summary and description, class gives tag', () {
      expect(
        out,
        contains(
          _flat('''
controller: 'UserController', method: 'index',
argumentTypes: <String>['DoxRequest'],
summary: 'List users', description: 'All users, newest first.',
tags: <String>['User'],'''),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "schema: <String, dynamic>{'type': 'array', 'items': "
            "<String, dynamic>{'\\\$ref': '#/components/schemas/User'}}",
          ),
        ),
      );
    });

    test('a @Dto argument is the request body', () {
      expect(
        out,
        contains(
          _flat(
            "method: 'store', argumentTypes: <String>['CreateUser'], "
            "summary: 'Create a user', tags: <String>['User'], "
            "schema: <String, dynamic>{'\\\$ref': '#/components/schemas/CreateUser'}",
          ),
        ),
      );
    });

    test('typed path params, nullable model answer', () {
      expect(
        out,
        contains(
          _flat(
            "method: 'show', argumentTypes: <String>['DoxRequest', 'int'], "
            "tags: <String>['User'], params: <Map<String, dynamic>>["
            "<String, dynamic>{'type': 'integer'}]",
          ),
        ),
      );
    });

    test('req.validate<T>() and returned map literals', () {
      expect(
        out,
        contains(
          _flat(
            "schema: <String, dynamic>{'\\\$ref': '#/components/schemas/CreateUser'}, "
            "responses: <int, ResponseDoc>{200: ResponseDoc(description: "
            "'Successful response', schema: <String, dynamic>{'type': 'object', "
            "'properties': <String, dynamic>{'status': <String, dynamic>{'type': "
            "'string'}, 'count': <String, dynamic>{'type': 'integer'}}})",
          ),
        ),
      );
    });

    test('lower case annotations, @Response and deprecated', () {
      expect(
        out,
        contains(
          _flat(
            "summary: 'Remove a user', tags: <String>['Admin'], "
            "deprecated: true,",
          ),
        ),
      );
      expect(out, contains(_flat("204: ResponseDoc(description: 'Deleted')")));
    });

    test('@ApiIgnore keeps only the names, private methods are left out', () {
      expect(
        out,
        contains(
          _flat(
            "method: 'secret', argumentTypes: <String>['DoxRequest'], "
            'ignore: true)',
          ),
        ),
      );
      expect(out, isNot(contains('_helper')));
      expect(out, isNot(contains('Routes')));
    });

    test('@DoxController, @Request, @Query and serializers', () {
      expect(
        out,
        contains(
          _flat(
            "method: 'me', argumentTypes: <String>['DoxRequest'], "
            "tags: <String>['Me'], "
            "schema: <String, dynamic>{'\\\$ref': '#/components/schemas/Address'}",
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            "'properties': <String, dynamic>{'id': <String, dynamic>{'type': "
            "'integer'}, 'name': <String, dynamic>{'type': <dynamic>['string', "
            "'null']}}",
          ),
        ),
      );
      expect(out, contains(_flat("requestIn: 'query'")));
      expect(out, contains(_flat("'Pagination': <String, dynamic>{")));
    });

    test('model schema: columns, relations, computed, hidden', () {
      expect(
        out,
        contains(
          _flat('''
'User': <String, dynamic>{'type': 'object', 'description': 'A person.',
'properties': <String, dynamic>{
'id': <String, dynamic>{'type': 'integer'},
'name': <String, dynamic>{'type': <dynamic>['string', 'null']},
'mail': <String, dynamic>{'type': <dynamic>['string', 'null']},
'parent': <String, dynamic>{'anyOf': <dynamic>[
<String, dynamic>{'\\\$ref': '#/components/schemas/User'},
<String, dynamic>{'type': 'null'}]},
'created_at': <String, dynamic>{'type': <dynamic>['string', 'null'], 'format': 'date-time'},
'updated_at': <String, dynamic>{'type': <dynamic>['string', 'null'], 'format': 'date-time'},
'full_name': <String, dynamic>{'type': 'string'}}}'''),
        ),
      );
    });

    test('dto schema: constraints, defaults, enums, nested lists', () {
      expect(
        out,
        contains(
          _flat('''
'CreateUser': <String, dynamic>{'type': 'object', 'title': 'CreateUser',
'properties': <String, dynamic>{
'name': <String, dynamic>{'type': 'string', 'minLength': 2, 'maxLength': 50},
'email': <String, dynamic>{'type': 'string', 'format': 'email'},
'bio': <String, dynamic>{'type': <dynamic>['string', 'null'], 'description': 'Short text about the user.'},
'age': <String, dynamic>{'type': 'integer', 'minimum': 18, 'maximum': 130, 'default': 18},
'role': <String, dynamic>{'type': 'string', 'enum': <dynamic>['admin', 'user'], 'default': 'user'},
'host': <String, dynamic>{'type': 'string', 'pattern': '^(?:[a-z]+)\\\$'},
'first_name': <String, dynamic>{'type': <dynamic>['string', 'null']},
'addresses': <String, dynamic>{'type': 'array',
'items': <String, dynamic>{'\\\$ref': '#/components/schemas/Address'},
'minItems': 1, 'maxItems': 3}},
'required': <dynamic>['name', 'email', 'host', 'addresses']}'''),
        ),
      );
    });

    test(
      'the your-qr routes: same paths and method names stay apart',
      () async {
        String qr = await _generate(<String, String>{'a|lib/qr.dart': _qrApp});
        for (String binding in <String>[
          "OpenApiRouteBinding('GET', 'api/links', 'LinkApiController.index')",
          "OpenApiRouteBinding('DELETE', 'api/links/{id}', "
              "'LinkApiController.destroy')",
          "OpenApiRouteBinding('GET', '/links', 'LinkPageController.index')",
          "OpenApiRouteBinding('DELETE', '/links/{id}', "
              "'LinkPageController.destroy')",
        ]) {
          expect(qr, contains(_flat(binding)));
        }
      },
    );

    test('@Security on a middleware class gives a login scheme', () async {
      String qr = await _generate(<String, String>{'a|lib/qr.dart': _qrApp});
      expect(
        qr,
        contains(
          _flat('''
security: <String, OpenApiSecurity>{
'ApiKeyAuthMiddleware': OpenApiSecurity('apiKeyAuth', <String, dynamic>{
'type': 'http', 'scheme': 'bearer', 'bearerFormat': 'API key'}),
'HeaderKeyMiddleware': OpenApiSecurity('keyHeader', <String, dynamic>{
'type': 'apiKey', 'name': 'X-Key', 'in': 'header'})}'''),
        ),
      );
    });

    test('no controllers, no file', () async {
      await testBuilder(
        buildDoxOpenApi(BuilderOptions.empty),
        <String, String>{'a|lib/a.dart': 'class A {}'},
        rootPackage: 'a',
        outputs: <String, Object>{},
      );
    });
  });
}
