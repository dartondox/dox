import 'dart:convert';
import 'dart:io';

import 'package:dox/src/utils/versions.dart';
import 'package:dox/src/version.dart';

/// `dox update`: installs the newest CLI with the same major version.
///
/// A plain `dart pub global activate dox` skips pre-releases. During the
/// 3.x alpha it would install the old 2.x CLI. So this reads the version
/// list from pub.dev and asks for that exact version.
Future<void> updateDox() async {
  String? newest = _newestVersion();
  if (newest == null) {
    print(
      '\x1B[31mCould not read the Dox versions from pub.dev. '
      'Check your network and try again.\x1B[0m',
    );
    return;
  }
  Process process = await Process.start('dart', [
    'pub',
    'global',
    'activate',
    'dox',
    newest,
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}

String? _newestVersion() {
  ProcessResult result = Process.runSync('curl', [
    'https://pub.dev/api/packages/dox',
    '-s',
  ]);
  if (result.exitCode != 0) return null;
  try {
    return newestOfMajor(pubVersions(result.stdout as String), version);
  } catch (_) {
    return null;
  }
}

/// the not retracted versions in a pub.dev `api/packages/<name>` answer
List<String> pubVersions(String json) {
  Map<String, dynamic> data = jsonDecode(json) as Map<String, dynamic>;
  return <String>[
    for (dynamic v in data['versions'] as List<dynamic>)
      if (v['retracted'] != true) v['version'] as String,
  ];
}
