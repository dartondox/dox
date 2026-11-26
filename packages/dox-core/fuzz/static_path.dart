import 'dart:io';

import 'package:dox_core/http/http_static_handler.dart';
import 'package:path/path.dart' as p;

import 'src/fuzz_target.dart';

/// The path of a request for a static file (`Route.staticFiles`).
/// The file must be in the folder, and must not be a hidden file.
class StaticPathTarget extends FuzzTarget {
  StaticPathTarget();

  final StaticFolder folder = StaticFolder('/assets', '/srv/public');

  @override
  String get name => 'static_path';

  @override
  String get library => 'package:dox_core/http/http_static_handler.dart';

  @override
  List<String> get seeds => const <String>[
    'assets/app.js',
    'assets/css/site.css',
    'assets/.well-known/security.txt',
    'assets/a%2Fb.txt',
    'assets/..%2F..%2Fetc/passwd',
    'assets/img/.env',
  ];

  @override
  void check(String input) {
    Uri? uri = Uri.tryParse('http://localhost/$input');
    if (uri == null) return;
    List<String> segments;
    try {
      segments = uri.pathSegments;
    } on FormatException {
      return;
    } on ArgumentError {
      return;
    }
    File? file = folder.fileFor(segments);
    if (file == null) return;
    String path = p.normalize(file.path);
    if (!p.isWithin(folder.root, path)) {
      throw StateError('outside the folder: ${file.path}');
    }
    List<String> parts = p.split(p.relative(path, from: folder.root));
    for (int i = 0; i < parts.length; i++) {
      if (i == 0 && parts[i] == '.well-known') continue;
      if (parts[i].startsWith('.')) {
        throw StateError('hidden file: ${file.path}');
      }
    }
  }
}

Future<void> main(List<String> args) => StaticPathTarget().run(args);
