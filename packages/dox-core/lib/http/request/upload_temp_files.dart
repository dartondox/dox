import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// the temp files of each request that has big uploads. a request with no
/// upload never gets an entry.
final Expando<List<File>> _temps = Expando<List<File>>();

/// handler Futures that still run after the answer was given (a request
/// timeout). The files stay until they end.
final Expando<List<Future<void>>> _late = Expando<List<Future<void>>>();

/// [work] still runs although the request got its answer (see
/// `RequestTimeout`). The temp files of [req] are kept until it ends. Does
/// nothing for a request with no temp file. A [work] that never ends keeps
/// the files for ever, like a handler that never ends.
void keepTempFilesUntil(HttpRequest req, Future<void> work) {
  if (_temps[req] == null) return;
  (_late[req] ??= <Future<void>>[]).add(work);
}

/// remember a temp file of [req]. it is deleted by [releaseTempFiles].
void keepTempFile(HttpRequest req, File file) {
  (_temps[req] ??= <File>[]).add(file);
}

/// call this when the handler of [req] has ended (or failed). the files are
/// deleted when the response is done and the `AfterResponse` work has run
/// (`AfterResponse` work that never ends keeps them for ever).
/// The response can be done early (the client left), so `done` alone is
/// not a safe time: the handler may still read the files.
/// safe to call many times.
void releaseTempFiles(HttpRequest req) {
  List<File>? files = _temps[req];
  if (files == null) return;
  _temps[req] = null;
  _deleteLater(req, files, _late[req]);
}

Future<void> _deleteLater(
  HttpRequest req,
  List<File> files,
  List<Future<void>>? late,
) async {
  try {
    await req.response.done;
  } catch (_) {
    /// the answer failed (eg. the client left)
  }
  await AfterResponse.flushed();
  if (late != null) {
    for (Future<void> work in late) {
      try {
        await work;
      } catch (_) {
        /// an error of the late handler is not ours
      }
    }
  }
  for (File file in files) {
    try {
      await file.delete();
    } catch (_) {
      /// already moved by `store()`/`moveTo()`, or already gone
    }
  }
}
