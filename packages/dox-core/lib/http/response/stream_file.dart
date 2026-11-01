import 'dart:convert';
import 'dart:io';

/// A file to send as a stream, from a controller.
/// The body is not loaded into memory.
class StreamFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;
  const StreamFile(this.contentType, this.stream, {this.length});
}

class DownloadableFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;

  String contentDisposition = '';
  DownloadableFile(
    this.contentType,
    this.stream,
    String filename, {
    this.length,
  }) {
    contentDisposition = _attachment(filename);
  }

  /// The Content-Disposition value for [filename].
  /// A plain ASCII name gives `attachment; filename="name"`, as before.
  /// `"` and `\` are escaped, and control characters become `_`, so the
  /// name can not add parameters. A non-ASCII name, like `résumé.pdf`,
  /// gets an ASCII `filename` (`_` for each other letter) and the real
  /// name in an RFC 5987 `filename*`.
  static String _attachment(String filename) {
    StringBuffer ascii = StringBuffer();
    bool nonAscii = false;
    for (int c in filename.runes) {
      if (c > 0x7e) nonAscii = true;
      if (c < 0x20 || c > 0x7e) {
        ascii.write('_');
      } else {
        if (c == 0x22 || c == 0x5c) ascii.write('\\');
        ascii.writeCharCode(c);
      }
    }
    String header = 'attachment; filename="$ascii"';
    if (!nonAscii) return header;
    return "$header; filename*=UTF-8''${_rfc5987(filename)}";
  }

  /// percent-encode all but the `attr-char` of RFC 5987
  static String _rfc5987(String value) {
    StringBuffer out = StringBuffer();
    for (int byte in utf8.encode(value)) {
      if (_attrChar.hasMatch(String.fromCharCode(byte))) {
        out.writeCharCode(byte);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  static final RegExp _attrChar = RegExp(r'^[A-Za-z0-9!#$&+\-.^_`|~]$');
}
