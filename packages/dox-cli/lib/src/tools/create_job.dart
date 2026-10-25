import 'dart:io';

import '../utils/utils.dart';
import 'create_factory.dart';

String _getSample(String className) {
  return '''
import 'package:dox_queue/dox_queue.dart';

/// Dispatch: await $className(userId: 1).dispatch();
/// Run `dart run build_runner build` after you change the fields.
@Job()
class $className extends DoxJob {
  $className();

  @override
  Future<void> handle() async {
    /// write your logic here
  }
}
''';
}

/// source of `bin/queue.dart`, for the app package [package]
String queueEntrySource(String package) {
  return '''
import 'dart:io';

import 'package:dox_queue/dox_queue.dart';
import 'package:$package/config/app.dart';
import 'package:$package/jobs.g.dart';

/// Runs the queue worker: `dox queue:work`, or
/// `dart run bin/queue.dart work [--queue=default] [--concurrency=1]`.
Future<void> main(List<String> args) async {
  exitCode = await QueueWorker(jobs: jobRegistry, app: appConfig).run(args);
}
''';
}

/// `dox make:job SendWelcomeEmail` makes
/// `lib/app/jobs/send_welcome_email.job.dart`, and `bin/queue.dart` when
/// it is missing.
bool createJob(String name) {
  String filename = pascalToSnake(name).replaceAll(RegExp(r'_?job$'), '');
  String className = snakeToPascal(filename);
  String? package = appPackageName();
  if (package == null) {
    print('pubspec.yaml has no name. Run this in the app folder.');
    exitCode = 1;
    return false;
  }
  String jobName = '$filename.job';
  File file = File('${Directory.current.path}/lib/app/jobs/$jobName.dart');
  if (file.existsSync()) {
    print('\x1B[32m$jobName already exists\x1B[0m');
    return false;
  }
  file.createSync(recursive: true);
  file.writeAsStringSync(_getSample(className));

  File entry = File('${Directory.current.path}/bin/queue.dart');
  if (!entry.existsSync()) {
    entry.createSync(recursive: true);
    entry.writeAsStringSync(queueEntrySource(package));
    print('\x1B[32mbin/queue.dart created.\x1B[0m');
  }
  print('\x1B[32m$jobName created successfully.\x1B[0m');

  File pubspec = File('${Directory.current.path}/pubspec.yaml');
  if (!RegExp(
    r'^\s+dox_queue:',
    multiLine: true,
  ).hasMatch(pubspec.readAsStringSync())) {
    print('Add dox_queue to pubspec.yaml: `dart pub add dox_queue`');
  }
  print('Run `dox build_runner:build` to make lib/jobs.g.dart.');
  return true;
}
