import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' as orm;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const int port = 50021;
const String baseUrl = 'http://localhost:$port';

/// form request with a fluent schema (used before rules)
class SignUpRequest extends FormRequest {
  static final ObjectSchema _schema = v.object(<String, Schema<Object?>>{
    'name': v.string().trim().min(3),
    'age': v.coerce.int().min(18),
  });

  @override
  ObjectSchema? schema() => _schema;

  @override
  Map<String, String> rules() => <String, String>{'never': 'required'};
}

/// form request with an async database rule
class RegisterRequest extends FormRequest {
  @override
  Map<String, String> rules() => <String, String>{
    'email': 'required|email|unique:users,email',
  };
}

class ValidationRouter extends Router {
  @override
  void register() {
    Route.post('/rules', (DoxRequest req) {
      return req.validate(<String, String>{
        'name': 'required',
        'email': 'required|email',
      });
    });
    Route.post('/unique', (DoxRequest req) async {
      return req.validateAsync(<String, String>{
        'email': 'required|email|unique:users,email',
      });
    });
    Route.post('/exists', (DoxRequest req) async {
      return req.validateAsync(<String, String>{
        'email': 'required|exists:users,email',
      });
    });
    Route.post('/sync-unique', (DoxRequest req) {
      return req.validate(<String, String>{'email': 'unique:users,email'});
    });
    Route.post('/schema', (DoxRequest req) async {
      Map<String, dynamic> data = await req.validateSchema(
        v.object(<String, Schema<Object?>>{
          'age': v.coerce.int().min(18),
          'tags': v.list(v.string()).optional(),
        }),
      );
      return <String, dynamic>{
        'age': data['age'],
        'type': '${data['age'].runtimeType}',
      };
    });
    Route.post('/parse', (DoxRequest req) {
      return v
          .object(<String, Schema<Object?>>{'title': v.string()})
          .parse(req.all());
    });
    Route.post('/sign-up', (SignUpRequest req) {
      return req.validated;
    });
    Route.post('/register', (RegisterRequest req) {
      return req.validated;
    });
  }
}

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  serverPort: port,
  totalIsolate: 1,
  routers: <Router>[ValidationRouter()],
  formRequests: <Type, FormRequest Function()>{
    SignUpRequest: () => SignUpRequest(),
    RegisterRequest: () => RegisterRequest(),
  },
  errorHandler: (Object? error, StackTrace stackTrace) {},
);

Future<http.Response> post(String path, Map<String, dynamic> body) {
  return http.post(
    Uri.parse('$baseUrl$path'),
    headers: <String, String>{'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
}

void main() {
  setUpAll(() async {
    orm.SqlQueryBuilder.initialize(
      database: orm.ConnectionConfig(
        driver: orm.Driver.sqlite,
        database: ':memory:',
        debug: false,
      ).getDatabaseConnection(),
      driver: orm.Driver.sqlite,
    );
    await orm.Schema().create('users', (orm.Table table) {
      table.id();
      table.string('email');
    });
    await orm.QueryBuilder.table<dynamic>('users')
        .insert(<String, dynamic>{'email': 'taken@dox.dev'});
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close(force: true);
  });

  test('string rules give the same error map as before', () async {
    http.Response res = await post('/rules', <String, dynamic>{'email': 'bad'});
    expect(res.statusCode, 422);
    expect(jsonDecode(res.body), <String, dynamic>{
      'name': 'The name is required',
      'email': 'The email is not a valid email',
    });
  });

  test('validate returns only the fields with rules', () async {
    http.Response res = await post('/rules', <String, dynamic>{
      'name': 'dox',
      'email': 'a@dox.dev',
      'extra': 1,
    });
    expect(res.statusCode, 200);
    expect(jsonDecode(res.body), <String, dynamic>{
      'name': 'dox',
      'email': 'a@dox.dev',
    });
  });

  test('unique rule checks sqlite', () async {
    http.Response taken = await post('/unique', <String, dynamic>{
      'email': 'taken@dox.dev',
    });
    expect(taken.statusCode, 422);
    expect(jsonDecode(taken.body), <String, dynamic>{
      'email': 'The email has already been taken',
    });

    http.Response free = await post('/unique', <String, dynamic>{
      'email': 'free@dox.dev',
    });
    expect(free.statusCode, 200);
  });

  test('exists rule checks sqlite', () async {
    expect(
      (await post('/exists', <String, dynamic>{
        'email': 'taken@dox.dev',
      })).statusCode,
      200,
    );
    http.Response missing = await post('/exists', <String, dynamic>{
      'email': 'nobody@dox.dev',
    });
    expect(missing.statusCode, 422);
    expect(jsonDecode(missing.body), <String, dynamic>{
      'email': 'The selected email is invalid',
    });
  });

  test('async rule in sync validate is a clear error', () async {
    http.Response res = await post('/sync-unique', <String, dynamic>{
      'email': 'a@dox.dev',
    });
    expect(res.statusCode, 500);
    expect(res.body, contains('validateAsync'));
  });

  test('validateSchema returns typed output', () async {
    http.Response res = await post('/schema', <String, dynamic>{'age': '21'});
    expect(jsonDecode(res.body), <String, dynamic>{'age': 21, 'type': 'int'});

    http.Response bad = await post('/schema', <String, dynamic>{'age': '12'});
    expect(bad.statusCode, 422);
    expect((jsonDecode(bad.body) as Map<String, dynamic>).keys, <String>[
      'age',
    ]);
  });

  test('schema.parse in a controller answers 422', () async {
    http.Response res = await post('/parse', <String, dynamic>{});
    expect(res.statusCode, 422);
    expect((jsonDecode(res.body) as Map<String, dynamic>).keys, <String>[
      'title',
    ]);
  });

  test('form request schema() is used before rules()', () async {
    http.Response res = await post('/sign-up', <String, dynamic>{
      'name': '  dox  ',
      'age': '30',
    });
    expect(res.statusCode, 200);
    expect(jsonDecode(res.body), <String, dynamic>{'name': 'dox', 'age': 30});

    http.Response bad = await post('/sign-up', <String, dynamic>{
      'name': 'd',
      'age': '30',
    });
    expect(bad.statusCode, 422);
    expect((jsonDecode(bad.body) as Map<String, dynamic>).keys, <String>[
      'name',
    ]);
  });

  test('form request rules() run async rules', () async {
    http.Response taken = await post('/register', <String, dynamic>{
      'email': 'taken@dox.dev',
    });
    expect(taken.statusCode, 422);
    http.Response free = await post('/register', <String, dynamic>{
      'email': 'new@dox.dev',
    });
    expect(jsonDecode(free.body), <String, dynamic>{'email': 'new@dox.dev'});
  });
}
