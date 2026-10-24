/// An uploaded file the validator can check.
///
/// dox-core `RequestFile` implements it, so `v.file()` and the DTO file
/// rules (`@MaxSize`, `@Mimes`, `@Image`) can read it.
abstract class FileInput {
  /// File extension from the file name, without the dot, like `png`.
  String get extension;

  /// Size in bytes.
  int get length;

  /// The first bytes of the file (up to [FileTypes.headSize]).
  /// The real file type comes from them.
  List<int> get head;
}

/// Finds the real type of a file from its first bytes ("magic bytes").
///
/// The file name and the content type from the client are not trusted.
/// The file name extension must not be another known type or a type a
/// browser runs, so `x.html` with GIF bytes is not a `gif`. An empty or
/// unknown extension (like a `blob` upload) is fine when the bytes match. A type without a byte signature (like `txt` or
/// `csv`) is matched by the file name extension only.
class FileTypes {
  const FileTypes._();

  /// How many first bytes a [FileInput] must keep in [FileInput.head].
  static const int headSize = 32;

  /// Extension => the byte format it uses.
  static const Map<String, String> _formats = <String, String>{
    'jpg': 'jpg',
    'jpeg': 'jpg',
    'png': 'png',
    'gif': 'gif',
    'webp': 'webp',
    'bmp': 'bmp',
    'tif': 'tiff',
    'tiff': 'tiff',
    'ico': 'ico',
    'psd': 'psd',
    'pdf': 'pdf',
    'mp3': 'mp3',
    'wav': 'wav',
    'avi': 'avi',
    'ogg': 'ogg',
    'flac': 'flac',
    'woff': 'woff',
    'woff2': 'woff2',
    'wasm': 'wasm',
    '7z': '7z',
    'rar': 'rar',
    // containers: the bytes are shared, so the file name must match too
    'zip': 'zip',
    'docx': 'zip',
    'xlsx': 'zip',
    'pptx': 'zip',
    'odt': 'zip',
    'ods': 'zip',
    'odp': 'zip',
    'epub': 'zip',
    'jar': 'zip',
    'apk': 'zip',
    'doc': 'ole',
    'xls': 'ole',
    'ppt': 'ole',
    'msg': 'ole',
    'mp4': 'ftyp',
    'm4a': 'ftyp',
    'm4v': 'ftyp',
    'mov': 'ftyp',
    'heic': 'ftyp',
    'heif': 'ftyp',
    'avif': 'ftyp',
    '3gp': 'ftyp',
    'webm': 'mkv',
    'mkv': 'mkv',
    'gz': 'gz',
    'tgz': 'gz',
  };

  /// Byte formats used by more than one file type.
  static const Set<String> _containers = <String>{
    'zip',
    'ole',
    'ftyp',
    'mkv',
    'gz',
  };

  /// `true` when [file] is one of [types] (file extensions, like `pdf`).
  static bool matches(FileInput file, List<String> types) {
    String? found = sniff(file.head);
    String name = file.extension.toLowerCase();
    for (String type in types) {
      String ext = type.toLowerCase();
      String? format = _formats[ext];
      if (format == null) {
        // no byte signature: trust the name, but only for non-binary bytes
        if (found == null && name == ext) return true;
      } else if (format == found && _nameFits(name, format)) {
        if (!_containers.contains(format) || name == ext) return true;
      }
    }
    return false;
  }

  /// Extensions a browser may run as a page or script.
  static const Set<String> _active = <String>{
    'html',
    'htm',
    'xhtml',
    'svg',
    'xml',
    'js',
    'mjs',
  };

  /// `false` when the client extension [name] is another known format, or
  /// a type a browser runs, so `x.html` with GIF bytes does not pass as
  /// `gif`. An empty or unknown extension is fine: browsers name canvas
  /// and fetch uploads `blob`.
  static bool _nameFits(String name, String format) {
    String? named = _formats[name];
    if (named != null) return named == format;
    return !_active.contains(name);
  }

  /// The byte format of [head], like `png` or `zip`. `null` when unknown.
  static String? sniff(List<int> head) {
    if (_starts(head, const <int>[0xFF, 0xD8, 0xFF])) return 'jpg';
    if (_starts(head, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) {
      return 'png';
    }
    if (_ascii(head, 0, 'GIF87a') || _ascii(head, 0, 'GIF89a')) return 'gif';
    if (_ascii(head, 0, 'RIFF')) {
      if (_ascii(head, 8, 'WEBP')) return 'webp';
      if (_ascii(head, 8, 'WAVE')) return 'wav';
      if (_ascii(head, 8, 'AVI ')) return 'avi';
      return null;
    }
    if (_ascii(head, 0, 'BM') && head.length >= 14) return 'bmp';
    if (_ascii(head, 0, '%PDF-')) return 'pdf';
    if (_starts(head, const <int>[0x50, 0x4B, 0x03, 0x04]) ||
        _starts(head, const <int>[0x50, 0x4B, 0x05, 0x06])) {
      return 'zip';
    }
    if (_starts(head, const <int>[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1])) {
      return 'ole';
    }
    if (_starts(head, const <int>[0x49, 0x49, 0x2A, 0x00]) ||
        _starts(head, const <int>[0x4D, 0x4D, 0x00, 0x2A])) {
      return 'tiff';
    }
    if (_starts(head, const <int>[0x00, 0x00, 0x01, 0x00])) return 'ico';
    if (_ascii(head, 0, '8BPS')) return 'psd';
    if (_ascii(head, 4, 'ftyp')) return 'ftyp';
    if (_ascii(head, 0, 'ID3') ||
        _starts(head, const <int>[0xFF, 0xFB]) ||
        _starts(head, const <int>[0xFF, 0xF3]) ||
        _starts(head, const <int>[0xFF, 0xF2])) {
      return 'mp3';
    }
    if (_ascii(head, 0, 'OggS')) return 'ogg';
    if (_ascii(head, 0, 'fLaC')) return 'flac';
    if (_starts(head, const <int>[0x1A, 0x45, 0xDF, 0xA3])) return 'mkv';
    if (_starts(head, const <int>[0x1F, 0x8B])) return 'gz';
    if (_starts(head, const <int>[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
      return '7z';
    }
    if (_ascii(head, 0, 'Rar!')) return 'rar';
    if (_ascii(head, 0, 'wOFF')) return 'woff';
    if (_ascii(head, 0, 'wOF2')) return 'woff2';
    if (_starts(head, const <int>[0x00, 0x61, 0x73, 0x6D])) return 'wasm';
    return null;
  }

  static bool _starts(List<int> head, List<int> bytes) {
    if (head.length < bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (head[i] != bytes[i]) return false;
    }
    return true;
  }

  static bool _ascii(List<int> head, int at, String text) {
    if (head.length < at + text.length) return false;
    for (int i = 0; i < text.length; i++) {
      if (head[at + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }
}
