import 'dart:convert';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart';

/// driver for postgres SQL
/// support PostgreSQLConnection and PgPool
class MysqlDriver extends DBDriver {
  dynamic conn;

  /// constructor
  MysqlDriver({required this.conn});

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
    return conn;
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
}

/// extension on mysql connection
extension MySqlConnectionExecute on MySqlConnection {
  Future<List<Map<String, dynamic>>> execute(
    String sql, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
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
    return _parseResultToMap(results);
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

  List<Map<String, dynamic>> _parseResultToMap(Results results) {
    List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (ResultRow element in results) {
      Map<String, dynamic> data = <String, dynamic>{};
      element.fields.forEach((String key, dynamic value) {
        /// blog need to convert to string
        if (value is Blob) {
          data[key] = value.toString();
        } else {
          data[key] = value;
        }

        /// if data is json string
        if (data[key].toString().startsWith('{"')) {
          try {
            /// convert to map
            data[key] = jsonDecode(data[key]);
          } catch (error) {
            /// ignore error
          }
        }
      });
      result.add(data);
    }
    return result;
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
