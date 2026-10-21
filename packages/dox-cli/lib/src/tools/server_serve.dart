import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

serverServe() async {
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

Future<Process> _startServer([message]) async {
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

watchBuilder() async {
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

buildBuilder() async {
  var process = await Process.start('dart', ['run', 'build_runner', 'build']);
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
/// output:
///   build/server              native binary (no Dart SDK needed to run)
///   build/db/                 migrations, read at start
///   build/.env.example        copy it to build/.env or set env vars
///
/// `dart run` (used by `dox serve`) is JIT: more memory and slower start.
/// never run production with it.
Future<void> buildServer() async {
  bool usesBuildRunner = File('pubspec.yaml').existsSync() &&
      File('pubspec.yaml').readAsStringSync().contains('build_runner');
  if (usesBuildRunner &&
      await _run('dart', <String>[
            'run',
            'build_runner',
            'build',
            '--delete-conflicting-outputs',
          ]) !=
          0) {
    exitCode = 1;
    return;
  }

  Directory('build').createSync(recursive: true);
  if (await _run('dart', <String>[
        'compile',
        'exe',
        'bin/server.dart',
        '-o',
        'build/server',
      ]) !=
      0) {
    exitCode = 1;
    return;
  }

  if (Directory('db').existsSync()) _copyDir(Directory('db'), 'build/db');
  if (File('.env.example').existsSync()) {
    File('.env.example').copySync('build/.env.example');
  }
  print(
      '\x1B[32m[Dox] Built build/server. Run it with: cd build && ./server\x1B[0m');
}

/// run a command with its output shown, return the exit code
Future<int> _run(String command, List<String> args) async {
  Process process =
      await Process.start(command, args, mode: ProcessStartMode.inheritStdio);
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
