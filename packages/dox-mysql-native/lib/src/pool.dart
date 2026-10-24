import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_mysql_native/src/bindings.dart';
import 'package:mysql_dart/exception.dart';

/// The result of one query.
class MysqlNativeResult {
  /// column names, empty when the query returns no rows (eg. INSERT)
  final List<String> columns;

  /// one map per row, column name to value
  final List<Map<String, dynamic>> rows;

  /// rows changed by INSERT, UPDATE or DELETE
  final int affectedRows;

  /// the AUTO_INCREMENT id of an INSERT, else 0
  final int insertId;

  const MysqlNativeResult(
    this.columns,
    this.rows,
    this.affectedRows,
    this.insertId,
  );
}

/// A pool of MySQL or MariaDB connections, owned by Rust (mysql_async).
/// Each connection keeps a cache of prepared statements.
///
/// ```
/// MysqlNativePool pool = MysqlNativePool.open(
///   host: 'localhost', user: 'root', password: 'secret', database: 'app',
/// );
/// MysqlNativeResult r = await pool.query(
///   'SELECT * FROM users WHERE id = ?',
///   parameters: <Object?>[1],
/// );
/// ```
///
/// Values come back typed: int, double (also DECIMAL), String, bool
/// (TINYINT(1)), DateTime in UTC (DATE, DATETIME, TIMESTAMP), decoded JSON,
/// Uint8List (BLOB, BINARY) and null. MariaDB keeps JSON in LONGTEXT, so
/// there TEXT that is a JSON object or array comes back decoded.
///
/// Connections open when they are needed. Isolates that open the same
/// settings share one pool. Or give [handle] to another isolate and use
/// [MysqlNativePool.fromHandle] there.
class MysqlNativePool {
  MysqlNativePool.fromHandle(this.handle);

  /// the pool id in Rust. Works in every isolate of this process.
  final int handle;

  /// true when the native library is loaded and works.
  static bool get isAvailable => _Link.available;

  /// why [isAvailable] is false, or null.
  static String? get loadError => _Link.loadError;

  /// Makes a pool of up to [maxConnections] connections.
  ///
  /// A [host] that starts with `/` is the path of a Unix socket file, eg.
  /// `/var/run/mysqld/mysqld.sock` or `/cloudsql/project:region:instance`.
  /// Then [port] is not used.
  ///
  /// [secure] turns on TLS. The server certificate is checked. Set
  /// [verifyCertificate] to false to skip the check, only for a self-signed
  /// certificate in development.
  ///
  /// [threads] is the size of the Rust runtime of the whole process. Only
  /// the first pool sets it. One thread is the fastest for most apps.
  factory MysqlNativePool.open({
    String host = 'localhost',
    int port = 3306,
    required String user,
    String password = '',
    required String database,
    int maxConnections = 10,
    bool secure = false,
    bool verifyCertificate = true,
    int statementCacheSize = 32,
    Duration maxConnectionAge = const Duration(hours: 12),
    int threads = 1,
  }) {
    bool socket = host.startsWith('/');
    Uri url = Uri(
      scheme: 'mysql',
      userInfo: '${Uri.encodeComponent(user)}:${Uri.encodeComponent(password)}',
      host: socket ? 'localhost' : host,
      port: port,
      path: '/${Uri.encodeComponent(database)}',
      queryParameters: <String, String>{
        // reset_connection would reset each connection when it goes back to
        // the pool: one more round trip, and it drops the statement cache.
        'reset_connection': 'false',
        // do not switch to the unix socket of the server (eg. in docker)
        'prefer_socket': 'false',
        'pool_min': '$maxConnections',
        'pool_max': '$maxConnections',
        'stmt_cache_size': '$statementCacheSize',
        'conn_ttl': '${maxConnectionAge.inSeconds}',
        if (secure) 'require_ssl': 'true',
        // only for a self-signed certificate in development
        if (secure && !verifyCertificate) ...<String, String>{
          'verify_ca': 'false',
          'verify_identity': 'false',
        },
        if (socket) 'socket': host,
      },
    );
    return MysqlNativePool.fromUrl(url.toString(), threads: threads);
  }

