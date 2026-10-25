import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// a small copy of dox_core: the builder finds Router and DoxService by
/// name, in a dox_core library.
const String _core = '''
export 'package:dox_annotation/dox_annotation.dart';

abstract class Router {
  void register();
}
abstract class DoxService {
  dynamic setup() {}
}
class IocContainer {}
''';

Map<String, String> _sources(Map<String, String> app) {
  return <String, String>{
    'dox_annotation|lib/dox_annotation.dart': '''
export 'src/dox_model.dart';
export 'src/inject_annotation.dart';
''',
    'dox_annotation|lib/src/dox_model.dart': File(
      '../dox-annotation/lib/src/dox_model.dart',
    ).readAsStringSync(),
    'dox_annotation|lib/src/inject_annotation.dart': File(
      '../dox-annotation/lib/src/inject_annotation.dart',
    ).readAsStringSync(),
    'dox_core|lib/dox_core.dart': _core,
    ...app,
  };
}

/// the generated file without white space, or the build errors
Future<String> _generate(Map<String, String> app) async {
  TestBuilderResult result = await testBuilder(
    buildDoxContainer(BuilderOptions.empty),
    _sources(app),
    rootPackage: 'a',
  );
  if (!result.succeeded) return 'ERROR: ${result.errors.join('\n')}';
  String output = '';
  await testBuilder(
    buildDoxContainer(BuilderOptions.empty),
    _sources(app),
    rootPackage: 'a',
    outputs: <String, Object>{
      'a|lib/container.g.dart': decodedMatches(
        predicate<String>((String s) {
          output = s;
          return true;
        }),
      ),
    },
  );
  return _flat(output);
}

/// [code] without white space and trailing commas, so formatting does
/// not matter
String _flat(String code) {
  return code.replaceAll(RegExp(r'\s'), '').replaceAll(',)', ')');
}

const String _import = "import 'package:dox_core/dox_core.dart';\n";

void main() {
  group('container builder |', () {
    test('a simple class', () async {
      String out = await _generate(<String, String>{
        'a|lib/repo.dart':
            '''
$_import
@Inject()
class UserRepository {}
class NotInjected {}
''',
      });
      expect(out, contains(_flat("import 'package:a/repo.dart' as i1;")));
      expect(
        out,
        contains(
          _flat(
            'c.singleton<i1.UserRepository>((IocContainer c) => '
            'i1.UserRepository());',
          ),
        ),
      );
      expect(out, isNot(contains('NotInjected')));
      expect(out, contains('voidregisterContainer(IocContainerc)'));
    });

    test('constructor dependencies across libraries', () async {
      String out = await _generate(<String, String>{
        'a|lib/repo.dart':
            '''
$_import
@Inject()
class UserRepository {}
''',
        'a|lib/service.dart':
            '''
$_import
import 'repo.dart';
@Inject(singleton: false)
class UserService {
  UserService(this.users);
  final UserRepository users;
}
''',
      });
      expect(
        out,
        contains(
          _flat(
            'c.factory<i2.UserService>((IocContainer c) => '
            'i2.UserService(c.get<i1.UserRepository>(),));',
          ),
        ),
      );
    });

    test('named, optional and nullable parameters', () async {
      String out = await _generate(<String, String>{
        'a|lib/a.dart':
            '''
$_import
class Clock {}
@Inject()
class Repo {}
@Inject()
class Service {
  Service(
    this.repo, {
    required this.named,
    this.clock,
    required this.maybe,
    this.limit = 10,
  });
  final Repo repo;
  final Repo named;
  final Clock? clock;
  final Clock? maybe;
  final int limit;
}
''',
      });
      expect(
        out,
        contains(
          _flat(
            'i1.Service(c.get<i1.Repo>(), named: c.get<i1.Repo>(), '
            'maybe: null,)',
          ),
        ),
      );
    });

    test('a missing dependency stops the build', () async {
      String out = await _generate(<String, String>{
        'a|lib/a.dart':
            '''
$_import
class Mailer {}
@Inject()
class Service {
  Service(this.mailer);
  final Mailer mailer;
}
''',
      });
      expect(out, startsWith('ERROR'));
      expect(out, contains('Service (package:a/a.dart) needs a Mailer'));
      expect(out, contains('Add @Inject() above that class'));
    });

    test('a cycle stops the build and shows the chain', () async {
      String out = await _generate(<String, String>{
        'a|lib/a.dart':
            '''
$_import
@Inject()
class A {
  A(this.b);
  final B b;
}
@Inject()
class B {
  B(this.c);
  final C c;
}
@Inject()
class C {
  C(this.a);
  final A a;
}
''',
      });
      expect(
        out,
        contains('Dependency cycle in the container: A -> B -> C -> A'),
      );
    });

    test('abstract and generic classes stop the build', () async {
      String abstract = await _generate(<String, String>{
        'a|lib/a.dart': '$_import@Inject()\nabstract class A {}',
      });
      expect(abstract, contains('an abstract class can not be made'));
      String generic = await _generate(<String, String>{
        'a|lib/a.dart': '$_import@Inject()\nclass A<T> {}',
      });
      expect(generic, contains('a generic class can not be in the container'));
    });

    test('routers and services are found without @Inject', () async {
      String out = await _generate(<String, String>{
        'a|lib/a.dart':
            '''
$_import
@Inject()
class Repo {}
class ApiRouter extends Router {
  ApiRouter(this.repo);
  final Repo repo;
  void register() {}
}
abstract class BaseRouter extends Router {}
class OrmService implements DoxService {
  dynamic setup() {}
}
''',
      });
      expect(
        out,
        contains(
          _flat(
            'c.router<i1.ApiRouter>((IocContainer c) => '
            'i1.ApiRouter(c.get<i1.Repo>(),));',
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat(
            'c.service<i1.OrmService>((IocContainer c) => i1.OrmService());',
          ),
        ),
      );
      expect(out, isNot(contains('BaseRouter')));
    });

    test('a class named Router of another package is not a router', () async {
      await testBuilder(
        buildDoxContainer(BuilderOptions.empty),
        _sources(<String, String>{
          'a|lib/a.dart': '''
abstract class Router {}
class Web extends Router {}
''',
        }),
        rootPackage: 'a',
        outputs: <String, Object>{},
      );
    });

    test('model binders, by primary key type', () async {
      String out = await _generate(<String, String>{
        'a|lib/models.dart':
            '''
$_import
@DoxModel()
class User {
  Future<User?> find(dynamic id) async => null;
}
@DoxModel(primaryKeyType: String)
class Token {
  Future<Token?> find(dynamic id) async => null;
}
''',
      });
      expect(
        out,
        contains(
          _flat(
            'c.bindModel<i1.User>((String id) {int? key = int.tryParse(id); '
            'if (key == null) return null; return i1.User().find(key);});',
          ),
        ),
      );
      expect(
        out,
        contains(
          _flat('c.bindModel<i1.Token>((String id) => i1.Token().find(id));'),
        ),
      );
    });

    test('two classes with one name get two prefixes', () async {
      String out = await _generate(<String, String>{
        'a|lib/a.dart': '$_import@Inject()\nclass Same {}',
        'a|lib/b.dart': '$_import@Inject()\nclass Same {}',
      });
      expect(out, contains('c.singleton<i1.Same>'));
      expect(out, contains('c.singleton<i2.Same>'));
    });

    test('nothing to register, no file', () async {
      await testBuilder(
        buildDoxContainer(BuilderOptions.empty),
        _sources(<String, String>{'a|lib/a.dart': 'class A {}'}),
        rootPackage: 'a',
        outputs: <String, Object>{},
      );
    });
  });
}
