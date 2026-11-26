import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/request/upload_temp_files.dart';
import 'package:mime/mime.dart';
import 'package:string_scanner/string_scanner.dart';

/// files up to this size stay in memory, bigger ones go to a temp file.
const int multipartMemoryLimit = 1024 * 1024;

/// how many first bytes of a file on disk stay in memory as
/// `RequestFile.head`. The file type is in the first 32 bytes, but a JPEG
/// keeps its image size after the photo metadata (EXIF, up to 64 KB),
/// and `@Dimensions` needs it.
const int fileHeadSize = 128 * 1024;

class FormDataVisitor {
  final HttpRequest request;

  /// request body, already wrapped with the size limit
  final Stream<List<int>> body;

  static final RegExp _token = RegExp(
    r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+',
  );
  static final RegExp _whitespace = RegExp(r'(?:(?:\r\n)?[ \t]+)*');

  /// a backslash only matches the `\\.` branch. when both branches can
  /// take it, a long run of backslashes backtracks for hours (ReDoS).
  static final RegExp _quotedString = RegExp(r'"(?:[^"\\\x00-\x1F\x7F]|\\.)*"');
  static final RegExp _quotedPair = RegExp(r'\\(.)');

  final Map<String, dynamic> inputs = <String, dynamic>{};

  /// every part in order, also repeated keys (a DTO reads these)
  final List<MapEntry<String, Object>> parts = <MapEntry<String, Object>>[];

  /// fails when the body stream fails (eg. 413). the mime parser only
  /// reports body errors on the outer stream, never on the open part,
  /// so a part reader must also watch this or it waits forever.
  /// made in the zone of [process]: an error of a future does not pass
  /// to a listener in another error zone.
  late final Completer<bool> _failed;

  /// the multipart boundary. read from the request when null.
  final String? boundary;

  FormDataVisitor(this.request, this.body, {this.boundary});

  /// read the parts one by one. a part must be fully read before the
  /// next one arrives, so the whole body is never held in memory.
  /// A body that is not valid multipart throws a [BadRequestException].
  Future<void> process() async {
    String? separator =
        boundary ?? request.headers.contentType?.parameters['boundary'];
    if (separator == null || separator.isEmpty) {
      throw BadRequestException(message: 'Multipart body has no boundary');
    }

    /// The mime parser throws some errors (eg. a space in a header name)
    /// in its stream callback. No `await` gets such an error: it goes to
    /// the zone, and the parser stops, so the request would wait for
    /// ever. This zone gets the error and fails the body with it, which
    /// ends the open reads. The completer `done` is made outside the
    /// zone, because an error of a future does not leave an error zone.
    Completer<void> done = Completer<void>();
    runZonedGuarded(
      () {
        _failed = Completer<bool>()..future.ignore();
        _process(separator).then(
          done.complete,
          onError: (Object error, StackTrace stackTrace) {
            done.completeError(_badBody(error), stackTrace);
          },
        );
      },
      (Object error, StackTrace stackTrace) {
        if (!_failed.isCompleted) {
          _failed.completeError(_badBody(error), stackTrace);
        }
      },
    );
    return done.future;
  }

  /// an error of the mime parser is the fault of the client: a 400.
  /// A `FormatException` is a part header that is not UTF-8.
  static Object _badBody(Object error) {
    if (error is MimeMultipartException || error is FormatException) {
      return BadRequestException(message: 'Multipart body is not valid');
    }
    return error;
  }

