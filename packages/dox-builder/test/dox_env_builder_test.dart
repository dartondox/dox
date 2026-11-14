import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:dox_builder/src/env_builder.dart';
import 'package:test/test.dart';

Map<String, String> _sources(String source, String imports) {
  return <String, String>{
    'dox_annotation|lib/dox_annotation.dart':
        "export 'src/env_annotation.dart';",
    'dox_annotation|lib/src/env_annotation.dart': File(
      '../dox-annotation/lib/src/env_annotation.dart',
    ).readAsStringSync(),
    'a|lib/other.dart': 'enum Mode { slow, fast }',
    'a|lib/env.dart':
        '''
import 'package:dox_annotation/dox_annotation.dart';
$imports
part 'env.g.dart';
enum Level { debug, info }
$source
''',
  };
}

/// the build errors of [source], joined
Future<String> _errors(String source) async {
  TestBuilderResult result = await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    _sources(source, ''),
    rootPackage: 'a',
  );
  return result.errors.join('\n');
}

Future<String> _generate(String source, {String imports = ''}) async {
  String output = '';
  await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    _sources(source, imports),
    rootPackage: 'a',
    outputs: <String, Object>{
      'a|lib/env.dox_model_generator.g.part': decodedMatches(
        predicate<String>((String s) {
          output = s;
          return true;
        }),
      ),
    },
  );
  return output;
}

void main() {
  test('upperSnake', () {
    expect(upperSnake('appName'), 'APP_NAME');
    expect(upperSnake('s3Bucket'), 'S3_BUCKET');
    expect(upperSnake('port'), 'PORT');
    expect(upperSnake('oauth2ClientId'), 'OAUTH2_CLIENT_ID');
    expect(upperSnake('_secret'), '_SECRET');
    // a run of capitals is one word
    expect(upperSnake('dbURL'), 'DB_URL');
    expect(upperSnake('awsS3URL'), 'AWS_S3_URL');
    expect(upperSnake('jwtTTL'), 'JWT_TTL');
    expect(upperSnake('httpURLPath'), 'HTTP_URL_PATH');
  });

  test('DoxEnvBuilder | keys, types, defaults and optional', () async {
    String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  String get appName;
  int get dbPort => 5432;
  double get rate => 0.5;
  num get ratio => 1;
  bool get appDebug => false;
  @EnvKey('AWS_BUCKET')
  String? get s3Bucket;
  Uri get appUrl;
  Duration get cacheTtl => const Duration(minutes: 5);
  Level get logLevel => Level.info;
  List<String> get hosts => <String>[];
}
''');
    expect(out, contains(r'class _$AppEnv extends AppEnv'));
    expect(out, contains('final String appName;'));
    expect(out, contains(r"String? appName = $r.string('APP_NAME');"));
    expect(out, contains(r"$r.need('APP_NAME');"));
    expect(out, contains('appName: appName!,'));
    expect(out, contains(r"int? dbPort = $r.integer('DB_PORT');"));
    expect(out, contains(r'final int? _$dbPort;'));
    expect(out, contains(r'late final int dbPort = _$dbPort ?? super.dbPort;'));
    expect(out, contains(r'_$dbPort = dbPort'));
    expect(out, contains(r'$env.dbPort;'));
    expect(out, contains("r.decimal('RATE')"));
    expect(out, contains("r.number('RATIO')"));
    expect(out, contains("r.boolean('APP_DEBUG')"));
    expect(out, contains(r"String? s3Bucket = $r.string('AWS_BUCKET');"));
    expect(out, isNot(contains("need('AWS_BUCKET')")));
    expect(out, contains("r.uri('APP_URL')"));
    expect(out, contains("r.duration('CACHE_TTL')"));
    expect(out, contains("r.enumByName('LOG_LEVEL', Level.values)"));
    expect(out, contains("r.list('HOSTS')"));
    expect(out, isNot(contains('Defaults')));
  });

  test('DoxEnvBuilder | a default can use another getter', () async {
    String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  int get appPort => 3000;
  String get appUrl => 'http://localhost:\$appPort';
  String? get region => null;
}
''');
    expect(
      out,
      contains(r'late final int appPort = _$appPort ?? super.appPort;'),
    );
    expect(
      out,
      contains(r'late final String appUrl = _$appUrl ?? super.appUrl;'),
    );
    // a nullable getter with a body keeps one `?`
    expect(out, contains(r'final String? _$region;'));
    expect(
      out,
      contains(r'late final String? region = _$region ?? super.region;'),
    );
    expect(out, isNot(contains('String??')));
  });

  test('DoxEnvBuilder | no defaults, no late fields', () async {
    String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  String get appKey;
}
''');
    expect(out, contains('final String appKey;'));
    expect(out, isNot(contains('late')));
    expect(out, isNot(contains('super.')));
  });

  test('DoxEnvBuilder | unsupported type fails', () async {
    expect(
      _generate('''
@DoxEnv()
abstract class AppEnv {
  DateTime get start;
}
'''),
      throwsA(anything),
    );
  });

  test(
    'DoxEnvBuilder | an enum from a prefixed import keeps the prefix',
    () async {
      String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  o.Mode get mode;
  @EnvKey(r'A\$B')
  String? get odd;
}
''', imports: "import 'other.dart' as o;");
      expect(out, contains('final o.Mode mode;'));
      expect(out, contains("enumByName('MODE', o.Mode.values)"));
      expect(out, contains(r"string('A\$B')"));
    },
  );

  test('DoxEnvBuilder | @EnvKey from a const variable', () async {
    String out = await _generate('''
const EnvKey bucket = EnvKey('AWS_BUCKET');
@DoxEnv()
abstract class AppEnv {
  @bucket
  String? get s3Bucket;
}
''');
    expect(out, contains("string('AWS_BUCKET')"));
  });

  test('DoxEnvBuilder | a getter named r or reader does not clash', () async {
    String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  String? get r;
  String? get reader;
}
''');
    expect(out, contains(r"String? r = $r.string('R');"));
    expect(out, contains(r"String? reader = $r.string('READER');"));
    expect(out, contains(r'load([EnvReader? $reader])'));
  });

  test('DoxEnvBuilder | an instance field fails with a clear error', () async {
    String errors = await _errors('''
@DoxEnv()
abstract class AppEnv {
  final String appName = 'dox';
}
''');
    expect(errors, contains('has the field "appName"'));
  });

  test(
    'DoxEnvBuilder | load() stops a default that reads the global env',
    () async {
      String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  String get appEnv => 'production';
  String? get loading;
}
''');
      expect(out, contains(r'static bool _$$loading = false;'));
      expect(out, contains(r'if (_$$loading) {'));
      expect(out, contains('A default of AppEnv reads the global `env`.'));
      expect(out, contains(r'_$$loading = false;'));
      expect(out, contains('finally'));
      // a getter named `loading` has its own raw field, no clash
      expect(out, contains(r'final String? loading;'));
    },
  );
}
