import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

Future<void> serverServe() async {
  DirectoryWatcher watcher = DirectoryWatcher(Directory.current.path);
  Timer? timer;
  Process? process;

  process = await _startServer();

  watcher.events.listen((event) async {
    if (path.extension(event.path) != '.dart') {
      return;
    }
    print("\x1B[34m[Dox] File changed: ${path.basename(event.path)}");
    if (timer != null) {
      timer?.cancel();
    }

    timer = Timer(Duration(milliseconds: 500), () async {
      process?.kill();
      int? exitCode = await process?.exitCode;
      if (exitCode.toString().isNotEmpty) {
        process = await _startServer();
      }
    });
  });
}

Future<Process> _startServer([String? message]) async {
  if (message != null) {
    print('\x1B[34m[Dox] $message..\x1B[0m');
  }
  Process process = await Process.start('dart', ['run', 'bin/server.dart']);
  process.stdout.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });

  process.stderr.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });
  return process;
}

Future<Process> watchBuilder() async {
  var process = await Process.start('dart', ['run', 'build_runner', 'watch']);

  process.stderr.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });
  return process;
}

/// `dart run build_runner build`. build_runner removed
/// `--delete-conflicting-outputs`, so it is not passed.
const List<String> buildRunnerBuildArgs = <String>[
  'run',
  'build_runner',
  'build',
];

Future<void> buildBuilder() async {
  var process = await Process.start('dart', buildRunnerBuildArgs);
  process.stdout.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    print(lines.first.toString().replaceAll('INFO', 'Dox'));
  });

  process.stderr.transform(utf8.decoder).listen((data) {
    List lines = data.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        print(line);
      }
    }
  });
}

/// AOT compile the app for production.
///
/// output (a `dart build cli` bundle):
///   build/bundle/bin/server     native binary (no Dart SDK needed to run)
///   build/bundle/lib/           native libraries from build hooks (eg. SQLite)
///   build/bundle/db/            migrations, read at start
///   build/bundle/.env.example   copy it to .env or set env vars
///
/// `dart compile exe` can not build packages with build hooks (sqlite3 v3),
/// so this uses `dart build cli`. It is the same AOT compiler.
///
/// `dart run` (used by `dox serve`) is JIT: more memory and slower start.
/// never run production with it.
Future<void> buildServer() async {
  bool usesBuildRunner =
      File('pubspec.yaml').existsSync() &&
      File('pubspec.yaml').readAsStringSync().contains('build_runner');
  if (usesBuildRunner && await _run('dart', buildRunnerBuildArgs) != 0) {
    exitCode = 1;
    return;
  }

  if (await _run('dart', <String>[
        'build',
        'cli',
        '--target',
        'bin/server.dart',
        '--output',
        'build',
      ]) !=
      0) {
    exitCode = 1;
    return;
  }

  Directory oldDb = Directory('build/bundle/db');
  if (oldDb.existsSync()) oldDb.deleteSync(recursive: true);
  if (Directory('db').existsSync()) {
    _copyDir(Directory('db'), 'build/bundle/db');
  }
  if (File('.env.example').existsSync()) {
    File('.env.example').copySync('build/bundle/.env.example');
  }
  print(
    '\x1B[32m[Dox] Built build/bundle. Run it with: '
    'cd build/bundle && ./bin/server\x1B[0m',
  );
}

/// run a command with its output shown, return the exit code
Future<int> _run(String command, List<String> args) async {
  Process process = await Process.start(
    command,
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

void _copyDir(Directory from, String to) {
  for (FileSystemEntity entity in from.listSync(recursive: true)) {
    String target = path.join(to, path.relative(entity.path, from: from.path));
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}
