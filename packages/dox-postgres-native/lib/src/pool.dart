import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_postgres_native/src/bindings.dart';
import 'package:dox_postgres_native/src/compat.dart';
import 'package:postgres/postgres.dart';

/// The rows of one query. Values have the same Dart types as with the
/// `postgres` package (eg. `int`, `String`, `DateTime` in UTC, a decoded
/// JSON value, `Uint8List` for bytea).
class PgNativeResult {
  PgNativeResult(this.columns, this.rows);

  /// column names, in the order of the select
  final List<String> columns;

  /// one map per row, column name to value
  final List<Map<String, dynamic>> rows;
}

/// A pool of Postgres connections, owned by Rust.
///
/// ```
/// PgNativePool pool = PgNativePool.open(
///   host: 'localhost', user: 'postgres', password: 'postgres',
///   database: 'postgres',
/// );
/// PgNativeResult r = await pool.query(
///   'SELECT * FROM users WHERE id = @id',
///   parameters: <String, dynamic>{'id': 1},
/// );
/// ```
///
/// Connections open when they are needed. Give [handle] to other isolates
/// and use [PgNativePool.fromHandle] there: they all share one pool.
class PgNativePool {
  PgNativePool.fromHandle(this.handle);

  /// the pool id in Rust. Works in every isolate of this process.
  final int handle;

  static bool? _available;
  static String? _loadError;

  /// true when the native library is loaded and works.
  static bool get isAvailable => _available ??= _load();

  /// why [isAvailable] is false, or null.
  static String? get loadError {
    isAvailable;
    return _loadError;
  }

  static bool _load() {
    try {
      int version = dpgVersion();
      if (version != abiVersion) {
        _loadError = 'native library ABI $version, expected $abiVersion';
        return false;
      }
      int rc = dpgInit(NativeApi.initializeApiDLData);
      if (rc != 0) {
        _loadError = 'dpg_init failed ($rc)';
        return false;
      }
      return true;
    } catch (error) {
      // the build hook found no library for this platform
      _loadError = '$error';
      return false;
    }
  }

  /// Makes a pool of up to [maxConnections] connections.
  ///
  /// [threads] is the size of the Rust runtime of the whole process. Only
  /// the first pool sets it. 0 runs one `current_thread` runtime on its own
  /// thread.
  factory PgNativePool.open({
    String host = 'localhost',
    int port = 5432,
    required String user,
    String password = '',
    required String database,
    int maxConnections = 10,
    String timeZone = 'UTC',
    String? applicationName,
    int threads = 1,
  }) {
    if (!isAvailable) {
      throw UnsupportedError(
        'dox_postgres_native is not available: $_loadError',
      );
    }
    String config = <String>[
      'host=${_quote(host)}',
      'port=$port',
      'user=${_quote(user)}',
      'password=${_quote(password)}',
      'dbname=${_quote(database)}',
      // same session time zone as the postgres package
      'options=${_quote('-c TimeZone=$timeZone')}',
      // same connect timeout as the postgres package
      'connect_timeout=15',
      if (applicationName != null)
        'application_name=${_quote(applicationName)}',
    ].join(' ');
    Uint8List bytes = utf8.encode(config);
    int handle = dpgConnect(
      bytes.address,
      bytes.length,
      maxConnections,
      threads,
    );
    if (handle <= 0) {
      throw ArgumentError('dox_postgres_native: bad connection config');
    }
    return PgNativePool.fromHandle(handle);
  }

  static String _quote(String v) =>
      "'${v.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  /// Runs [sql] and returns its rows.
  ///
  /// [parameters] is a map for `@name` parameters (like `Sql.named`), or a
  /// list for `$1, $2...`. Values are sent like the `postgres` package
  /// sends them; a [TypedValue] sets the type.
  /// Throws [ServerException] (eg. [UniqueViolationException]) for errors
  /// from the server, [PgException] for others.
  Future<PgNativeResult> query(
    String sql, {
    Object? parameters,
    int transaction = 0,
  }) {
    ParsedSql parsed = parameters is List
        ? ParsedSql.direct(sql)
        : ParsedSql.named(sql);
    List<TypedValue<Object>> values = parsed.bind(parameters);
    return _Link.instance.send<PgNativeResult>(
      handle,
      transaction,
      0,
      parsed.sql,
      values,
    );
  }

  /// Starts a transaction on one connection. Use its id as `transaction`
  /// of [query], then [commit] or [rollback] it.
  Future<int> begin() => _Link.instance.send<int>(
    handle,
    0,
    1,
    _noSql,
    const <TypedValue<Object>>[],
  );

  static final Uint8List _noSql = Uint8List(0);

  /// Commits the transaction and gives its connection back to the pool.
  Future<void> commit(int transaction) => _end(transaction, 2);

