import 'dart:convert';
import 'dart:io';

import 'package:dox/dox.dart';
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

  // Replace the project name in all files
  final files = projectFolder.listSync(recursive: true);
  for (final file in files) {
    if (file is File) {
      if (!file.path.contains('bin/dox')) {
        final content = file.readAsStringSync().replaceAll(
          'dox_sample',
          projectName,
        );
        file.writeAsStringSync(content);
      }
    }
  }

  print('\x1B[32m✔\x1B[0m Done. Created at - ${projectFolder.path}');
  print('\x1B[32m✔\x1B[0m Now run:\n');
  print('    ➢ cd $projectName');
  print('    ➢ dart pub get');
  print('    ➢ cp .env.example .env (modify .env variables)');
  print('    ➢ dox serve\n');
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
  String major = version.split('.').first;
  List<String> tags = <String>[];
  try {
    List<dynamic> releases = jsonDecode(result.stdout);
    for (final release in releases) {
      String tag = (release['tag_name'] as String).replaceFirst('v', '');
      if (tag.startsWith('$major.')) tags.add(tag);
    }
  } catch (_) {
    return null;
  }
  if (tags.isEmpty) return null;
  tags.sort(_compareVersions);
  return tags.last;
}

/// Sorts `3.0.0-alpha.2 < 3.0.0-alpha.4 < 3.0.0 < 3.1.0`.
int _compareVersions(String a, String b) {
  List<int> key(String v) {
    List<String> parts = v.split('-');
    List<int> nums = parts.first.split('.').map(int.parse).toList();
    // a stable version ranks above every pre-release of the same base
    if (parts.length == 1) return [...nums, 1, 0];
    Match? n = RegExp(r'\d+$').firstMatch(parts[1]);
    return [...nums, 0, n == null ? 0 : int.parse(n.group(0)!)];
  }

  List<int> ka = key(a), kb = key(b);
  for (int i = 0; i < ka.length && i < kb.length; i++) {
    if (ka[i] != kb[i]) return ka[i].compareTo(kb[i]);
  }
  return ka.length.compareTo(kb.length);
}
