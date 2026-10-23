import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' as orm;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../dtos/database.dto.dart';
import '../../dtos/dtos.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

class ValidationRouter extends Router {
  @override
  void register() {
    Route.post('/members', (CreateMember body) {
      return <String, dynamic>{'email': body.email, 'tags': body.tagIds};
    });
    Route.put('/members/{id}', (int id, UpdateMember body) {
      return <String, dynamic>{'id': id, 'email': body.email};
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
  }
}

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  // the OS picks a free port, so test files can run in parallel
  serverPort: 0,
  totalIsolate: 1,
  routers: <Router>[ValidationRouter()],
  dtos: testDtos,
  errorHandler: (Object? error, StackTrace stackTrace) {},
);

Future<http.Response> send(String method, String path, Object body) async {
  http.Request request = http.Request(method, Uri.parse('$baseUrl$path'))
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode(body);
  return http.Response.fromStream(await request.send());
}

Map<String, dynamic> json(http.Response res) {
  return jsonDecode(res.body) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    // sqlite by default. `PG_PORT=5432` runs the same tests on postgres.
    String? pgPort = Platform.environment['PG_PORT'];
    orm.ConnectionConfig connection = pgPort == null
        ? orm.ConnectionConfig(
            driver: orm.Driver.sqlite,
            database: ':memory:',
            debug: false,
          )
        : orm.ConnectionConfig(
            driver: orm.Driver.postgres,
            port: int.parse(pgPort),
            user: 'postgres',
            password: 'postgres',
            database: 'postgres',
            debug: false,
          );
    orm.SqlQueryBuilder.initialize(
      database: connection.getDatabaseConnection(),
      driver: connection.driver,
    );
    for (String table in <String>['members', 'teams', 'tags']) {
      await orm.Schema().dropIfExists(table);
    }
    await orm.Schema().create('members', (orm.Table table) {
      table.id();
      table.string('email');
      table.softDeletes();
    });
    await orm.Schema().create('teams', (orm.Table table) {
      table.id();
    });
    await orm.Schema().create('tags', (orm.Table table) {
      table.id();
    });
    await orm.QueryBuilder.table('members')
        .insert(<String, dynamic>{'email': 'taken@dox.dev'});
    await orm.QueryBuilder.table('members').insert(<String, dynamic>{
      'email': 'gone@dox.dev',
      'deleted_at': '2024-01-01 00:00:00',
    });
    await orm.QueryBuilder.table('teams').insert(<String, dynamic>{'id': 1});
    for (int id in <int>[1, 2]) {
      await orm.QueryBuilder.table('tags').insert(<String, dynamic>{'id': id});
    }
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close(force: true);
  });

  test('@Unique, @Exists and a list @Exists pass', () async {
    http.Response res = await send('POST', '/members', <String, dynamic>{
      'email': 'new@dox.dev',
      'team_id': 1,
      'tag_ids': <int>[1, 2],
    });
    expect(res.statusCode, 200);
    expect(json(res), <String, dynamic>{
      'email': 'new@dox.dev',
      'tags': <int>[1, 2],
    });
  });

  test('@Unique, @Exists and each list item fail', () async {
    http.Response res = await send('POST', '/members', <String, dynamic>{
      'email': 'taken@dox.dev',
      'team_id': 9,
      'tag_ids': <int>[1, 7, 8],
    });
    expect(res.statusCode, 422);
    expect(json(res), <String, dynamic>{
      'email': 'The email has already been taken',
      'team_id': 'The selected team_id is invalid',
      'tag_ids.1': 'The selected tag_ids is invalid',
      'tag_ids.2': 'The selected tag_ids is invalid',
    });
  });

  test('soft-deleted rows count for @Unique', () async {
    http.Response res = await send('POST', '/members', <String, dynamic>{
      'email': 'gone@dox.dev',
      'team_id': 1,
    });
    expect(json(res), <String, dynamic>{
      'email': 'The email has already been taken',
    });
  });

  test('database rules do not run when a field rule failed', () async {
    http.Response res = await send('POST', '/members', <String, dynamic>{
      'email': 'not-an-email',
      'team_id': 9,
    });
    expect(json(res), <String, dynamic>{
      'email': 'The email is not a valid email',
    });
  });

  test('ignoreParam skips the row being updated', () async {
    http.Response own = await send('PUT', '/members/1', <String, dynamic>{
      'email': 'taken@dox.dev',
    });
    expect(own.statusCode, 200);
    http.Response other = await send('PUT', '/members/5', <String, dynamic>{
      'email': 'taken@dox.dev',
    });
    expect(other.statusCode, 422);
  });

  test('validateSchema gives typed output', () async {
    http.Response res = await send('POST', '/schema', <String, dynamic>{
      'age': '21',
    });
    expect(json(res), <String, dynamic>{'age': 21, 'type': 'int'});

    http.Response bad = await send('POST', '/schema', <String, dynamic>{
      'age': '12',
    });
    expect(bad.statusCode, 422);
    expect(json(bad).keys, <String>['age']);
  });

  test('schema.parse in a controller answers 422', () async {
    http.Response res = await send('POST', '/parse', <String, dynamic>{});
    expect(res.statusCode, 422);
    expect(json(res).keys, <String>['title']);
  });
}
