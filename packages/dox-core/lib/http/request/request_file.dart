import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/extensions/num.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

final Uuid uuid = Uuid();

/// An uploaded file from a multipart/form-data request.
///
/// Small files (up to 1 MB) are kept in memory. Bigger files are streamed
/// to a temp file while the request is read, so a big upload does not
/// fill the RAM. The temp file is deleted when the response is done, so
/// call [store] or [moveTo] before you return from the controller.
class RequestFile implements FileInput {
  final String filename;
  final String filetype;

  /// size of the file in bytes
  final int length;

  Uint8List? _bytes;
  File? _file;

  /// true while [_file] is our own temp file, which we may move
  bool _isTemp;

  RequestFile({
    required this.filename,
    required this.filetype,
    required this.length,
    this._bytes,
    File? file,
  }) : _file = file,
       _isTemp = file != null;

  /// Get file extension
  /// eg. png, jpeg, pdf
  @override
  String get extension =>
      path.extension(filename).toLowerCase().replaceFirst('.', '');

  /// the file on disk, or null when the file is kept in memory
  File? get file => _file;

  /// get file content in bytes.
  /// for a big file this reads the whole file into memory,
  /// so prefer [stream], [store] or [moveTo] for big files.
  /// ```
  /// await file.bytes
  /// ```
  Future<Uint8List> get bytes async {
    return _bytes ??= await _file!.readAsBytes();
  }

  /// read the file content as a stream, without loading it all in memory
  /// ```
  /// await for (List<int> chunk in file.stream()) {}
  /// ```
  Stream<List<int>> stream() {
    Uint8List? memory = _bytes;
    if (memory != null) return Stream<List<int>>.value(memory);
    return _file!.openRead();
  }

  /// get file size in kilobytes
  /// ```
  /// await file.size
  /// ```
  Future<num> get size async {
    return (length / 1024).toFixed(2);
  }

  /// move the file to [destination] and return the new file.
  /// the first move of a temp file is a cheap rename,
  /// later calls copy, so the file can be stored in many places.
  /// ```
  /// File saved = await file.moveTo('/data/avatars/1.png');
  /// ```
  Future<File> moveTo(String destination) async {
    File target = File(destination);
    await target.parent.create(recursive: true);
    Uint8List? memory = _bytes;
    if (memory != null) {
      return target.writeAsBytes(memory);
    }
    File source = _file!;
    if (!_isTemp) return source.copy(destination);
    try {
      _file = await source.rename(destination);
    } on FileSystemException {
      /// rename does not work across disks (eg. /tmp and a docker volume)
      _file = await source.copy(destination);
      await source.delete();
    }
    _isTemp = false;
    return _file!;
  }

  /// this function will store the file in your project storage folder
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.store();
  /// ```
  Future<String> store(String folder) async {
    return Storage().putRequestFile(folder, this);
  }
}
