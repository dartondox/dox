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

buildServer() async {
  var process = await Process.start(
      'dart', ['compile', 'exe', 'bin/server.dart', '-o', 'bin/server']);

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
