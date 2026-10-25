import 'dart:convert';
import 'dart:io';

import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../dox-openapi/test/support/openapi_checker.dart';

/// the files of `dox openapi:generate`, made from lib/generated/openapi.g.dart
/// (dart run build_runner build) and the live routes of the app
void main() {
  late Map<String, dynamic> doc;
  late String yaml;

  setUpAll(() async {
    Directory dir = await Directory.systemTemp.createTemp('dox_app_openapi');
    // .env.example has no APP_KEY, so give the test one.
    Env().load();
    if ((Env().env['APP_KEY'] ?? '').isEmpty) {
      Env().env['APP_KEY'] = 'test-key-for-the-app-tests-only1';
    }
    Dox().initialize(appConfig);
    List<File> files = await Dox().writeOpenApi(dir.path);
    doc = jsonDecode(await files[0].readAsString());
    yaml = await files[1].readAsString();
    await dir.delete(recursive: true);
  });

  test('the document is valid', () {
    expect(OpenApiChecker().check(doc), isEmpty);
  });

  test('blog CRUD comes from the controller and the models', () {
    Map<String, dynamic> list = doc['paths']['/api/blogs']['get'];
    expect(list['operationId'], 'BlogController.index');
    expect(list['summary'], 'List blogs');
    expect(list['tags'], <String>['Blog']);
    expect(
      <dynamic>[for (dynamic p in list['parameters']) p['name']],
      <String>['page', 'limit'],
    );
    expect(
      list['responses']['200']['content']['application/json']['schema'],
      <String, dynamic>{r'$ref': '#/components/schemas/Pagination'},
    );

    Map<String, dynamic> store = doc['paths']['/api/blogs']['post'];
    Map<String, dynamic> body =
        store['requestBody']['content']['application/json']['schema'];
    expect(body, <String, dynamic>{r'$ref': '#/components/schemas/SaveBlog'});
    expect(doc['components']['schemas']['SaveBlog']['required'], <String>[
      'title',
      'description',
    ]);
    expect(store['responses'].keys, contains('422'));

    Map<String, dynamic> show = doc['paths']['/api/blogs/{id}']['get'];
    expect(show['parameters'][0]['name'], 'id');
    expect(show['responses'].keys, <String>['200', '404', '500']);
  });

  test('auth routes: DTO bodies and bearer login', () {
    Map<String, dynamic> register = doc['paths']['/api/auth/register']['post'];
    expect(
      register['requestBody']['content']['application/json']['schema'],
      <String, dynamic>{r'$ref': '#/components/schemas/RegisterUser'},
    );
    Map<String, dynamic> user = doc['paths']['/api/auth/user']['get'];
    expect(user['security'], <dynamic>[
      <String, dynamic>{'bearerAuth': <dynamic>[]},
    ]);
    expect(user['responses'].keys, contains('401'));
    expect(doc['components']['securitySchemes'].keys, <String>['bearerAuth']);
  });

  test('blog writes need login, reads do not', () {
    List<dynamic> bearer = <dynamic>[
      <String, dynamic>{'bearerAuth': <dynamic>[]},
    ];
    Map<String, dynamic> blogs = doc['paths']['/api/blogs'];
    Map<String, dynamic> blog = doc['paths']['/api/blogs/{id}'];
    expect(blogs['get']['security'], isNull);
    expect(blog['get']['security'], isNull);
    expect(blogs['post']['security'], bearer);
    expect(blog['put']['security'], bearer);
    expect(blog['patch']['security'], bearer);
    expect(blog['delete']['security'], bearer);
  });

  test('no open demo routes that read, write or delete files', () {
    List<String> routes = <String>[
      for (dynamic r in Route().routes) '${r.method} ${r.path}',
    ];
    expect(routes, contains('GET /ping'));
    expect(routes, isNot(contains('GET /download')));
    expect(routes, isNot(contains('DELETE /image')));
    expect(routes, isNot(contains('DELETE /ping')));
    expect(routes, isNot(contains('POST /ping')));
  });

  test('model schemas leave out hidden fields', () {
    Map<String, dynamic> props =
        doc['components']['schemas']['User']['properties'];
    expect(props.keys, containsAll(<String>['id', 'name', 'email']));
    expect(props.keys, isNot(contains('password')));
  });

  test('@ApiIgnore leaves the route out', () {
    expect(doc['paths'].keys, isNot(contains('/redis')));
  });

  test('YAML and JSON give the same document', () {
    expect(jsonDecode(jsonEncode(loadYaml(yaml))), doc);
  });
}
