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
/// Connections open when they are needed. Isolates that open the same
/// settings share one pool in Rust, so `maxConnections` is for the whole
/// process. Or give [handle] to another isolate and use
/// [PgNativePool.fromHandle] there.
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

  /// Makes a pool of up to [maxConnections] connections. The same
  /// settings in another isolate give the same pool.
  ///
  /// A [host] that starts with `/` is a Unix socket folder, like libpq.
  /// Eg. `/cloudsql/project:region:instance` on Google Cloud Run.
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

  /// Gives back this open of the pool. Isolates that open the same
  /// settings share one pool, and the last [close] closes it for all of
  /// them. Running queries finish. Call it once per [PgNativePool.open];
  /// a pool from [PgNativePool.fromHandle] is closed by the isolate that
  /// opened it.
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

  /// The waiting requests. The id of a request is its slot here. Rust
  /// answers each id once, so a slot is free again after its answer.
  final List<Completer<Object?>?> _pending = <Completer<Object?>?>[];

  /// the sql of each waiting request, to find the columns it had before
  final List<Uint8List> _sqls = <Uint8List>[];
  final List<int> _free = <int>[];
  int _waiting = 0;

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
    int id = _free.isEmpty ? _pending.length : _free.last;
    Completer<T> done = Completer<T>();
    // encode first: a bad value throws before anything is queued
    _write(id, pool, tx, kind, sql, values);
    if (id == _pending.length) {
      _pending.add(done);
      _sqls.add(sql);
    } else {
      _free.removeLast();
      _pending[id] = done;
      _sqls[id] = sql;
    }
    if (_waiting++ == 0) _port.keepIsolateAlive = true;
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
    List<(int, int, Object?)> params = <(int, int, Object?)>[
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
    for ((int, int, Object?) p in params) {
      _ensure(9);
      int at = _len;
      _outData.setUint32(at, p.$1, Endian.little);
      _outData.setUint8(at + 4, p.$2);
      _len += 9;
      Object? data = p.$3;
      if (data is int) {
        _digits(data);
      } else if (data is List<int>) {
        _bytes(data);
      }
      _outData.setInt32(
        at + 5,
        data == null ? -1 : _len - at - 9,
        Endian.little,
      );
    }
  }

  /// Writes [v] as decimal text, without a String in between.
  void _digits(int v) {
    // the minus of the smallest int64 can not be flipped
    if (v == -0x8000000000000000) return _bytes('$v'.codeUnits);
    _ensure(20);
    Uint8List o = _out;
    int at = _len;
    if (v < 0) {
      o[at++] = 0x2d; // -
      v = -v;
    }
    int n = 1;
    for (int t = v; t >= 10; t ~/= 10) {
      n++;
    }
    for (int i = at + n - 1; i >= at; i--) {
      o[i] = 0x30 + v % 10;
      v ~/= 10;
    }
    _len = at + n;
  }

  /// (type oid, format, value) of one parameter, the same bytes the
  /// `postgres` package sends. The value is the bytes, an `int` to write
  /// as text, or null for NULL.
  static (int, int, Object?) _encode(TypedValue<Object> v) {
    if (v.isSqlNull) return (v.type.oid ?? 0, 0, null);
    Object? value = v.value;
    if (v.type == Type.unspecified) {
      // the common ones without the type registry. An int goes as text
      // with no type, like the `postgres` package: the server then picks
      // the type (eg. int4, or text for `WHERE name = $1`).
      if (value is String) return (0, 0, utf8.encode(value));
      if (value is int) return (0, 0, value);
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
      Completer<Object?>? done = id < _pending.length ? _pending[id] : null;
      if (done == null) continue;
      _pending[id] = null;
      Uint8List sql = _sqls[id];
      _sqls[id] = PgNativePool._noSql;
      _free.add(id);
      _waiting--;
      // one bad record fails its own request, not the rest of the batch
      try {
        switch (status) {
          case 0:
            done.complete(_rows(b, d, at, sql));
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
    if (_waiting == 0) _port.keepIsolateAlive = false;
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

  /// the columns of the last result of each sql (the `Uint8List` of
  /// [ParsedSql], one per sql text). The same query gives the same columns,
  /// so most results skip the decode. The same name strings also keep
  /// their hash code for the row maps. It goes away with its sql.
  static final Expando<_Columns> _columns = Expando<_Columns>();

  static PgNativeResult _rows(Uint8List b, ByteData d, int at, Uint8List sql) {
    int count = d.getUint16(at, Endian.little);
    int start = at;
    at += 2;
    for (int c = 0; c < count; c++) {
      at += 6 + d.getUint16(at + 4, Endian.little);
    }
    _Columns? known = _columns[sql];
    // the bytes are checked: the columns change after eg. ALTER TABLE
    if (known == null || !_same(known.head, b, start, at)) {
      List<String> names = List<String>.filled(count, '');
      List<int> oids = List<int>.filled(count, 0);
      int p = start + 2;
      for (int c = 0; c < count; c++) {
        oids[c] = d.getUint32(p, Endian.little);
        int len = d.getUint16(p + 4, Endian.little);
        names[c] = utf8.decoder.convert(b, p + 6, p + 6 + len);
        p += 6 + len;
      }
      known = _columns[sql] = _Columns(
        Uint8List.fromList(Uint8List.sublistView(b, start, at)),
        List<String>.unmodifiable(names), // shared by results
        oids,
      );
    }
    List<String> names = known.names;
    List<int> oids = known.oids;
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
  static const int _dayMicros = 86400000000;
  static const int _infinity = 0x7fffffffffffffff;
  static final Converter<List<int>, Object?> _json = utf8.decoder.fuse(
    json.decoder,
  );
  static const String _hex = '0123456789abcdef';

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
      case 1082: // date
        int days = d.getInt32(at);
        if (days != 0x7fffffff && days != -0x80000000) {
          return DateTime.fromMicrosecondsSinceEpoch(
            _y2kMicros + days * _dayMicros,
            isUtc: true,
          );
        }
      case 2950 when len == 16: // uuid
        return _uuid(b, at);
      case 1700: // numeric
        return _numeric(d, at);
      case 114: // json
        return _json.convert(Uint8List.sublistView(b, at, at + len));
      case 3802 when len > 0 && b[at] == 1: // jsonb, version 1
        return _json.convert(Uint8List.sublistView(b, at + 1, at + len));
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

  /// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`, lower case
  static String _uuid(Uint8List b, int at) {
    List<int> out = List<int>.filled(36, 0x2d); // -
    int o = 0;
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) o++;
      int v = b[at + i];
      out[o++] = _hex.codeUnitAt(v >> 4);
      out[o++] = _hex.codeUnitAt(v & 15);
    }
    return String.fromCharCodes(out);
  }

  /// numeric as text, with all its digits. Postgres sends groups of 4
  /// decimal digits: the first one times 10000^weight.
  static String _numeric(ByteData d, int at) {
    int count = d.getInt16(at);
    int weight = d.getInt16(at + 2);
    int sign = d.getUint16(at + 4);
    int scale = d.getInt16(at + 6);
    if (sign == 0xc000) return 'NaN';
    if (sign == 0xd000) return 'Infinity';
    if (sign == 0xf000) return '-Infinity';
    int group(int i) => i >= 0 && i < count ? d.getInt16(at + 8 + 2 * i) : 0;
    StringBuffer out = StringBuffer(sign == 0x4000 ? '-' : '');
    if (weight < 0) {
      out.write('0');
    } else {
      out.write(group(0)); // no leading zeros
      for (int i = 1; i <= weight; i++) {
        out.write(group(i).toString().padLeft(4, '0'));
      }
    }
    if (scale > 0) {
      StringBuffer fraction = StringBuffer();
      for (int i = weight + 1; fraction.length < scale; i++) {
        fraction.write(group(i).toString().padLeft(4, '0'));
      }
      out
        ..write('.')
        ..write(fraction.toString().substring(0, scale));
    }
    return out.toString();
  }
}

/// The columns of one result: the bytes they came in, names and type oids.
class _Columns {
  _Columns(this.head, this.names, this.oids);

  final Uint8List head;
  final List<String> names;
  final List<int> oids;
}

/// Decodes one binary value of type [oid] like a result row does. For
/// tests.
Object? decodeValue(int oid, Uint8List bytes) =>
    _Link._decode(oid, bytes, ByteData.sublistView(bytes), 0, bytes.length);
