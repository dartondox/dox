import 'dart:io';

/// Runs the Node.js interop scripts in `test/interop`.
class NodeRunner {
  NodeRunner() : dir = Directory('test/interop').absolute.path;

  final String dir;

  /// Null when node and npm work, else the reason to skip.
  static String? skipReason() {
    try {
      ProcessResult node = Process.runSync('node', <String>['--version']);
      ProcessResult npm =
          Process.runSync('npm', <String>['--version'], runInShell: true);
      if (node.exitCode != 0 || npm.exitCode != 0) return 'node/npm failed';
      return null;
    } on ProcessException {
      return 'node or npm is not installed';
    }
  }

  /// Installs the npm packages when they are missing.
  Future<void> install() async {
    if (Directory('$dir/node_modules/socket.io-client').existsSync()) return;
    ProcessResult result = await Process.run(
      'npm',
      <String>['ci', '--no-audit', '--no-fund'],
      workingDirectory: dir,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw StateError('npm ci failed:\n${result.stdout}\n${result.stderr}');
    }
  }

  /// Runs `node <script> <args>` and returns the result.
  Future<ProcessResult> run(String script, List<String> args) {
    return Process.run(
      'node',
      <String>[script, ...args],
      workingDirectory: dir,
    ).timeout(const Duration(seconds: 20));
  }

  /// Starts `node <script> <args>` and returns the process.
  Future<Process> start(String script, List<String> args) {
    return Process.start('node', <String>[script, ...args],
        workingDirectory: dir);
  }
}