  Future<void> _process(String separator) async {
    MimeMultipartTransformer transformer = MimeMultipartTransformer(separator);
    _closing = utf8.encode('\r\n--$separator--');

    await for (MimeMultipart formItem in _guard<MimeMultipart>(
      _watch(body).transform(transformer),
    )) {
      String? partHeaders = formItem.headers['content-disposition'];
      if (partHeaders == null) {
        throw BadRequestException(
          message: 'Multipart part has no Content-Disposition',
        );
      }
      String? contentType = formItem.headers['content-type'];

      Map<String, String> data;
      try {
        data = _parseFormDataContentDisposition(partHeaders);
      } on FormatException {
        throw BadRequestException(
          message: 'Multipart part has a bad Content-Disposition',
        );
      }

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
  /// the temp file is deleted when the request is handled (see
  /// `releaseTempFiles`).
  Future<RequestFile> _readFile(
    MimeMultipart part,
    String filename,
    String filetype,
  ) async {
    BytesBuilder buffer = BytesBuilder(copy: false);
    RandomAccessFile? raf;
    File? temp;
    int length = 0;
    Uint8List? head;
    try {
      await for (List<int> chunk in _guard(part)) {
        length += chunk.length;
        if (raf == null && length > multipartMemoryLimit) {
          temp = File(
            '${Directory.systemTemp.path}/dox-upload-${uuid.v4()}.tmp',
          );
          keepTempFile(request, temp);
          raf = await temp.open(mode: FileMode.write);
          Uint8List first = buffer.takeBytes();
          head = _headOf(first, chunk);
          await raf.writeFrom(first);
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

  /// a copy of the first [fileHeadSize] bytes of [first], then [chunk].
  /// a copy, so the 1 MB [first] buffer is not kept alive.
  static Uint8List _headOf(Uint8List first, List<int> chunk) {
    BytesBuilder out = BytesBuilder();
    out.add(
      first.length > fileHeadSize
          ? Uint8List.sublistView(first, 0, fileHeadSize)
          : first,
    );
    int take = fileHeadSize - out.length;
    if (take > 0) out.add(chunk.length > take ? chunk.sublist(0, take) : chunk);
    return out.takeBytes();
  }

  /// `CRLF--boundary--`, the end mark of the body. The parser takes it as
  /// the end only after a line break (or at the start of the body).
  List<int> _closing = const <int>[];

  /// pass the body through up to the end mark, and mark [_failed] when it
  /// fails. A body that ends with no closing boundary (a cut upload) also
  /// fails: the mime parser reports it on the outer stream only, so a
  /// reader that waits for the open part would wait for ever.
  ///
  /// The bytes after the end mark (the epilogue) are read, so the size
  /// limit still counts them, but the parser does not get them. When a
  /// body has no parts, the parser stops at the first byte after the end
  /// mark and never ends, so the request would wait for ever.
  Stream<List<int>> _watch(Stream<List<int>> source) async* {
    /// the end mark can be split between two chunks, so the last bytes of
    /// the chunk before are kept.

    /// the body start counts as after a line break
    List<int> carry = const <int>[0x0D, 0x0A];
    bool closed = false;
    try {
      /// `await for`, not `yield*`: yield* forwards errors without throwing
      await for (List<int> chunk in source) {
        if (closed) continue;
        int end = _closingEnd(carry, chunk);
        if (end < 0) {
          carry = _lastOf(carry, chunk);
          yield chunk;
          continue;
        }
        closed = true;
        if (end > 0) yield chunk.sublist(0, end);

        /// the line break that ends the mark, for the parser
        yield const <int>[0x0D, 0x0A];
      }
      if (!closed && !_failed.isCompleted) {
        _failed.completeError(
          BadRequestException(message: 'Multipart body is cut'),
          StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      if (!_failed.isCompleted) _failed.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// where the end mark ends in [chunk], when [carry] then [chunk] hold
  /// it. -1 when they do not.
  int _closingEnd(List<int> carry, List<int> chunk) {
    List<int> mark = _closing;
    int total = carry.length + chunk.length;
    int first = mark.first;
    int at(int i) => i < carry.length ? carry[i] : chunk[i - carry.length];
    for (int i = 0; i + mark.length <= total; i++) {
      if (at(i) != first) continue;
      int j = 1;
      while (j < mark.length && at(i + j) == mark[j]) {
        j++;
      }
      if (j == mark.length) return i + mark.length - carry.length;
    }
    return -1;
  }

  /// the last `mark.length - 1` bytes of [carry] then [chunk]
  List<int> _lastOf(List<int> carry, List<int> chunk) {
    int keep = _closing.length - 1;
    if (chunk.length >= keep) return chunk.sublist(chunk.length - keep);
    List<int> all = <int>[...carry, ...chunk];
    return all.length <= keep ? all : all.sublist(all.length - keep);
  }

  /// read a part (or the parts), but stop with the body error if the
  /// body fails. a body error cancels the iterator, which ends a waiting
  /// `moveNext`. so there is no race per chunk.
  Stream<T> _guard<T>(Stream<T> part) async* {
    StreamIterator<T> iterator = StreamIterator<T>(part);
    Object? error;
    StackTrace? stackTrace;
    _failed.future
        .then<void>(
          (_) {},
          onError: (Object e, StackTrace s) {
            error = e;
            stackTrace = s;
            return iterator.cancel();
          },
        )
        .ignore();
    try {
      while (await iterator.moveNext()) {
        yield iterator.current;
      }
    } finally {
      await iterator.cancel();
    }
    if (error != null) Error.throwWithStackTrace(error!, stackTrace!);
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
      /// `expect`, not `scan`: with no name there is no match to read
      scanner
        ..scan(_whitespace)
        ..expect(_token);
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
