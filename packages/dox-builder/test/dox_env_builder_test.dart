import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:dox_builder/src/env_builder.dart';
import 'package:test/test.dart';

Future<String> _generate(String source) async {
  String output = '';
  await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    <String, String>{
      'dox_annotation|lib/dox_annotation.dart':
          "export 'src/env_annotation.dart';",
      'dox_annotation|lib/src/env_annotation.dart': File(
        '../dox-annotation/lib/src/env_annotation.dart',
      ).readAsStringSync(),
      'a|lib/env.dart':
          '''
import 'package:dox_annotation/dox_annotation.dart';
part 'env.g.dart';
enum Level { debug, info }
$source
''',
    },
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
    expect(out, contains("String? appName = r.string('APP_NAME');"));
    expect(out, contains("r.need('APP_NAME');"));
    expect(out, contains('appName: appName!,'));
    expect(out, contains("int dbPort = r.integer('DB_PORT') ?? d.dbPort;"));
    expect(out, contains("r.decimal('RATE')"));
    expect(out, contains("r.number('RATIO')"));
    expect(out, contains("r.boolean('APP_DEBUG')"));
    expect(out, contains("String? s3Bucket = r.string('AWS_BUCKET');"));
    expect(out, isNot(contains("r.need('AWS_BUCKET')")));
    expect(out, contains("r.uri('APP_URL')"));
    expect(out, contains("r.duration('CACHE_TTL')"));
    expect(out, contains("r.enumByName('LOG_LEVEL', Level.values)"));
    expect(out, contains("r.list('HOSTS')"));
    expect(out, contains(r'class _$AppEnvDefaults extends AppEnv'));
  });

  test('DoxEnvBuilder | no defaults class without defaults', () async {
    String out = await _generate('''
@DoxEnv()
abstract class AppEnv {
  String get appKey;
}
''');
    expect(out, isNot(contains('Defaults')));
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
}