  /// Rolls the transaction back and gives its connection back to the pool.
  Future<void> rollback(int transaction) => _end(transaction, 3);

  Future<void> _end(int transaction, int kind) => _Link.instance.send<void>(
    handle,
    transaction,
    kind,
    _noSql,
    const <TypedValue<Object>>[],
  );

  /// Closes the pool for every isolate. Running queries finish.
  void close() => dpgClose(handle);
}

final CodecContext _codec = CodecContext.withDefaults();

/// The link of this isolate to Rust: one sink for the results, and one
/// buffer for the requests that go out in the next microtask.
class _Link {
  _Link._() {
    _port = RawReceivePort(_onBatch, 'dox_postgres_native');
    _port.keepIsolateAlive = false;
    _sink = dpgOpen(_port.sendPort.nativePort);
  }

  static final _Link instance = _Link._();

  late final RawReceivePort _port;
  late final int _sink;
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextId = 0;

  Uint8List _out = Uint8List(1 << 14);
  late ByteData _outData = ByteData.sublistView(_out);
  int _len = 0;
  bool _flushQueued = false;

  Future<T> send<T>(
    int pool,
    int tx,
    int kind,
    Uint8List sql,
    List<TypedValue<Object>> values,
  ) {
    int id = ++_nextId;
    Completer<T> done = Completer<T>();
    // encode first: a bad value throws before anything is queued
    _write(id, pool, tx, kind, sql, values);
    if (_pending.isEmpty) _port.keepIsolateAlive = true;
    _pending[id] = done;
    if (!_flushQueued) {
      _flushQueued = true;
      scheduleMicrotask(_flush);
    }
    return done.future;
  }

  void _ensure(int extra) {
    int need = _len + extra;
    if (need <= _out.length) return;
    int size = _out.length * 2;
    while (size < need) {
      size *= 2;
    }
    _out = Uint8List(size)..setRange(0, _len, _out);
    _outData = ByteData.sublistView(_out);
  }

  void _bytes(List<int> b) {
    _ensure(b.length);
    _out.setRange(_len, _len + b.length, b);
    _len += b.length;
  }

  void _write(
    int id,
    int pool,
    int tx,
    int kind,
    Uint8List sql,
    List<TypedValue<Object>> values,
  ) {
    List<(int, int, List<int>?)> params = <(int, int, List<int>?)>[
      for (TypedValue<Object> v in values) _encode(v),
    ];
    int start = _len;
    _ensure(32);
    ByteData d = _outData;
    d.setUint64(start, id, Endian.little);
    d.setUint64(start + 8, pool, Endian.little);
    d.setUint64(start + 16, tx, Endian.little);
    d.setUint8(start + 24, kind);
    d.setUint8(start + 25, 0);
    d.setUint16(start + 26, params.length, Endian.little);
    d.setUint32(start + 28, sql.length, Endian.little);
    _len += 32;
    _bytes(sql);
    for ((int, int, List<int>?) p in params) {
      _ensure(9);
      _outData.setUint32(_len, p.$1, Endian.little);
      _outData.setUint8(_len + 4, p.$2);
      _outData.setInt32(_len + 5, p.$3?.length ?? -1, Endian.little);
      _len += 9;
      if (p.$3 != null) _bytes(p.$3!);
    }
  }

  /// (type oid, format, bytes) of one parameter, the same bytes the
  /// `postgres` package sends.
  static (int, int, List<int>?) _encode(TypedValue<Object> v) {
    if (v.isSqlNull) return (v.type.oid ?? 0, 0, null);
    Object? value = v.value;
    if (v.type == Type.unspecified) {
      // the common ones without the type registry
      if (value is String) return (0, 0, utf8.encode(value));
      if (value is int) return (0, 0, '$value'.codeUnits);
    }
    Object? e = _codec.typeRegistry.encode(v, _codec);
    if (e is! EncodedValue) {
      throw PgException('dox_postgres_native: $value needs an async encoder');
    }
    return (v.type.oid ?? 0, e.isBinary ? 1 : 0, e.bytes);
  }

  void _flush() {
    _flushQueued = false;
    if (_len == 0) return;
    dpgSubmit(_sink, _out.address, _len);
    _len = 0;
    if (_out.length > 1 << 20) {
      _out = Uint8List(1 << 14); // do not keep a big buffer forever
      _outData = ByteData.sublistView(_out);
    }
  }

  // ---- results from Rust ----

