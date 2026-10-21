import 'dart:async';
import 'dart:convert';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart';

/// zone key to find the connections that have an open transaction
const Symbol _txKey = #doxMysqlTransaction;

/// mysql field types
const int _fieldTypeTiny = 0x01;
const int _fieldTypeJson = 0xf5;

/// driver for mysql and mariadb
class MysqlDriver extends DBDriver {
  dynamic conn;

  /// constructor
  MysqlDriver({required this.conn});

  /// ponytail: mysql1 has no pool, so each named connection is one
  /// database connection. while a transaction is open, other queries on
  /// it wait until the transaction ends. use a pool if throughput matters.
  static final Expando<Future<void>> _transactionDone = Expando<Future<void>>();

  /// true when the server is mariadb, saved per connection
  static final Expando<bool> _isMariaDb = Expando<bool>();

  @override
  Driver getName() {
    return Driver.mysql;
  }

  Future<MySqlConnection> _getConnection() async {
    /// if connection is future, we need to connect first.
    /// the connection is kept on this driver, so each named connection
    /// keeps its own database connection.
    if (conn is Future) {
      conn = await conn;
    }
    MySqlConnection c = conn;
    if (_isMariaDb[c] == null) {
      Results version = await c.query('SELECT VERSION()');
      _isMariaDb[c] =
          version.first.values?.first.toString().contains('MariaDB') ?? false;
    }

    /// wait for a transaction from outside this zone to end
    if (!_inTransaction(c)) {
      while (_transactionDone[c] != null) {
        await _transactionDone[c];
      }
    }
    return c;
  }

  bool _inTransaction(MySqlConnection c) {
    Set<MySqlConnection>? open = Zone.current[_txKey];
    return open?.contains(c) ?? false;
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    MySqlConnection c = await _getConnection();
    return await c.execute(
      query,
      primaryKey: primaryKey,
      substitutionValues: substitutionValues,
      isMariaDb: _isMariaDb[c] ?? false,
    );
  }

  /// only run query
  @override
  Future<void> execute(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    MySqlConnection c = await _getConnection();
    await c.run(query, substitutionValues: substitutionValues);
  }

  /// note: in mysql, schema changes (create/alter/drop table) commit the
  /// transaction right away, they can not be rolled back.
  @override
  Future<R> transaction<R>(Future<R> Function() callback) async {
    MySqlConnection c = await _getConnection();

    /// ponytail: a nested transaction joins the outer one (no savepoint)
    if (_inTransaction(c)) {
      return await callback();
    }

    /// another transaction can start while we wait, so check again
    while (_transactionDone[c] != null) {
      await _transactionDone[c];
    }
    Completer<void> done = Completer<void>();
    _transactionDone[c] = done.future;

    Set<MySqlConnection> open = <MySqlConnection>{
      ...?Zone.current[_txKey],
      c,
    };
    try {
      await c.query('START TRANSACTION');
      R result = await runZoned(
        callback,
        zoneValues: <Symbol, dynamic>{_txKey: open},
      );
      await c.query('COMMIT');
      return result;
    } catch (error) {
      await c.query('ROLLBACK');
      rethrow;
    } finally {
      _transactionDone[c] = null;
      done.complete();
    }
  }
}

/// extension on mysql connection
extension MySqlConnectionExecute on MySqlConnection {
  Future<List<Map<String, dynamic>>> execute(
    String sql, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
    bool isMariaDb = false,
  }) async {
    Results results = await run(sql, substitutionValues: substitutionValues);

    /// if result has last insert id, it mean insert query and need to return
    /// correct id
    if (results.insertId != null &&
        results.insertId! > 0 &&
        primaryKey != null) {
      return <Map<String, dynamic>>[
        <String, dynamic>{primaryKey: results.insertId}
      ];
    }

    /// normal get query which need to return list of map data
    /// similar to postgres
    return _parseResultToMap(results, isMariaDb);
  }

  Future<Results> run(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    Map<String, dynamic> values = substitutionValues ?? <String, dynamic>{};
    List<Object?> params = <Object?>[];

    /// mysql use `?` placeholder, so replace each known `@key` in the order
    /// it shows in the sql, and add its value in the same order.
    /// unknown `@word` (eg. 'a@b.com' inside a string) is kept as it is.
    sql = sql.replaceAllMapped(RegExp(r'@(\w+)'), (Match m) {
      String key = m.group(1)!;
      if (!values.containsKey(key)) {
        return m.group(0)!;
      }
      params.add(_toMysqlValue(values[key]));
      return '?';
    });
    return await query(sql, params);
  }

  /// json rule:
  /// - mysql: only JSON columns are decoded (objects and arrays).
  /// - mariadb: JSON is a LONGTEXT column, so the type is unknown.
  ///   text that starts with `{` or `[` and is valid json is decoded.
  /// TINYINT(1) (used by boolean()) is returned as bool.
  List<Map<String, dynamic>> _parseResultToMap(
      Results results, bool isMariaDb) {
    List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (ResultRow element in results) {
      Map<String, dynamic> data = <String, dynamic>{};
      for (int i = 0; i < results.fields.length; i++) {
        Field field = results.fields[i];
        dynamic value = element[i];

        if (value == null) {
          data[field.name!] = null;
          continue;
        }

        /// blob need to convert to string
        bool isBlob = value is Blob;
        if (isBlob) {
          value = value.toString();
        }

        if (field.type == _fieldTypeJson) {
          value = value is String ? jsonDecode(value) : value;
        } else if (isMariaDb && isBlob && _looksLikeJson(value)) {
          try {
            value = jsonDecode(value);
          } catch (error) {
            /// not json, keep the text
          }
        } else if (field.type == _fieldTypeTiny &&
            field.length == 1 &&
            value is int) {
          value = value != 0;
        }
        data[field.name!] = value;
      }
      result.add(data);
    }
    return result;
  }

  bool _looksLikeJson(String value) {
    String text = value.trimLeft();
    return text.startsWith('{') || text.startsWith('[');
  }

  Object? _toMysqlValue(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is bool) {
      return value ? 1 : 0;
    } else if (value is Map || value is List) {
      return jsonEncode(value);
    } else if (value is DateTime) {
      return value.toIso8601String().split('.').first;
    } else if (value.toString().endsWith('Z')) {
      try {
        return DateTime.parse(value).toIso8601String().split('.').first;
      } catch (error) {
        return value.toString();
      }
    }
    return value.toString();
  }
}
