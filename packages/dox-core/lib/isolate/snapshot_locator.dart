import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the file that `Isolate.spawnUri` can start, so a server isolate
/// can get its own isolate group (`CoreFlags.isolateGroups`).
///
/// It tries, in this order:
/// 1. Linux: the library of a `dart build cli` bundle,
///    `<dir of the executable>/../lib/libdartaot<name of the executable>.so`
/// 2. `<executable>.aot`, a file made with `dart compile aot-snapshot`
/// 3. the script that runs now, when it is a file (`dart run`, JIT)
///
/// The executable itself is never a candidate. On macOS `spawnUri` on it
/// crashes the VM, and the crash can not be caught.
class SnapshotLocator {
  SnapshotLocator({String? executable, Uri? script, bool? isLinux})
    : executable = executable ?? Platform.resolvedExecutable,
      script = script ?? Platform.script,
      isLinux = isLinux ?? Platform.isLinux;

  final String executable;
  final Uri script;
  final bool isLinux;

  /// the file to start, or null when there is none
  Uri? find() {
    String self = _real(executable);
    for (String path in candidates()) {
      if (!File(path).existsSync()) continue;
      // also when one of the two is a link to the other
      if (p.equals(_real(path), self)) continue;
      return Uri.file(path);
    }
    return null;
  }

  /// [path] with every link followed, or [path] when it does not exist
  static String _real(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }

  /// the kinds of file the VM can start as a script. An executable from
  /// `dart compile exe` is its own script, and it has none of these.
  static const Set<String> scriptKinds = <String>{
    '.dart',
    '.dill',
    '.aot',
    '.jit',
    '.snapshot',
  };

  /// the paths to try, in order, with no check
  List<String> candidates() {
    return <String>[
      if (isLinux)
        p.normalize(
          p.join(
            p.dirname(executable),
            '..',
            'lib',
            'libdartaot${p.basename(executable)}.so',
          ),
        ),
      '$executable.aot',
      if (script.scheme == 'file' &&
          scriptKinds.contains(p.extension(script.path).toLowerCase()))
        script.toFilePath(),
    ];
  }
}