  /// Makes a pool from a `mysql://user:password@host:port/database` URL.
  /// It takes the URL options of mysql_async, like `?pool_max=20`, or
  /// `?socket=/var/run/mysqld/mysqld.sock` for a Unix socket.
  factory MysqlNativePool.fromUrl(String url, {int threads = 1}) {
    if (!isAvailable) {
      throw UnsupportedError('dox_mysql_native is not available: $loadError');
    }
    Uint8List bytes = utf8.encode(url);
    int handle = doxMysqlConnect(bytes.address, bytes.length, threads);
    if (handle <= 0) {
      throw ArgumentError('dox_mysql_native: bad connection config');
    }
    return MysqlNativePool.fromHandle(handle);
  }

  /// Runs [sql] and returns its rows.
  ///
  /// [parameters] is a list for `?` placeholders, or a map for `@name`
  /// placeholders (like the Dox ORM). Values can be null, int, double,
  /// bool, String, DateTime, Uint8List, or a Map or List (sent as JSON).
  /// [transaction] is an id from [begin].
  /// Throws [MySQLServerException] for errors from the server (with its
  /// error code), [MySQLClientException] for others. The same as mysql_dart.
  Future<MysqlNativeResult> query(
    String sql, {
    Object? parameters,
    int transaction = 0,
  }) => _send(_opQuery, sql, parameters, transaction);

  /// Like [query], but the rows are not sent back to Dart.
  Future<MysqlNativeResult> execute(
    String sql, {
    Object? parameters,
    int transaction = 0,
  }) => _send(_opExecute, sql, parameters, transaction);

  /// Starts a transaction on one connection. Use its id as `transaction`
  /// of [query], then [commit] or [rollback] it.
  Future<int> begin() async {
    MysqlNativeResult r = await _send(_opBegin, '', null, 0);
    return r.insertId;
  }

  /// Commits the transaction and gives its connection back to the pool.
  Future<void> commit(int transaction) =>
      _send(_opCommit, '', null, transaction);

  /// Rolls the transaction back and gives its connection back to the pool.
  Future<void> rollback(int transaction) =>
      _send(_opRollback, '', null, transaction);

  /// Gives back this open of the pool. Isolates that open the same
  /// settings share one pool, and the last [close] disconnects it for
  /// all of them. Running queries finish. Call it once per
  /// [MysqlNativePool.open]; a pool from [MysqlNativePool.fromHandle] is
  /// closed by the isolate that opened it.
  void close() => doxMysqlClose(handle);

  Future<MysqlNativeResult> _send(
    int op,
    String sql,
    Object? parameters,
    int transaction,
  ) {
    List<Object?> params;
    if (parameters is Map<String, dynamic>) {
      (sql, params) = _toPositional(sql, parameters);
    } else if (parameters is List<Object?>) {
      params = parameters;
    } else if (parameters == null) {
      params = const <Object?>[];
    } else {
      throw ArgumentError.value(parameters, 'parameters', 'a List or a Map');
    }
    return _Link.instance.send(handle, transaction, op, sql, params);
  }

  /// changes each known `@key` to `?` and lists its value in the same
  /// order. An unknown `@word` (eg. 'a@b.com' in a string) stays as it is.
  // ponytail: no cache of the converted sql. The Dox ORM driver sends
  // lists, so only direct pool users with maps pay for the regex.
  static (String, List<Object?>) _toPositional(
    String sql,
    Map<String, dynamic> values,
  ) {
    List<Object?> params = <Object?>[];
    String converted = sql.replaceAllMapped(_paramPattern, (Match m) {
      String key = m.group(1)!;
      if (!values.containsKey(key)) return m.group(0)!;
      params.add(values[key]);
      return '?';
    });
    return (converted, params);
  }

  static final RegExp _paramPattern = RegExp(r'@(\w+)');
}

const int _opQuery = 0;
const int _opExecute = 1;
const int _opBegin = 2;
const int _opCommit = 3;
const int _opRollback = 4;

const int _tNull = 0;
const int _tInt = 1;
const int _tDouble = 2;
const int _tText = 3;
const int _tBytes = 4;
const int _tDate = 5;
const int _tBool = 6;
const int _tJson = 7;
const int _tLongText = 8;

/// One per isolate: the port Rust posts results to, and the requests
/// that wait for them. Requests of one microtask go to Rust in one call.
class _Link {
  _Link._() {
    _port = RawReceivePort(_onBatch, 'dox_mysql_native');
    _port.keepIsolateAlive = false;
    _handle = doxMysqlClient(_port.sendPort.nativePort);
    if (_handle <= 0) {
      _port.close();
      throw MySQLClientException('dox_mysql_native: dox_mysql_client failed');
    }
  }

