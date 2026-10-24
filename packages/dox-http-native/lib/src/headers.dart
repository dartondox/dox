import 'dart:io';
import 'dart:typed_data';

/// a header value is ASCII text or tab, like dart:io. The response record
/// is split on `\n`, so a line break in a value would add a header.
String checkHeaderValue(String value) {
  for (int i = 0; i < value.length; i++) {
    int c = value.codeUnitAt(i);
    if ((c < 32 && c != 9) || c > 127) {
      throw FormatException('Invalid HTTP header field value', value, i);
    }
  }
  return value;
}

/// [HttpHeaders] for the native server.
///
/// Request headers are read from the raw bytes from Rust, one name at a
/// time, when the handler asks. Response headers share the server defaults
/// until the first change (copy on write), so a plain response copies
/// nothing.
class NativeHeaders implements HttpHeaders {
  /// Headers of a request, read from [raw] on use. Not mutable.
  /// [raw] is the header block of the request record (see lib.rs).
  NativeHeaders.request(Uint8List raw, {required this._http10})
    : _raw = raw,
      _mutable = false;

  /// Headers of a response. They start as a view of [defaults].
  NativeHeaders.response(NativeHeaders defaults)
    : _raw = null,
      _mutable = true,
      _http10 = false,
      _map = defaults._entries,
      _shared = true;

  /// An empty, mutable set (the server defaults).
  NativeHeaders.empty()
    : _raw = null,
      _mutable = true,
      _http10 = false,
      _map = <String, List<String>>{};

  final Uint8List? _raw;
  final bool _mutable;
  final bool _http10;

  /// null for request headers until a call needs all of them.
  Map<String, List<String>>? _map;
  bool _shared = false;
  int _contentLength = -1;
  bool _chunked = false;

  /// counts changes, so a cache of the encoded bytes knows when it is old
  int version = 0;

  /// a content type set while the headers were still the defaults. They
  /// stay shared: a response with only a new content type (eg. JSON)
  /// copies nothing.
  ContentType? _sharedType;
  String? _sharedTypeText;

  /// request headers: lookups done by scanning the raw bytes
  int _scans = 0;

  /// true while the headers are still the untouched server defaults
  bool get isShared => _shared && _sharedType == null;

  /// the content type, when the headers are the server defaults with only
  /// this content type set. Else null.
  ContentType? get sharedType => _shared ? _sharedType : null;

  Map<String, List<String>> get _entries {
    if (_sharedType != null) _unshare();
    return _map ??= _parse(_raw!);
  }

  // Raw request headers (from Rust): per header u16 name length, u16 value
  // length (little endian), the name (lowercase), the value.

  static Map<String, List<String>> _parse(Uint8List b) {
    Map<String, List<String>> out = <String, List<String>>{};
    int i = 0;
    while (i + 4 <= b.length) {
      int nameEnd = i + 4 + (b[i] | b[i + 1] << 8);
      int end = nameEnd + (b[i + 2] | b[i + 3] << 8);
      String name = String.fromCharCodes(b, i + 4, nameEnd);
      (out[name] ??= <String>[]).add(String.fromCharCodes(b, nameEnd, end));
      i = end;
    }
    return out;
  }

  /// the values of one header. A request reads only that name from the
  /// raw bytes, so a handler that asks for one or two headers parses no more.
  /// The second lookup parses all headers into a map, as most handlers
  /// read a few (host, content type, upgrade).
  List<String>? _get(String name) {
    String? type = _sharedTypeText;
    if (type != null && name == HttpHeaders.contentTypeHeader) {
      return <String>[type];
    }
    Map<String, List<String>>? map = _map;
    if (map != null) return map[name];
    if (++_scans >= 2) return (_map = _parse(_raw!))[name];
    return _scan(_raw!, name);
  }

  static List<String>? _scan(Uint8List b, String name) {
    List<String>? out;
    int len = name.length;
    int i = 0;
    while (i + 4 <= b.length) {
      int nameLen = b[i] | b[i + 1] << 8;
      int nameEnd = i + 4 + nameLen;
      int end = nameEnd + (b[i + 2] | b[i + 3] << 8);
      if (nameLen == len && _startsWith(b, i + 4, name)) {
        (out ??= <String>[]).add(String.fromCharCodes(b, nameEnd, end));
      }
      i = end;
    }
    return out;
  }

