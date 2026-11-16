import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// the temp files of each request that has big uploads. a request with no
/// upload never gets an entry.
final Expando<List<File>> _temps = Expando<List<File>>();

/// remember a temp file of [req]. it is deleted by [releaseTempFiles].
void keepTempFile(HttpRequest req, File file) {
  (_temps[req] ??= <File>[]).add(file);
}

/// call this when the handler of [req] has ended (or failed). the files are
/// deleted when the response is done and the `AfterResponse` work has run.
/// The response can be done early (the client left), so `done` alone is
/// not a safe time: the handler may still read the files.
/// safe to call many times.
void releaseTempFiles(HttpRequest req) {
  List<File>? files = _temps[req];
  if (files == null) return;
  _temps[req] = null;
  _deleteLater(req, files);
}

Future<void> _deleteLater(HttpRequest req, List<File> files) async {
  try {
    await req.response.done;
  } catch (_) {
    /// the answer failed (eg. the client left)
  }
  await AfterResponse.flushed();
  for (File file in files) {
    try {
      await file.delete();
    } catch (_) {
      /// already moved by `store()`/`moveTo()`, or already gone
    }
  }
}
