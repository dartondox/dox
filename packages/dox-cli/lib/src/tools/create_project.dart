import 'dart:io';

import 'package:dox/dox.dart';

createProject(projectName) async {
  projectName = pascalToSnake(projectName);

  print("\x1B[32m✔\x1B[0m Project name - $projectName");

  final projectFolder = Directory('${Directory.current.path}/$projectName');

  Process.runSync('git', [
    'clone',
    '-b',
    'v2.x',
    'https://github.com/necessarylion/dox-sample.git',
    projectName
  ]);

  Directory gitDirectory = Directory('${projectFolder.path}/.git');
  gitDirectory.deleteSync(recursive: true);

  // Replace the project name in all files
  final files = projectFolder.listSync(recursive: true);
  for (final file in files) {
    if (file is File) {
      final content =
          file.readAsStringSync().replaceAll('dox_sample', projectName);
      file.writeAsStringSync(content);
    }
  }

  print('\x1B[32m✔\x1B[0m Done. Created at - ${projectFolder.path}');
  print('\x1B[32m✔\x1B[0m Now run:\n');
  print('    ➢ cd $projectName');
  print('    ➢ dart pub get');
  print('    ➢ cp .env.example .env (modify .env variables)');
  print('    ➢ dox serve\n');
}
