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
  final List<String> _lines = <String>[];

  /// the lines that [printSummary] prints, read only. Add one with [note].
  List<String> get lines => List<String>.unmodifiable(_lines);

  /// false when a step failed (a `dart` command or a missing file)
  bool ok = true;

  /// add a line to the summary, for a step that is not in this class.
  /// Start it with `created`, `added`, `skipped` or `failed` and two
  /// spaces, like the other lines.
  void note(String line) => _lines.add(line);

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
      note('skipped  $path (already there)');
      return false;
    }
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
    note('created  $path');
    return true;
  }

  /// make the folder [path] when it is not there
  void makeFolder(String path) {
    Directory folder = Directory('${root.path}/$path');
    if (folder.existsSync()) return;
    folder.createSync(recursive: true);
    note('created  $path/');
  }

  /// add `KEY=value` to `.env.example` and `.env` when the key is not in
  /// the file. A key that is there is never changed. A file that is not
  /// there is skipped.
  void addEnv(String key, String value) {
    List<String> added = <String>[];
    List<String> skipped = <String>[];
    RegExp line = RegExp(
      '^[ \\t]*(export[ \\t]+)?${RegExp.escape(key)}[ \\t]*=',
      multiLine: true,
    );
    for (String name in <String>['.env.example', '.env']) {
      File file = _file(name);
      if (!file.existsSync()) continue;
      String text = file.readAsStringSync();
      if (line.hasMatch(text)) {
        skipped.add(name);
        continue;
      }
      if (text.isNotEmpty && !text.endsWith('\n')) text = '$text\n';
      file.writeAsStringSync('$text$key=$value\n');
      added.add(name);
    }
    if (added.isNotEmpty) note('added    $key to ${added.join(', ')}');
    if (skipped.isNotEmpty) {
      note('skipped  $key in ${skipped.join(', ')} (already there)');
    }
    if (added.isEmpty && skipped.isEmpty) {
      note('skipped  $key: there is no .env or .env.example');
    }
  }

  /// add [getter] (like `String get dbName => 'db/dox.sqlite';`, with
  /// optional `///` lines above it) to the `AppEnv` class of
  /// `lib/config/env.dart`, when the class has no member with the same
  /// name. Run [buildRunner] after it.
  ///
  /// When the file or the class is not found, or its braces do not
  /// match, it changes nothing, adds a hint to the summary and sets [ok]
  /// to false.
  void addEnvGetter(String getter) {
    String path = 'lib/config/env.dart';
    RegExpMatch? named = RegExp(r'\bget\s+(\w+)\s*(=>|;)').firstMatch(getter);
    if (named == null) throw ArgumentError('Not a getter: $getter');
    String name = named.group(1)!;
    File file = _file(path);
    String text = file.existsSync() ? file.readAsStringSync() : '';
    RegExpMatch? head = RegExp(
      r'^abstract\s+class\s+AppEnv\b[^{;]*\{',
      multiLine: true,
    ).firstMatch(text);
    int end = head == null ? -1 : _closingBrace(text, head.end);
    if (end == -1) {
      note(
        'failed   $name: add `${getter.split('\n').last.trim()}` to AppEnv in $path',
      );
      ok = false;
      return;
    }
    String body = text.substring(head!.end, end);
    if (RegExp('\\b$name\\b').hasMatch(body)) {
      note('skipped  $name in AppEnv (already there)');
      return;
    }
    String before = text.substring(0, end).trimRight();
    String gap = before.endsWith('{') ? '\n' : '\n\n';
    file.writeAsStringSync('$before$gap  $getter\n${text.substring(end)}');
    note('added    $name to AppEnv in $path');
  }

  /// the index of the `}` that closes the `{` just before [start], or -1.
  /// Braces in `//` comments and in one-line strings do not count.
  int _closingBrace(String text, int start) {
    int depth = 1;
    for (int i = start; i < text.length; i++) {
      String char = text[i];
      if (char == '/' && i + 1 < text.length && text[i + 1] == '/') {
        int newline = text.indexOf('\n', i);
        if (newline == -1) return -1;
        i = newline;
      } else if (char == "'" || char == '"') {
        int close = i + 1;
        while (close < text.length && text[close] != char) {
          if (text[close] == '\n') return -1;
          if (text[close] == r'\') close++;
          close++;
        }
        i = close;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
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
    note(
      done
          ? 'added    $package${dev ? ' (dev)' : ''}'
          : 'failed   dart pub add $package',
    );
    return done;
  }

  /// `dart run build_runner build`, to make the generated files again
  Future<bool> buildRunner() async {
    bool done = await _dart(<String>['run', 'build_runner', 'build']);
    note(done ? 'ran      build_runner' : 'failed   build_runner');
    return done;
  }

  /// print what was done and the [nextSteps]. Sets exit code 1 when a
  /// step failed.
  void printSummary(List<String> nextSteps) {
    print('');
    for (String line in _lines) {
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
