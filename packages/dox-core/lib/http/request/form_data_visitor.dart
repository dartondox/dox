import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:mime/mime.dart';
import 'package:string_scanner/string_scanner.dart';

/// files up to this size stay in memory, bigger ones go to a temp file.
const int multipartMemoryLimit = 1024 * 1024;

class FormDataVisitor {
  final HttpRequest request;

  /// request body, already wrapped with the size limit
  final Stream<List<int>> body;

  final RegExp _token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
  final RegExp _whitespace = RegExp(r'(?:(?:\r\n)?[ \t]+)*');

  /// a backslash only matches the `\\.` branch. when both branches can
  /// take it, a long run of backslashes backtracks for hours (ReDoS).
  final RegExp _quotedString = RegExp(r'"(?:[^"\\\x00-\x1F\x7F]|\\.)*"');
  final RegExp _quotedPair = RegExp(r'\\(.)');

  final Map<String, dynamic> inputs = <String, dynamic>{};

  /// every part in order, also repeated keys (a DTO reads these)
  final List<MapEntry<String, Object>> parts = <MapEntry<String, Object>>[];

  /// fails when the body stream fails (eg. 413). the mime parser only
  /// reports body errors on the outer stream, never on the open part,
  /// so a part reader must also watch this or it waits forever.
  final Completer<bool> _failed = Completer<bool>();

  FormDataVisitor(this.request, this.body) {
    _failed.future.ignore();
  }

  /// read the parts one by one. a part must be fully read before the
  /// next one arrives, so the whole body is never held in memory.
  Future<void> process() async {
    MimeMultipartTransformer transformer = MimeMultipartTransformer(
      request.headers.contentType!.parameters['boundary']!,
    );

    await for (MimeMultipart formItem in _watch(body).transform(transformer)) {
      String partHeaders = formItem.headers['content-disposition']!;
      String? contentType = formItem.headers['content-type'];

      Map<String, String> data = _parseFormDataContentDisposition(partHeaders);

      String? inputName = data['name'];
      if (inputName != null) {
        Object value;
        if (data['filename'] == null || data['filename']!.isEmpty) {
          value = await _utf8.bind(_guard(formItem)).join();
        } else {
          value = await _readFile(
            formItem,
            data['filename'].toString(),
            contentType.toString(),
          );
        }
        inputs[inputName] = value;
        parts.add(MapEntry<String, Object>(inputName, value));
      } else {
        await _guard(formItem).drain<void>();
      }
    }
  }

  /// keep small files in memory. once a file passes
  /// [multipartMemoryLimit], write it to a temp file instead.
  /// the temp file is deleted when the response is done.
  Future<RequestFile> _readFile(
    MimeMultipart part,
    String filename,
    String filetype,
  ) async {
    BytesBuilder buffer = BytesBuilder(copy: false);
    RandomAccessFile? raf;
    File? temp;
    int length = 0;
    List<int> head = <int>[];
    try {
      await for (List<int> chunk in _guard(part)) {
        if (head.length < FileTypes.headSize) {
          int take = FileTypes.headSize - head.length;
          head.addAll(chunk.length > take ? chunk.sublist(0, take) : chunk);
        }
        length += chunk.length;
        if (raf == null && length > multipartMemoryLimit) {
          temp = File(
            '${Directory.systemTemp.path}/dox-upload-${uuid.v4()}.tmp',
          );
          _deleteWhenDone(temp);
          raf = await temp.open(mode: FileMode.write);
          await raf.writeFrom(buffer.takeBytes());
        }
        if (raf != null) {
          /// awaiting each write pauses the socket when the disk is slow
          await raf.writeFrom(chunk);
        } else {
          buffer.add(chunk);
        }
      }
    } finally {
      await raf?.close();
    }
    return RequestFile(
      filename: filename,
      filetype: filetype,
      length: length,
      bytes: temp == null ? buffer.takeBytes() : null,
      file: temp,
      head: head,
    );
  }

  /// pass the body through, and mark [_failed] when it fails
  Stream<List<int>> _watch(Stream<List<int>> source) async* {
    try {
      /// `await for`, not `yield*`: yield* forwards errors without throwing
      await for (List<int> chunk in source) {
        yield chunk;
      }
    } catch (error, stackTrace) {
      if (!_failed.isCompleted) _failed.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// read a part, but stop with the body error if the body fails
  Stream<List<int>> _guard(Stream<List<int>> part) async* {
    StreamIterator<List<int>> iterator = StreamIterator<List<int>>(part);
    try {
      while (await Future.any(<Future<bool>>[
        iterator.moveNext(),
        _failed.future,
      ])) {
        yield iterator.current;
      }
    } finally {
      await iterator.cancel();
    }
  }

  void _deleteWhenDone(File file) {
    request.response.done.whenComplete(() => _delete(file)).ignore();
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } catch (_) {
      /// already moved by `store()`/`moveTo()`, or already gone
    }
  }

  static const Utf8Decoder _utf8 = Utf8Decoder(allowMalformed: true);

  /// reference from `shelf_multipart` package
  /// https://pub.dev/packages/shelf_multipart
  Map<String, String> _parseFormDataContentDisposition(String header) {
    StringScanner scanner = StringScanner(header);
    scanner
      ..scan(_whitespace)
      ..expect(_token);

    Map<String, String> params = <String, String>{};

    while (scanner.scan(';')) {
      scanner
        ..scan(_whitespace)
        ..scan(_token);
      String key = scanner.lastMatch![0]!;
      scanner.expect('=');

      String value;
      if (scanner.scan(_token)) {
        value = scanner.lastMatch![0]!;
      } else {
        scanner.expect(_quotedString, name: 'quoted string');
        String string = scanner.lastMatch![0]!;

        value = string
            .substring(1, string.length - 1)
            .replaceAllMapped(_quotedPair, (Match match) => match[1]!);
      }

      scanner.scan(_whitespace);
      params[key] = value;
    }

    scanner.expectDone();
    return params;
  }
}
