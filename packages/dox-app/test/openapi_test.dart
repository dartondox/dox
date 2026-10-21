import 'dart:convert';
import 'dart:io';

import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../dox-openapi/test/support/openapi_checker.dart';

/// the files of `dox openapi:generate`, made from lib/openapi.g.dart
/// (dart run build_runner build) and the live routes of the app
void main() {
  late Map<String, dynamic> doc;
  late String yaml;

  setUpAll(() async {
    Directory dir = await Directory.systemTemp.createTemp('dox_app_openapi');
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
      <String>['page', 'limit', 'with_trashed'],
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