  void _onBatch(Object? message) {
    Uint8List b = message as Uint8List;
    ByteData d = ByteData.sublistView(b);
    int p = 0;
    while (p + 13 <= b.length) {
      int id = d.getUint64(p, Endian.little);
      int status = d.getUint8(p + 8);
      int len = d.getUint32(p + 9, Endian.little);
      int at = p + 13;
      p = at + len;
      Completer<Object?>? done = _pending.remove(id);
      if (done == null) continue;
      // one bad record fails its own request, not the rest of the batch
      try {
        switch (status) {
          case 0:
            done.complete(_rows(b, d, at));
          case 1:
            done.completeError(serverException(_fields(b, d, at)));
          case 2:
            done.completeError(
              PgException(utf8.decode(Uint8List.sublistView(b, at, p))),
            );
          default:
            done.complete(d.getUint64(at, Endian.little));
        }
      } catch (error, stack) {
        done.completeError(
          PgException('dox_postgres_native: can not read the result: $error'),
          stack,
        );
      }
    }
    if (_pending.isEmpty) _port.keepIsolateAlive = false;
  }

  static List<(int, String)> _fields(Uint8List b, ByteData d, int at) {
    int count = b[at++];
    List<(int, String)> fields = <(int, String)>[];
    for (int i = 0; i < count; i++) {
      int len = d.getUint32(at + 1, Endian.little);
      Uint8List text = Uint8List.sublistView(b, at + 5, at + 5 + len);
      fields.add((b[at], utf8.decode(text)));
      at += 5 + len;
    }
    return fields;
  }

  /// the column part of the last result, and its names and oids. The same
  /// query gives the same columns, so most results skip the decode. The
  /// same name strings also keep their hash code for the row maps.
  static Uint8List _lastHead = Uint8List(0);
  static List<String> _lastNames = const <String>[];
  static List<int> _lastOids = const <int>[];

  static PgNativeResult _rows(Uint8List b, ByteData d, int at) {
    int count = d.getUint16(at, Endian.little);
    int start = at;
    at += 2;
    for (int c = 0; c < count; c++) {
      at += 6 + d.getUint16(at + 4, Endian.little);
    }
    if (!_same(_lastHead, b, start, at)) {
      List<String> names = List<String>.filled(count, '');
      List<int> oids = List<int>.filled(count, 0);
      int p = start + 2;
      for (int c = 0; c < count; c++) {
        oids[c] = d.getUint32(p, Endian.little);
        int len = d.getUint16(p + 4, Endian.little);
        names[c] = utf8.decoder.convert(b, p + 6, p + 6 + len);
        p += 6 + len;
      }
      _lastHead = Uint8List.fromList(Uint8List.sublistView(b, start, at));
      _lastNames = List<String>.unmodifiable(names); // shared by results
      _lastOids = oids;
    }
    List<String> names = _lastNames;
    List<int> oids = _lastOids;
    int rowCount = d.getUint32(at, Endian.little);
    at += 4;
    List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.generate(
      rowCount,
      (_) => <String, dynamic>{},
      growable: false,
    );
    for (int r = 0; r < rowCount; r++) {
      Map<String, dynamic> row = rows[r];
      for (int c = 0; c < count; c++) {
        int len = d.getInt32(at, Endian.little);
        at += 4;
        if (len < 0) {
          row[names[c]] = null;
          continue;
        }
        row[names[c]] = _decode(oids[c], b, d, at, len);
        at += len;
      }
    }
    return PgNativeResult(names, rows);
  }

  /// true when [b] from [start] to [end] has the bytes of [head]
  static bool _same(Uint8List head, Uint8List b, int start, int end) {
    if (head.length != end - start) return false;
    for (int i = 0; i < head.length; i++) {
      if (head[i] != b[start + i]) return false;
    }
    return true;
  }

  static const int _y2kMicros = 946684800000000;
  static const int _infinity = 0x7fffffffffffffff;

  /// One binary value. The common types here, the rest with the type
  /// registry of the `postgres` package.
  static Object? _decode(int oid, Uint8List b, ByteData d, int at, int len) {
    switch (oid) {
      case 16: // bool
        return b[at] != 0;
      case 20: // int8
        return d.getInt64(at);
      case 23: // int4
        return d.getInt32(at);
      case 21: // int2
        return d.getInt16(at);
      case 25 || 1043 || 19 || 1042: // text, varchar, name, bpchar
        return utf8.decoder.convert(b, at, at + len);
      case 701: // float8
        return d.getFloat64(at);
      case 700: // float4
        return d.getFloat32(at);
      case 1114 || 1184: // timestamp, timestamptz
        int micros = d.getInt64(at);
        if (micros != _infinity && micros != -_infinity - 1) {
          return DateTime.fromMicrosecondsSinceEpoch(
            _y2kMicros + micros,
            isUtc: true,
          );
        }
    }
    // a copy: the value must not keep the whole batch alive
    Uint8List bytes = Uint8List.fromList(
      Uint8List.sublistView(b, at, at + len),
    );
    return _codec.typeRegistry.decode(
      EncodedValue.binary(bytes, typeOid: oid),
      _codec,
    );
  }
}
