import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// a small copy of dox_queue: the builder finds Job and DoxJob by name,
/// in a dox_queue library
const String _queue = '''
class Job {
  const Job({this.name});
  final String? name;
}
abstract class DoxJob {
  Future<void> handle();
  int? get tries => null;
  List<Duration> get backoff => const <Duration>[];
  Duration? get timeout => null;
  String get queue => 'default';
  void failed(Object error, StackTrace stack) {}
}
mixin InteractsWithQueue on DoxJob {
  void release([Duration delay = Duration.zero]) {}
}
''';

const String _golden = 'test/fixtures/jobs/jobs.g.dart';

/// a small copy of dox_mailer with the two mail jobs
const String _mailer = '''
class SendQueuedMail {}
class SendEncryptedQueuedMail {}
''';

/// the generated file, or the build errors
Future<String> _generate(Map<String, String> app) async {
  Map<String, String> sources = <String, String>{
    'dox_queue|lib/dox_queue.dart': _queue,
    ...app,
  };
  TestBuilderResult result = await testBuilder(
    buildJobRegistry(BuilderOptions.empty),
    sources,
    rootPackage: 'a',
  );
  if (!result.succeeded) return 'ERROR: ${result.errors.join('\n')}';
  String output = '';
  await testBuilder(
    buildJobRegistry(BuilderOptions.empty),
    sources,
    rootPackage: 'a',
    outputs: <String, Object>{
      // the test copies of dox_queue and dox_mailer get one too
      'dox_queue|lib/generated/jobs.g.dart': anything,
      if (sources.containsKey('dox_mailer|lib/dox_mailer.dart'))
        'dox_mailer|lib/generated/jobs.g.dart': anything,
      'a|lib/generated/jobs.g.dart': decodedMatches(
        predicate<String>((String s) {
          output = s;
          return true;
        }),
      ),
    },
  );
  return output;
}

Future<String> _error(String source) async {
  String result = await _generate(<String, String>{'a|lib/jobs.dart': source});
  expect(result, startsWith('ERROR'));
  return result;
}

const String _header = '''
import 'package:dox_queue/dox_queue.dart';
enum Color { red }
''';

