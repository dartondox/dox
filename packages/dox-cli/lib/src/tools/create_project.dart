import 'dart:convert';
import 'dart:io';

import 'package:dox/dox.dart';

createProject(projectName, [String? versionName]) async {
  projectName = pascalToSnake(projectName);

  final projectFolder = Directory('${Directory.current.path}/$projectName');

  if (projectFolder.existsSync()) {
    print('\x1B[31mFolder name "$projectName" already exist\x1B[0m');
    return;
  }

  print("\x1B[32m✔\x1B[0m Project name : $projectName");
  print("\x1B[32m✔\x1B[0m Creating...");

  ProcessResult version = Process.runSync('curl', [
    'https://api.github.com/repos/dartondox/dox-sample/releases/latest',
    '-s',
  ]);

  Map<String, dynamic> versionData = jsonDecode(version.stdout);

  /// use version name if provided, else use latest version
  String latestTag = versionName ?? versionData['name'];

  /// replace v with empty space if there is v in version and join again v
  /// so that it work for both 'v2.0.0' and '2.0.0'
  latestTag = 'v${latestTag.replaceFirst('v', '')}';

  print("\x1B[32m✔\x1B[0m Version : $latestTag");

  ProcessResult result = Process.runSync('git', [
    'clone',
    '--depth',
    '1',
    '--branch',
    latestTag,
    'https://github.com/dartondox/dox-sample.git',
    projectName
  ]);

  if (result.stderr != null) {
    if (result.stderr.toString().contains('Could not find')) {
      print('\x1B[31m${result.stderr}\x1B[0m');
      return;
    }
  }

  Directory gitDirectory = Directory('${projectFolder.path}/.git');

  if (!gitDirectory.existsSync()) {
    return;
  }

  /// remove `.git` folder
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
