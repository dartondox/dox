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

/// A MySQL or MariaDB pool. Rust (mysql_async) runs the connections, the
/// pool and a prepared statement cache per connection.
///
/// ```
/// MysqlNativePool pool = await MysqlNativePool.connect(
///   host: 'localhost', user: 'root', password: 'secret', database: 'app');
/// MysqlNativeResult r = await pool.query('SELECT * FROM users WHERE id = ?', [1]);
/// print(r.rows.first['name']);
/// ```
///
/// Values come back typed: int, double (also DECIMAL), String, bool
/// (TINYINT(1)), DateTime in UTC (DATE, DATETIME, TIMESTAMP), decoded JSON,
/// Uint8List (BLOB, BINARY) and null. Params can be null, int, double,
/// bool, String, DateTime, Uint8List, or a Map or List (sent as JSON).
///
/// Isolates that connect with the same settings share one pool.
class MysqlNativePool {
  MysqlNativePool._(this._handle, this.isMariaDb);

  int _handle;

  /// true when the server is MariaDB. MariaDB keeps JSON in LONGTEXT, so
  /// TEXT values that are a JSON object or array come back decoded.
  final bool isMariaDb;

  /// true when the native library is loaded and works.
  static bool get isAvailable => _Client.available;

  /// why [isAvailable] is false, or null.
  static String? get loadError => _Client.loadError;

  /// Open a pool and check the login with `SELECT VERSION()`.
  /// [maxConnections] is per process: all isolates share the pool.
  static Future<MysqlNativePool> connect({
    String host = 'localhost',
    int port = 3306,
    String user = 'root',
    String password = '',
    required String database,
    int maxConnections = 10,
    bool secure = false,
    int statementCacheSize = 32,
    Duration maxConnectionAge = const Duration(hours: 12),
  }) {
    Uri url = Uri(
      scheme: 'mysql',
      userInfo: '${Uri.encodeComponent(user)}:${Uri.encodeComponent(password)}',
      host: host,
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
      },
    );
    return fromUrl(url.toString());
  }

  /// Open a pool from a `mysql://user:password@host:port/database` URL.
  /// It takes the options of mysql_async, like `?pool_max=20`.
  static Future<MysqlNativePool> fromUrl(String url) async {
    _Client client = _Client.instance;
    Uint8List bytes = utf8.encode(url);
    int handle = doxMysqlConnect(bytes.address, bytes.length);
    if (handle <= 0) {
      throw MySQLClientException('dox_mysql_native: invalid url or options');
    }
    MysqlNativePool pool = MysqlNativePool._(handle, false);
    try {
      MysqlNativeResult version = await client.send(
        handle,
        0,
        _opQuery,
        'SELECT VERSION() AS v',
        null,
        false,
      );
      String text = '${version.rows.first['v']}';
      return MysqlNativePool._(handle, text.contains('MariaDB'));
    } catch (_) {
      pool.close();
      rethrow;
    }
  }

  /// Run [sql] and return its rows. Use `?` for [params].
  /// Throws [MySQLServerException] for an error of the server
  /// and [MySQLClientException] for a connection error.
  Future<MysqlNativeResult> query(String sql, [List<Object?>? params]) {
    return _Client.instance.send(_open, 0, _opQuery, sql, params, isMariaDb);
  }

  /// Like [query], but the rows are not sent back to Dart.
  Future<MysqlNativeResult> execute(String sql, [List<Object?>? params]) {
    return _Client.instance.send(_open, 0, _opExecute, sql, params, isMariaDb);
  }

  /// Run [action] in a transaction on one connection. Commit when it ends,
  /// rollback when it throws.
  Future<R> transaction<R>(
    Future<R> Function(MysqlNativeTransaction tx) action,
  ) async {
    MysqlNativeTransaction tx = await begin();
    R result;
    try {
      result = await action(tx);
    } catch (_) {
      await tx.rollback();
      rethrow;
    }
    await tx.commit();
    return result;
  }

  /// Start a transaction. It keeps one connection until [commit] or
  /// [MysqlNativeTransaction.rollback].
  Future<MysqlNativeTransaction> begin() async {
    MysqlNativeResult r = await _Client.instance.send(
      _open,
      0,
      _opBegin,
      '',
      null,
      false,
    );
    return MysqlNativeTransaction._(this, r.insertId);
  }

  /// Give up this pool. The connections close when no isolate uses the
  /// pool anymore.
  void close() {
    if (_handle == 0) return;
    doxMysqlClose(_handle);
    _handle = 0;
  }

  int get _open {
    if (_handle == 0) throw MySQLClientException('the pool is closed');
    return _handle;
  }
}

/// A transaction on one pooled connection.
class MysqlNativeTransaction {
  MysqlNativeTransaction._(this._pool, this._handle);

  final MysqlNativePool _pool;
  int _handle;

  /// Run [sql] in this transaction and return its rows.
  Future<MysqlNativeResult> query(String sql, [List<Object?>? params]) {
    return _Client.instance.send(
      _pool._open,
      _open,
      _opQuery,
      sql,
      params,
      _pool.isMariaDb,
    );
  }

  /// Like [query], but the rows are not sent back to Dart.
  Future<MysqlNativeResult> execute(String sql, [List<Object?>? params]) {
    return _Client.instance.send(
      _pool._open,
      _open,
      _opExecute,
      sql,
      params,
      _pool.isMariaDb,
    );
  }

  /// Commit and give the connection back to the pool.
  Future<void> commit() => _end(_opCommit);

  /// Roll back and give the connection back to the pool.
  Future<void> rollback() => _end(_opRollback);

  Future<void> _end(int op) async {
    int handle = _open;
    _handle = 0;
    await _Client.instance.send(_pool._open, handle, op, '', null, false);
  }

  int get _open {
    if (_handle == 0) throw MySQLClientException('the transaction is closed');
    return _handle;
  }
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
class _Client {
  _Client._() {
    _port = RawReceivePort(_onBatch, 'dox_mysql_native');
    _port.keepIsolateAlive = false;
    _handle = doxMysqlClient(_port.sendPort.nativePort);
    if (_handle <= 0) {
      _port.close();
      throw MySQLClientException('dox_mysql_native: dox_mysql_client failed');
    }
  }

  static _Client? _instance;

  static _Client get instance {
    if (!available) {
      throw UnsupportedError('dox_mysql_native is not available: $loadError');
    }
    return _instance ??= _Client._();
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
    List<Object?>? params,
    bool mariaDb,
  ) {
    int id = _nextId++;
    _Pending pending = _Pending(mariaDb);
    if (_pending.isEmpty) _port.keepIsolateAlive = true;
    _pending[id] = pending;
    int start = _len;
    try {
      _write(id, pool, tx, op, sql, params ?? const <Object?>[]);
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
        pending.completer.complete(_rows(b, d, body, pending.mariaDb));
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

  static MysqlNativeResult _rows(Uint8List b, ByteData d, int p, bool maria) {
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
                  : tag == _tLongText && maria
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
  _Pending(this.mariaDb);
  final bool mariaDb;
  final Completer<MysqlNativeResult> completer = Completer<MysqlNativeResult>();
}