  static _Link? _instance;

  static _Link get instance {
    if (!available) {
      throw UnsupportedError('dox_mysql_native is not available: $loadError');
    }
    return _instance ??= _Link._();
  }

  static bool? _available;
  static String? _loadError;

  static bool get available => _available ??= _load();

  static String? get loadError {
    available;
    return _loadError;
  }

  static bool _load() {
    try {
      int version = doxMysqlVersion();
      if (version != abiVersion) {
        _loadError = 'native library ABI $version, expected $abiVersion';
        return false;
      }
      int rc = doxMysqlInit(NativeApi.initializeApiDLData);
      if (rc != 0) {
        _loadError = 'dox_mysql_init failed ($rc)';
        return false;
      }
      return true;
    } catch (error) {
      // the build hook found no library for this platform
      _loadError = '$error';
      return false;
    }
  }

  late final RawReceivePort _port;
  late final int _handle;
  int _nextId = 1;
  final Map<int, _Pending> _pending = <int, _Pending>{};

  Uint8List _out = Uint8List(1 << 14);
  late ByteData _outData = ByteData.sublistView(_out);
  int _len = 0;
  bool _flushQueued = false;

  Future<MysqlNativeResult> send(
    int pool,
    int tx,
    int op,
    String sql,
    List<Object?> params,
  ) {
    int id = _nextId++;
    _Pending pending = _Pending();
    if (_pending.isEmpty) _port.keepIsolateAlive = true;
    _pending[id] = pending;
    int start = _len;
    try {
      _write(id, pool, tx, op, sql, params);
    } catch (_) {
      _len = start;
      _done(id);
      rethrow;
    }
    if (!_flushQueued) {
      _flushQueued = true;
      scheduleMicrotask(_flush);
    }
    return pending.completer.future;
  }

  void _flush() {
    _flushQueued = false;
    if (_len == 0) return;
    doxMysqlSubmit(_handle, _out.address, _len);
    _len = 0;
    if (_out.length > 1 << 20) {
      _out = Uint8List(1 << 14); // do not keep a big buffer forever
      _outData = ByteData.sublistView(_out);
    }
  }

  void _done(int id) {
    _pending.remove(id);
    if (_pending.isEmpty) _port.keepIsolateAlive = false;
  }

  // ---- requests ----

  void _ensure(int extra) {
    int need = _len + extra;
    if (need <= _out.length) return;
    int size = _out.length * 2;
    while (size < need) {
      size *= 2;
    }
    Uint8List grown = Uint8List(size)..setRange(0, _len, _out);
    _out = grown;
    _outData = ByteData.sublistView(grown);
  }

  void _write(
    int id,
    int pool,
    int tx,
    int op,
    String sql,
    List<Object?> params,
  ) {
    // head: u64 id, u64 pool, u64 tx, u8 op + 3 reserved, u32 sql_len,
    // u32 param count
    _ensure(36);
    int start = _len;
    _outData.setUint64(start, id, Endian.little);
    _outData.setUint64(start + 8, pool, Endian.little);
    _outData.setUint64(start + 16, tx, Endian.little);
    _outData.setUint32(start + 24, op, Endian.little);
    _outData.setUint32(start + 32, params.length, Endian.little);
    _len += 36;
    _string(sql);
    _outData.setUint32(start + 28, _len - start - 36, Endian.little);
    for (Object? value in params) {
      _param(value);
    }
  }

  /// writes utf8 bytes, ASCII without a copy
  void _string(String s) {
    _ensure(s.length);
    Uint8List o = _out;
    int at = _len;
    for (int i = 0; i < s.length; i++) {
      int c = s.codeUnitAt(i);
      if (c >= 128) {
        Uint8List bytes = utf8.encode(s);
        _ensure(bytes.length);
        _out.setRange(_len, _len + bytes.length, bytes);
        _len += bytes.length;
        return;
      }
      o[at++] = c;
    }
    _len = at;
  }

