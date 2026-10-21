import 'dart:io';

/// Makes the typed env class (`lib/config/env.dart`) from `.env.example`.
///
/// - digits give `int` with the example value as default
/// - true/false give `bool` with the example value as default
/// - an empty value gives an optional `String?`
/// - any other value gives a required `String` (no default, so a secret
///   from the example never becomes a default)
/// - `#` comment lines above a key become its doc comment
class EnvScaffold {
  static final RegExp _digits = RegExp(r'^-?\d+$');

  String build(String example) {
    StringBuffer getters = StringBuffer();
    List<String> comments = <String>[];
    for (String line in example.split('\n')) {
      String text = line.trim();
      if (text.isEmpty) {
        comments.clear();
        continue;
      }
      if (text.startsWith('#')) {
        comments.add(text.substring(1).trim());
        continue;
      }
      int equal = text.indexOf('=');
      if (equal < 1) continue;
      String key = text.substring(0, equal).trim();
      String value = _unquote(text.substring(equal + 1).trim());
      getters.writeln();
      for (String comment in comments) {
        getters.writeln('  /// $comment');
      }
      comments.clear();
      String name = camelCase(key);
      if (upperSnake(name) != key) getters.writeln("  @EnvKey('$key')");
      getters.writeln('  ${_getter(name, value)}');
    }

    return '''
import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

/// The env of the app, typed. Made by `dox env:generate`.
/// -------------------------------
/// Each getter reads one key: `appName` reads `APP_NAME`.
/// A getter body is the default. A nullable getter is optional.
/// Other getters are required: the app stops at startup when one is missing.
/// Run `dart run build_runner build` after you change this class.
@DoxEnv()
abstract class AppEnv {
  /// reads and checks every key once
  static AppEnv load([EnvReader? reader]) {
    return _\$AppEnv.load(reader);
  }
$getters}

/// The env of the app. Read and checked once, on first use.
final AppEnv env = AppEnv.load();
''';
  }

  String _getter(String name, String value) {
    if (value.isEmpty) return 'String? get $name;';
    if (_digits.hasMatch(value)) return 'int get $name => $value;';
    String lower = value.toLowerCase();
    if (lower == 'true' || lower == 'false') {
      return 'bool get $name => $lower;';
    }
    return 'String get $name;';
  }

  String _unquote(String value) {
    if (value.length >= 2) {
      String first = value[0];
      if ((first == '"' || first == "'") && value.endsWith(first)) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}

/// `APP_NAME` => `appName`
String camelCase(String key) {
  List<String> words = key.toLowerCase().split('_');
  StringBuffer out = StringBuffer(words.first);
  for (String word in words.skip(1)) {
    if (word.isEmpty) continue;
    out.write(word[0].toUpperCase() + word.substring(1));
  }
  return out.toString();
}

/// `appName` => `APP_NAME`, the same rule as the dox_builder generator
String upperSnake(String name) {
  StringBuffer out = StringBuffer();
  for (int i = 0; i < name.length; i++) {
    String char = name[i];
    if (char != char.toLowerCase() && i > 0) out.write('_');
    out.write(char.toUpperCase());
  }
  return out.toString();
}

/// `dox env:generate`: writes `lib/config/env.dart` from `.env.example`.
/// Gives false (and exit code 1) when the example is missing or the file
/// is already there.
bool envGenerate() {
  String root = Directory.current.path;
  File example = File('$root/.env.example');
  File target = File('$root/lib/config/env.dart');
  if (!example.existsSync()) {
    print('.env.example is missing.');
    exitCode = 1;
    return false;
  }
  if (target.existsSync()) {
    print('lib/config/env.dart is already there. Delete it to make it again.');
    exitCode = 1;
    return false;
  }
  target.createSync(recursive: true);
  target.writeAsStringSync(EnvScaffold().build(example.readAsStringSync()));
  print(
    '\x1B[32mlib/config/env.dart created.\x1B[0m '
    'Run `dart run build_runner build` to make env.g.dart.',
  );
  return true;
}

/// `dox env:check`: loads `AppEnv` from `lib/config/env.dart` with the
/// current env and `.env`. Prints every missing or bad key (exit code 1).
Future<void> envCheck() async {
  String root = Directory.current.path;
  if (!File('$root/lib/config/env.dart').existsSync()) {
    print('lib/config/env.dart is missing. Run `dox env:generate` first.');
    exitCode = 1;
    return;
  }
  RegExpMatch? name = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('$root/pubspec.yaml').readAsStringSync());
  if (name == null) {
    print('pubspec.yaml has no name.');
    exitCode = 1;
    return;
  }
  File script = File('$root/.dart_tool/dox/env_check.dart');
  script.createSync(recursive: true);
  script.writeAsStringSync('''
import 'dart:io';

import 'package:${name.group(1)}/config/env.dart';
import 'package:dox_core/dox_core.dart';

void main() {
  try {
    AppEnv.load();
    print('The env is valid.');
  } on EnvException catch (e) {
    print(e);
    exitCode = 1;
  }
}
''');
  String exe = Platform.resolvedExecutable;
  String dart = exe.split(Platform.pathSeparator).last.startsWith('dart')
      ? exe
      : 'dart';
  Process process = await Process.start(dart, <String>[
    'run',
    script.path,
  ], mode: ProcessStartMode.inheritStdio);
  int code = await process.exitCode;
  if (code != 0) exitCode = code;
}
