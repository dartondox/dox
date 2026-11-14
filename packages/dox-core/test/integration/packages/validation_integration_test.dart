import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../dtos/dtos.dart';
import '../../utils/test_app_key.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

class ValidationRouter extends Router {
  @override
  void register() {
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
  appKey: testAppKey,
  // the OS picks a free port, so test files can run in parallel
  serverPort: 0,
  totalIsolate: 1,
  routers: <Router>[ValidationRouter()],
  dtos: testDtos,
  exceptionHandler: const _QuietExceptionHandler(),
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
  // @Unique and @Exists need a database. They are tested in
  // dartondox/dox-orm.
  setUpAll(() async {
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close(force: true);
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

  test('schema.parse in a controller keeps the issues', () async {
    http.Request request = http.Request('POST', Uri.parse('$baseUrl/parse'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-issues'] = '1'
      ..body = '{}';
    http.Response res = await http.Response.fromStream(await request.send());
    expect(json(res), <String, dynamic>{
      'issues': <String>['title:required'],
    });
  });
}

/// does not log the errors the tests cause on purpose
class _QuietExceptionHandler extends ExceptionHandler {
  const _QuietExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {}

  /// with `x-issues: 1`: the issues that reach the handler
  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is ValidationException && req.headers.value('x-issues') == '1') {
      return <String, dynamic>{
        'issues': <String>[
          for (ValidationIssue issue in error.issues)
            '${issue.dottedPath}:${issue.code}',
        ],
      };
    }
    return super.render(error, req);
  }
}