  void _param(Object? value) {
    if (value is bool) value = value ? 1 : 0;
    if (value == null) {
      _ensure(1);
      _out[_len++] = _tNull;
    } else if (value is int) {
      _ensure(9);
      _out[_len] = _tInt;
      _outData.setInt64(_len + 1, value, Endian.little);
      _len += 9;
    } else if (value is double) {
      _ensure(9);
      _out[_len] = _tDouble;
      _outData.setFloat64(_len + 1, value, Endian.little);
      _len += 9;
    } else if (value is Uint8List) {
      _ensure(5 + value.length);
      _out[_len] = _tBytes;
      _outData.setUint32(_len + 1, value.length, Endian.little);
      _out.setRange(_len + 5, _len + 5 + value.length, value);
      _len += 5 + value.length;
    } else {
      String text = value is DateTime
          ? _dateText(value)
          : value is Map || value is List
          ? jsonEncode(value)
          : value.toString();
      _ensure(5);
      int at = _len;
      _out[at] = _tText;
      _len += 5;
      _string(text);
      _outData.setUint32(at + 1, _len - at - 5, Endian.little);
    }
  }

  /// `2024-01-02 03:04:05.000006`, the time in UTC
  static String _dateText(DateTime d) {
    String s = d.toUtc().toIso8601String();
    return s.substring(0, s.length - 1).replaceFirst('T', ' ');
  }

  // ---- results ----

  void _onBatch(Object? message) {
    Uint8List b = message as Uint8List;
    ByteData d = ByteData.sublistView(b);
    int p = 0;
    while (p + 16 <= b.length) {
      int id = d.getUint64(p, Endian.little);
      int status = b[p + 8];
      int len = d.getUint32(p + 12, Endian.little);
      int body = p + 16;
      p = body + len;
      _Pending? pending = _pending[id];
      if (pending == null) continue;
      _done(id);
      if (status == 0) {
        pending.completer.complete(_rows(b, d, body));
      } else {
        pending.completer.completeError(_error(b, d, body, len));
      }
    }
  }

  static Exception _error(Uint8List b, ByteData d, int at, int len) {
    int code = d.getUint16(at, Endian.little);
    int kind = b[at + 2];
    String message = utf8.decode(
      Uint8List.sublistView(b, at + 8, at + len),
      allowMalformed: true,
    );
    if (kind == 0) return MySQLServerException(message, code);
    return MySQLClientException(message);
  }

  static MysqlNativeResult _rows(Uint8List b, ByteData d, int p) {
    int affected = d.getUint64(p, Endian.little);
    int insertId = d.getUint64(p + 8, Endian.little);
    int ncols = d.getUint32(p + 16, Endian.little);
    int nrows = d.getUint32(p + 20, Endian.little);
    p += 24;
    List<String> names = List<String>.filled(ncols, '');
    for (int i = 0; i < ncols; i++) {
      int len = d.getUint16(p, Endian.little);
      p += 2;
      names[i] = _text(b, p, len);
      p += len;
    }
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (int r = 0; r < nrows; r++) {
      Map<String, dynamic> row = <String, dynamic>{};
      rows.add(row);
      for (int c = 0; c < ncols; c++) {
        int tag = b[p++];
        dynamic value;
        switch (tag) {
          case _tNull:
            value = null;
          case _tInt:
            value = d.getInt64(p, Endian.little);
            p += 8;
          case _tDouble:
            value = d.getFloat64(p, Endian.little);
            p += 8;
          case _tDate:
            value = DateTime.fromMicrosecondsSinceEpoch(
              d.getInt64(p, Endian.little),
              isUtc: true,
            );
            p += 8;
          case _tBool:
            value = b[p++] != 0;
          default:
            int len = d.getUint32(p, Endian.little);
            p += 4;
            if (tag == _tBytes) {
              value = Uint8List.fromList(Uint8List.sublistView(b, p, p + len));
            } else {
              String text = _text(b, p, len);
              value = tag == _tJson
                  ? jsonDecode(text)
                  : tag == _tLongText
                  ? _maybeJson(text)
                  : text;
            }
            p += len;
        }
        row[names[c]] = value;
      }
    }
    return MysqlNativeResult(names, rows, affected, insertId);
  }

  static String _text(Uint8List b, int at, int len) {
    return utf8.decode(Uint8List.sublistView(b, at, at + len));
  }

  /// MariaDB: text that is a JSON object or array is decoded
  static Object? _maybeJson(String text) {
    String t = text.trimLeft();
    if (!t.startsWith('{') && !t.startsWith('[')) return text;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }
}

class _Pending {
  final Completer<MysqlNativeResult> completer = Completer<MysqlNativeResult>();
}