  static bool _startsWith(Uint8List b, int at, String name) {
    for (int k = 0; k < name.length; k++) {
      if (b[at + k] != name.codeUnitAt(k)) return false;
    }
    return true;
  }

  Map<String, List<String>> _own() {
    if (!_mutable) throw HttpException('HTTP headers are not mutable');
    version++;
    if (_shared) _unshare();
    return _entries;
  }

  /// Copies the shared defaults, so they can change.
  void _unshare() {
    String? type = _sharedTypeText;
    _sharedType = null;
    _sharedTypeText = null;
    _shared = false;
    _map = <String, List<String>>{
      for (MapEntry<String, List<String>> e in _map!.entries)
        e.key: List<String>.of(e.value),
      if (type != null) HttpHeaders.contentTypeHeader: <String>[type],
    };
  }

  /// every header line, for the response record. content-length and
  /// transfer-encoding are left out: Rust sets them from the body.
  void forEachLine(void Function(String name, String value) write) {
    for (MapEntry<String, List<String>> e in _entries.entries) {
      for (String value in e.value) {
        write(e.key, value);
      }
    }
  }

  @override
  List<String>? operator [](String name) {
    name = name.toLowerCase();
    if (name == HttpHeaders.contentLengthHeader && _mutable) {
      return _contentLength < 0 ? null : <String>['$_contentLength'];
    }
    return _get(name);
  }

  @override
  String? value(String name) {
    List<String>? values = this[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values[0];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    name = _checkName(name.toLowerCase());
    if (_special(name, value)) return;
    Map<String, List<String>> map = _own();
    if (value is Iterable<Object?>) {
      for (Object? v in value) {
        (map[name] ??= <String>[]).add(checkHeaderValue(_text(v)));
      }
    } else {
      (map[name] ??= <String>[]).add(checkHeaderValue(_text(value)));
    }
  }

  /// a name must be a token, like dart:io. Rust reads the record up to `:`.
  static String _checkName(String name) {
    for (int i = 0; i < name.length; i++) {
      int c = name.codeUnitAt(i);
      if (c <= 32 || c >= 127 || _separators.contains(c)) {
        throw FormatException('Invalid HTTP header field name', name, i);
      }
    }
    return name;
  }

  static const Set<int> _separators = <int>{
    34, 40, 41, 44, 47, 58, 59, 60, 61, 62, 63, 64, 91, 92, 93, 123, 125, //
  };

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    name = name.toLowerCase();
    if (_special(name, value)) return;
    _own().remove(name);
    add(name, value);
  }

  /// content-length is kept as a number, like dart:io.
  bool _special(String name, Object value) {
    if (name == HttpHeaders.contentLengthHeader) {
      if (!_mutable) throw HttpException('HTTP headers are not mutable');
      contentLength = value is int ? value : int.parse(_text(value));
      return true;
    }
    return false;
  }

  static String _text(Object? value) {
    if (value is DateTime) return HttpDate.format(value);
    return '$value';
  }

  @override
  void remove(String name, Object value) {
    name = name.toLowerCase();
    if (name == HttpHeaders.contentLengthHeader) {
      contentLength = -1;
      return;
    }
    List<String>? values = _own()[name];
    if (values == null) return;
    values.remove(_text(value));
    if (values.isEmpty) _entries.remove(name);
  }

  @override
  void removeAll(String name) {
    name = name.toLowerCase();
    if (name == HttpHeaders.contentLengthHeader) {
      contentLength = -1;
      return;
    }
    _own().remove(name);
  }

  @override
  void clear() {
    _own().clear();
    _contentLength = -1;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _entries.forEach(action);
    if (_mutable && _contentLength >= 0) {
      action(HttpHeaders.contentLengthHeader, <String>['$_contentLength']);
    }
  }

  @override
  void noFolding(String name) {}

  @override
  int get contentLength {
    if (_mutable) return _contentLength;
    String? v = value(HttpHeaders.contentLengthHeader);
    return v == null ? -1 : int.tryParse(v) ?? -1;
  }

