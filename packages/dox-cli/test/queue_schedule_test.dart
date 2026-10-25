import 'dart:async';
import 'dart:io';

import 'package:dox/src/command_registry.dart';
import 'package:dox/src/tools/create_job.dart';
import 'package:test/test.dart';

/// Commands write relative to the current directory,
/// so each test runs inside its own temp dir.
void main() {
  late Directory tempDir;
  late Directory originalCwd;

  setUp(() {
    originalCwd = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('dox_queue_test_');
    Directory.current = tempDir;
  });

  tearDown(() {
    exitCode = 0;
    Directory.current = originalCwd;
    tempDir.deleteSync(recursive: true);
  });

  /// run a command and return what it printed
  Future<String> run(String command, List<String> args) async {
    StringBuffer out = StringBuffer();
    await runZoned(
      () => CommandRegistry.findCommand(command)!.function(args),
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          out.writeln(line);
        },
      ),
    );
    return out.toString();
  }

  /// a fake script that writes its args to args.txt and exits with 3
  void fakeScript(String path) {
    File('${tempDir.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import 'dart:io';

void main(List<String> args) {
  File('args.txt').writeAsStringSync(args.join('|'));
  exit(3);
}
''');
  }

  group('create:* aliases', () {
    test('every old name still finds the make:* command', () {
      for (String name in <String>[
        'controller',
        'middleware',
        'dto',
        'serializer',
        'model',
        'migration',
        'factory',
        'seeder',
      ]) {
        expect(
          CommandRegistry.findCommand('create:$name')?.command,
          'make:$name',
        );
        expect(
          CommandRegistry.findCommand('make:$name')?.aliases,
          contains('create:$name'),
        );
      }
    });
  });

  group('queue commands', () {
    test('missing bin/queue.dart prints how to set it up', () async {
      String out = await run('queue:work', <String>[]);
      expect(out, contains('bin/queue.dart is missing'));
      expect(out, contains('dox_queue'));
      expect(out, contains('dox make:job'));
      expect(exitCode, 1);
    });

    test('queue:work passes the flags and returns the exit code', () async {
      fakeScript('bin/queue.dart');
      await run('queue:work', <String>['--queue=a,b', '--once', '--tries=2']);
      expect(
        File('args.txt').readAsStringSync(),
        'work|--queue=a,b|--once|--tries=2',
      );
      expect(exitCode, 3);
    });

    test('each command runs its own subcommand', () async {
      fakeScript('bin/queue.dart');
      const Map<String, List<String>> cases = <String, List<String>>{
        'queue:failed': <String>[],
        'queue:retry': <String>['all'],
        'queue:forget': <String>['7'],
        'queue:flush': <String>[],
      };
      for (MapEntry<String, List<String>> c in cases.entries) {
        await run(c.key, c.value);
        String sub = c.key.split(':').last;
        expect(
          File('args.txt').readAsStringSync(),
          [sub, ...c.value].join('|'),
        );
      }
    });

    test('argument counts', () {
      expect(
        CommandRegistry.findCommand('queue:retry')!.validateArgs(<String>[]),
        isFalse,
      );
      expect(
        CommandRegistry.findCommand('queue:forget')!
            .validateArgs(<String>['1']),
        isTrue,
      );
      expect(
        CommandRegistry.findCommand('queue:work')!
            .validateArgs(<String>['--once', '--sleep=1']),
        isTrue,
      );
    });
  });

  group('make:job', () {
    test('writes the job and bin/queue.dart', () async {
      File('pubspec.yaml').writeAsStringSync('name: my_app\n');
      expect(createJob('SendWelcomeEmail'), isTrue);
      String job = File('lib/app/jobs/send_welcome_email.job.dart')
          .readAsStringSync();
      expect(job, contains("import 'package:dox_queue/dox_queue.dart';"));
      expect(job, contains('@Job()\nclass SendWelcomeEmail extends DoxJob {'));
      expect(job, contains('  SendWelcomeEmail();'));
      String entry = File('bin/queue.dart').readAsStringSync();
      expect(entry, contains("import 'package:my_app/config/app.dart';"));
      expect(entry, contains("import 'package:my_app/generated/jobs.g.dart';"));
      expect(entry, contains('QueueWorker(jobs: jobRegistry, app: appConfig)'));
    });

    test(
      'keeps an existing bin/queue.dart and does not overwrite a job',
      () async {
        File('pubspec.yaml').writeAsStringSync('name: my_app\n');
        File('bin/queue.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('// mine');
        expect(createJob('SendWelcomeEmailJob'), isTrue);
        expect(File('bin/queue.dart').readAsStringSync(), '// mine');
        expect(createJob('SendWelcomeEmail'), isFalse);
      },
    );

    test('hints to add dox_queue only when it is missing', () async {
      File('pubspec.yaml').writeAsStringSync('name: my_app\n');
      String out = await run('make:job', <String>['A']);
      expect(out, contains('dart pub add dox_queue'));
      expect(out, contains('build_runner'));
      File(
        'pubspec.yaml',
      ).writeAsStringSync('name: my_app\ndependencies:\n  dox_queue: ^1.0.0\n');
      out = await run('make:job', <String>['B']);
      expect(out, isNot(contains('dart pub add')));
    });
  });

  group('schedule commands', () {
    test('missing bin/schedule.dart prints how to set it up', () async {
      String out = await run('schedule:list', <String>[]);
      expect(out, contains('bin/schedule.dart is missing'));
      expect(out, contains('dox_scheduler'));
      expect(out, contains('lib/config/schedule.dart'));
      expect(exitCode, 1);
    });

    test(
      'each command runs its subcommand and returns the exit code',
      () async {
        fakeScript('bin/schedule.dart');
        const Map<String, List<String>> cases = <String, List<String>>{
          'schedule:work': <String>[],
          'schedule:run': <String>[],
          'schedule:list': <String>[],
          'schedule:test': <String>['report'],
        };
        for (MapEntry<String, List<String>> c in cases.entries) {
          exitCode = 0;
          await run(c.key, c.value);
          String sub = c.key.split(':').last;
          expect(
            File('args.txt').readAsStringSync(),
            [sub, ...c.value].join('|'),
          );
          expect(exitCode, 3);
        }
      },
    );

    test('schedule:test needs a name', () {
      expect(
        CommandRegistry.findCommand('schedule:test')!.validateArgs(<String>[]),
        isFalse,
      );
    });
  });
}
