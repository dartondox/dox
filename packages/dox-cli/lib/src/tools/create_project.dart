import 'dart:convert';
import 'dart:io';

import 'package:dox/dox.dart';
import 'package:dox/src/tools/generate_key.dart';
import 'package:dox/src/utils/versions.dart';
import 'package:dox/src/version.dart';

Future<void> createProject(String projectName, [String? versionName]) async {
  projectName = pascalToSnake(projectName);

  final projectFolder = Directory('${Directory.current.path}/$projectName');

  if (projectFolder.existsSync()) {
    print('\x1B[31mFolder name "$projectName" already exist\x1B[0m');
    return;
  }

  print("\x1B[32m✔\x1B[0m Project name : $projectName");
  print("\x1B[32m✔\x1B[0m Creating...");

  /// use version name if provided, else the newest template for this CLI
  String? latestTag = versionName ?? _latestTemplate();
  if (latestTag == null) {
    print(
      '\x1B[31mCould not find a template release for Dox $version. '
      'Check your network, or pass --version.\x1B[0m',
    );
    return;
  }

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
    projectName,
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

  replaceProjectName(projectFolder, projectName);
  createEnv(projectFolder);

  print('\x1B[32m✔\x1B[0m Done. Created at - ${projectFolder.path}');
  print('\x1B[32m✔\x1B[0m .env created with a new APP_KEY');
  print('\x1B[32m✔\x1B[0m Now run:\n');
  print('    ➢ cd $projectName');
  print('    ➢ dart pub get');
  print('    ➢ dox serve\n');
}

/// Copies `.env.example` to `.env` in [folder] and sets a new `APP_KEY`.
///
/// Each project gets its own secret key. The key in `.env.example` is
/// public, so it must never be used. Does nothing when `.env` exists or
/// there is no `.env.example`.
void createEnv(Directory folder) {
  File example = File('${folder.path}/.env.example');
  File env = File('${folder.path}/.env');
  if (env.existsSync() || !example.existsSync()) return;
  example.copySync(env.path);
  overrideKey(newKey(), env.path);
}

/// Replaces `dox_sample` with [projectName] in every text file of [folder].
///
/// Files that are not valid UTF-8 (a SQLite file, an image, a font) are
/// skipped. A file is only written when its content changes.
void replaceProjectName(Directory folder, String projectName) {
  for (final entity in folder.listSync(recursive: true)) {
    if (entity is! File || entity.path.contains('bin/dox')) continue;
    String content;
    try {
      content = utf8.decode(entity.readAsBytesSync());
    } on FormatException {
      continue;
    }
    String replaced = content.replaceAll('dox_sample', projectName);
    if (replaced != content) entity.writeAsStringSync(replaced);
  }
}

/// The newest dox-sample release with the same major version as this CLI.
///
/// GitHub's `releases/latest` skips pre-releases, so during an alpha it
/// would give the old 2.x template. This reads the release list instead.
String? _latestTemplate() {
  ProcessResult result = Process.runSync('curl', [
    'https://api.github.com/repos/dartondox/dox-sample/releases?per_page=100',
    '-s',
  ]);
  if (result.exitCode != 0) return null;
  List<String> tags = <String>[];
  try {
    List<dynamic> releases = jsonDecode(result.stdout);
    for (final release in releases) {
      tags.add((release['tag_name'] as String).replaceFirst('v', ''));
    }
  } catch (_) {
    return null;
  }
  return newestOfMajor(tags, version);
}