  @override
  set contentLength(int length) {
    if (!_mutable) throw HttpException('HTTP headers are not mutable');
    _contentLength = length;
  }

  ContentType? _contentType;
  String? _contentTypeOf;

  @override
  ContentType? get contentType {
    String? v = value(HttpHeaders.contentTypeHeader);
    if (v == null) return null;
    if (v != _contentTypeOf) {
      _contentType = ContentType.parse(v);
      _contentTypeOf = v;
    }
    return _contentType;
  }

  @override
  set contentType(ContentType? type) {
    if (type == null) {
      removeAll(HttpHeaders.contentTypeHeader);
      return;
    }
    // apps set the same const types (eg. ContentType.json) again and
    // again. Keep the text of the last one, so it is not built each time.
    if (!identical(type, _lastType)) {
      _lastType = type;
      _lastTypeText = type.toString();
    }
    String text = _lastTypeText!;
    if (_shared) {
      // no copy: send() uses cached bytes for defaults plus this type
      _sharedType = type;
      _sharedTypeText = text;
    } else {
      set(HttpHeaders.contentTypeHeader, text);
    }
    // the getter (and so `encoding`) then needs no parse
    _contentType = type;
    _contentTypeOf = text;
  }

  static ContentType? _lastType;
  static String? _lastTypeText;

  @override
  bool get chunkedTransferEncoding {
    if (_mutable) return _chunked;
    return value(HttpHeaders.transferEncodingHeader)
            ?.toLowerCase()
            .contains('chunked') ==
        true;
  }

  @override
  set chunkedTransferEncoding(bool chunked) => _chunked = chunked;

  @override
  bool get persistentConnection {
    String? c = _get(HttpHeaders.connectionHeader)?.join(',').toLowerCase();
    if (c == null) return !_http10;
    if (c.contains('close')) return false;
    return !_http10 || c.contains('keep-alive');
  }

  @override
  set persistentConnection(bool keep) {
    if (keep) {
      removeAll(HttpHeaders.connectionHeader);
    } else {
      set(HttpHeaders.connectionHeader, 'close');
    }
  }

  DateTime? _date(String name) {
    String? v = value(name);
    if (v == null) return null;
    try {
      return HttpDate.parse(v);
    } on Exception {
      return null;
    }
  }

  void _setDate(String name, DateTime? date) {
    if (date == null) {
      removeAll(name);
    } else {
      set(name, HttpDate.format(date.toUtc()));
    }
  }

  @override
  DateTime? get date => _date(HttpHeaders.dateHeader);

  @override
  set date(DateTime? date) => _setDate(HttpHeaders.dateHeader, date);

  @override
  DateTime? get expires => _date(HttpHeaders.expiresHeader);

  @override
  set expires(DateTime? expires) =>
      _setDate(HttpHeaders.expiresHeader, expires);

  @override
  DateTime? get ifModifiedSince => _date(HttpHeaders.ifModifiedSinceHeader);

  @override
  set ifModifiedSince(DateTime? date) {
    _setDate(HttpHeaders.ifModifiedSinceHeader, date);
  }

  @override
  String? get host {
    String? v = value(HttpHeaders.hostHeader);
    if (v == null) return null;
    if (v.startsWith('[')) {
      int end = v.indexOf(']');
      return end < 0 ? v : v.substring(1, end);
    }
    int colon = v.indexOf(':');
    return colon < 0 ? v : v.substring(0, colon);
  }

  @override
  set host(String? host) {
    if (host == null) {
      removeAll(HttpHeaders.hostHeader);
    } else {
      set(HttpHeaders.hostHeader, port == null ? host : '$host:$port');
    }
  }

  @override
  int? get port {
    String? v = value(HttpHeaders.hostHeader);
    if (v == null) return null;
    int colon = v.lastIndexOf(':');
    if (colon < 0 || colon < v.lastIndexOf(']')) return null;
    return int.tryParse(v.substring(colon + 1));
  }

  @override
  set port(int? port) {
    String? h = host;
    if (h != null) set(HttpHeaders.hostHeader, port == null ? h : '$h:$port');
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    forEach((String name, List<String> values) {
      for (String v in values) {
        sb.write('$name: $v\n');
      }
    });
    return sb.toString();
  }
}
