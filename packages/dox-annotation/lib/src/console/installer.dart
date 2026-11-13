import 'dart:io';

/// Runs a program in the app folder, with its output on this terminal.
/// Tests pass a fake one to [Installer].
class ProcessRunner {
  /// run [executable] with [args] in [folder] and return its exit code
  Future<int> run(String executable, List<String> args, String folder) async {
    Process process = await Process.start(
      executable,
      args,
      workingDirectory: folder,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

/// The steps of a `<package>:install` command, so `dox add <package>`
/// sets up the app.
///
/// Every step is safe to run twice: it never overwrites a file and never
/// adds a key twice. Each step adds one line to the summary that
/// [printSummary] prints at the end.
///
/// ```dart
/// Installer installer = Installer();
/// await installer.addDependency('dox_migration');
/// installer.writeFile('lib/config/database.dart', source);
/// installer.addEnv('DB_CONNECTION', 'sqlite');
/// await installer.buildRunner();
/// installer.printSummary(<String>['Run `dox migrate`.']);
/// ```
class Installer {
  /// [root] is the app folder, the current folder by default
  Installer({Directory? root, ProcessRunner? runner})
    : root = (root ?? Directory.current).absolute,
      _runner = runner ?? ProcessRunner();

  final Directory root;
  final ProcessRunner _runner;

  /// one line per step, for [printSummary]
  final List<String> lines = <String>[];

  /// false when a step failed (a `dart` command or a missing file)
  bool ok = true;

  File _file(String path) => File('${root.path}/$path');

  /// the `name:` of the app pubspec.yaml, for `package:<app>/...` imports
  String get appName {
    RegExpMatch? match = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(_file('pubspec.yaml').readAsStringSync());
    if (match == null) throw StateError('pubspec.yaml has no name.');
    return match.group(1)!;
  }

  /// write [content] to [path] (relative to the app folder) only when the
  /// file is not there. Returns true when the file was made.
  bool writeFile(String path, String content) {
    File file = _file(path);
    if (file.existsSync()) {
      lines.add('skipped  $path (already there)');
      return false;
    }
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
    lines.add('created  $path');
    return true;
  }

  /// make the folder [path] when it is not there
  void makeFolder(String path) {
    Directory folder = Directory('${root.path}/$path');
    if (folder.existsSync()) return;
    folder.createSync(recursive: true);
    lines.add('created  $path/');
  }

  /// add `KEY=value` to `.env.example` and `.env` when the key is not in
  /// the file. A file that is not there is skipped.
  void addEnv(String key, String value) {
    for (String name in <String>['.env.example', '.env']) {
      File file = _file(name);
      if (!file.existsSync()) continue;
      String text = file.readAsStringSync();
      if (RegExp(
        '^\\s*(export\\s+)?$key\\s*=',
        multiLine: true,
      ).hasMatch(text)) {
        continue;
      }
      if (text.isNotEmpty && !text.endsWith('\n')) text = '$text\n';
      file.writeAsStringSync('$text$key=$value\n');
      lines.add('added    $key to $name');
    }
  }

  /// add [getter] (like `String get dbName => 'db/dox.sqlite';`) to the
  /// `AppEnv` class of `lib/config/env.dart`, when a getter with the same
  /// name is not there. Run [buildRunner] after it.
  void addEnvGetter(String getter) {
    String path = 'lib/config/env.dart';
    String name = RegExp(r'get\s+(\w+)').firstMatch(getter)!.group(1)!;
    File file = _file(path);
    String text = file.existsSync() ? file.readAsStringSync() : '';
    int start = text.indexOf('abstract class AppEnv');

    /// `dart format` puts the closing `}` of a class alone at the start
    /// of a line
    int end = start == -1 ? -1 : text.indexOf('\n}', start);
    if (end == -1) {
      lines.add('skipped  $name: add `$getter` to AppEnv in $path');
      ok = false;
      return;
    }
    if (RegExp('get\\s+$name\\b').hasMatch(text.substring(start, end))) return;
    file.writeAsStringSync(
      '${text.substring(0, end)}\n\n  $getter${text.substring(end)}',
    );
    lines.add('added    $name to AppEnv in $path');
  }

  /// true when [package] is in `dependencies` or `dev_dependencies` of
  /// the app pubspec.yaml
  bool hasDependency(String package) {
    String section = '';
    for (String line in _file('pubspec.yaml').readAsLinesSync()) {
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        section = line.split(':').first.trim();
      } else if ((section == 'dependencies' || section == 'dev_dependencies') &&
          RegExp('^\\s+$package\\s*:').hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  /// `dart pub add [--dev] <package>` when the app does not have it yet
  Future<bool> addDependency(String package, {bool dev = false}) async {
    if (hasDependency(package)) return true;
    bool done = await _dart(<String>['pub', 'add', if (dev) '--dev', package]);
    lines.add(
      done
          ? 'added    $package${dev ? ' (dev)' : ''}'
          : 'failed   dart pub add $package',
    );
    return done;
  }

  /// `dart run build_runner build`, to make the generated files again
  Future<bool> buildRunner() async {
    bool done = await _dart(<String>['run', 'build_runner', 'build']);
    lines.add(done ? 'ran      build_runner' : 'failed   build_runner');
    return done;
  }

  /// print what was done and the [nextSteps]. Sets exit code 1 when a
  /// step failed.
  void printSummary(List<String> nextSteps) {
    print('');
    for (String line in lines) {
      print('  $line');
    }
    if (!ok) {
      print('\n\x1B[31mSome steps failed. See the output above.\x1B[0m');
      exitCode = 1;
    }
    if (nextSteps.isEmpty) return;
    print('\nNext steps:');
    for (String step in nextSteps) {
      print('  - $step');
    }
  }

  Future<bool> _dart(List<String> args) async {
    int code = await _runner.run(_dartExecutable(), args, root.path);
    if (code != 0) ok = false;
    return code == 0;
  }

  /// the `dart` that runs this command, or `dart` from PATH when it runs
  /// as an AOT snapshot
  String _dartExecutable() {
    String exe = Platform.resolvedExecutable;
    return exe.split(Platform.pathSeparator).last.startsWith('dart')
        ? exe
        : 'dart';
  }
}