void main() {
  test('writes the registry of test/fixtures/test_jobs.dart', () async {
    String source = File('test/fixtures/jobs/test_jobs.dart')
        .readAsStringSync();
    String output = await _generate(<String, String>{
      'a|lib/test_jobs.dart': source,
    });
    expect(output, isNot(startsWith('ERROR')), reason: output);
    // the checked-in copy imports the fixture by a relative path
    output = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(output.replaceAll('package:a/test_jobs.dart', 'test_jobs.dart'));
    File golden = File(_golden);
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      golden.writeAsStringSync(output);
    }
    expect(output, golden.readAsStringSync());
    expect(output, contains("JobCodec('all-types', i1.AllTypesJob"));
    expect(output, contains("JobCodec('SendWelcomeEmail'"));
  });

  test('writes an empty registry when there is no job', () async {
    String output = await _generate(<String, String>{
      'a|lib/user.dart': 'class User {}',
    });
    expect(output, contains('const JobRegistry jobRegistry'));
    expect(output, isNot(contains('JobCodec(')));
  });

  test('adds the mail jobs when the app can import dox_mailer', () async {
    String output = await _generate(<String, String>{
      'dox_mailer|lib/dox_mailer.dart': _mailer,
      'a|lib/user.dart': 'class User {}',
    });
    expect(
      output,
      contains("import 'package:dox_mailer/dox_mailer.dart' as i1;"),
    );
    expect(output, contains('i1.SendQueuedMail.codec,'));
    expect(output, contains('i1.SendEncryptedQueuedMail.codec,'));
  });

  test('no mail jobs from a dox_mailer without them', () async {
    String output = await _generate(<String, String>{
      'dox_mailer|lib/dox_mailer.dart': 'class Mail {}',
      'a|lib/user.dart': 'class User {}',
    });
    expect(output, contains('const JobRegistry jobRegistry'));
    expect(output, isNot(contains('dox_mailer')));
  });

  test('writes nothing when the app can not import dox_queue', () async {
    await testBuilder(
      buildJobRegistry(BuilderOptions.empty),
      <String, String>{'a|lib/user.dart': 'class User {}'},
      rootPackage: 'a',
      outputs: <String, Object>{},
    );
  });

  test('writes nothing when dox_queue is not a direct dependency', () async {
    await testBuilder(
      buildJobRegistry(BuilderOptions.empty),
      <String, String>{
        'dox_queue|lib/dox_queue.dart': _queue,
        'dox_mailer|lib/dox_mailer.dart': _mailer,
        'a|pubspec.yaml': 'name: a\ndependencies:\n  dox_mailer: any\n',
        'a|lib/user.dart': 'class User {}',
      },
      rootPackage: 'a',
      outputs: <String, Object>{
        // the test copies of dox_queue and dox_mailer have no pubspec
        'dox_queue|lib/generated/jobs.g.dart': anything,
        'dox_mailer|lib/generated/jobs.g.dart': anything,
      },
    );
  });

  test('writes the file when dox_queue is in the app pubspec', () async {
    String output = await _generate(<String, String>{
      'a|pubspec.yaml': 'name: a\ndependencies:\n  dox_queue: ^3.2.0\n',
      'a|lib/user.dart': 'class User {}',
    });
    expect(output, contains('const JobRegistry jobRegistry'));
  });

  test('hasDirectDependency reads dependencies and dev_dependencies', () {
    bool has(String yaml) {
      return JobRegistryBuilder.hasDirectDependency(yaml, 'dox_queue');
    }

    expect(has('dependencies:\n  dox_queue: ^3.2.0\n'), isTrue);
    expect(has('dev_dependencies:\n  dox_queue:\n    path: ../q\n'), isTrue);
    expect(has('dependencies:\n  # dox_queue: ^3.2.0\n'), isFalse);
    expect(has('dependencies:\n  dox_queue_database: ^3.2.0\n'), isFalse);
    expect(has('dependency_overrides:\n  dox_queue: any\n'), isFalse);
    expect(has('name: a\n'), isFalse);
  });

  test('a job with no fields has no unused variable', () async {
    String output = await _generate(<String, String>{
      'a|lib/jobs.dart':
          '''
$_header
@Job()
class A extends DoxJob {
  @override
  Future<void> handle() async {}
}
''',
    });
    expect(output, contains("JobCodec('A'"));
    expect(output, isNot(contains('value = job')));
  });

  test('a job with InteractsWithQueue and a const constructor', () async {
    String output = await _generate(<String, String>{
      'a|lib/jobs.dart':
          '''
$_header
@Job()
class A extends DoxJob with InteractsWithQueue {
  const A({required this.id, this.note});
  final int id;
  final String? note;
  @override
  Future<void> handle() async {}
}
''',
    });
    expect(output, contains("JobCodec('A'"));
    expect(output, contains("'id': value.id"));
    expect(output, contains("note: data['note'] as String?"));
  });

  test('a job class must extend DoxJob', () async {
    String error = await _error('''
$_header
@Job()
class A { A(); }
''');
    expect(error, contains('must extend DoxJob'));
  });

  test('a parameter type must be a JSON type', () async {
    String error = await _error('''
$_header
class User {}
@Job()
class A extends DoxJob {
  A(this.user);
  final User user;
  @override
  Future<void> handle() async {}
}
''');
    expect(error, contains('parameter "user"'));
    expect(error, contains('User is not a JSON type'));
  });

  test('map keys must be String', () async {
    String error = await _error('''
$_header
@Job()
class A extends DoxJob {
  A(this.byId);
  final Map<int, String> byId;
  @override
  Future<void> handle() async {}
}
''');
    expect(error, contains('map keys must be String'));
  });

  test('a parameter needs a field of the same name', () async {
    String error = await _error('''
$_header
@Job()
class A extends DoxJob {
  A(int id) : userId = id;
  final int userId;
  @override
  Future<void> handle() async {}
}
''');
    expect(error, contains('needs a field or getter "id"'));
  });

  test('a private parameter can not be saved', () async {
    String error = await _error('''
$_header
@Job()
class A extends DoxJob {
  A(this._id);
  final int _id;
  @override
  Future<void> handle() async { print(_id); }
}
''');
    expect(error, contains('private parameter'));
  });

  test('two jobs can not have one name', () async {
    String error = await _error('''
$_header
@Job(name: 'same')
class A extends DoxJob {
  @override
  Future<void> handle() async {}
}
@Job(name: 'same')
class B extends DoxJob {
  @override
  Future<void> handle() async {}
}
''');
    expect(error, contains('Two jobs are named "same"'));
  });

  test('a job name can not start with dox_queue:', () async {
    String error = await _error('''
$_header
@Job(name: 'dox_queue:SendQueuedMail')
class A extends DoxJob {
  @override
  Future<void> handle() async {}
}
''');
    expect(error, contains('kept for the built-in jobs'));
  });
}
