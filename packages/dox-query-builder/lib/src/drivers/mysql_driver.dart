import 'dart:convert';

import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:mysql1/mysql1.dart';

/// driver for postgres SQL
/// support PostgreSQLConnection and PgPool
class MysqlDriver extends DBDriver {
  final MySqlConnection conn;

  /// constructor
  MysqlDriver({required this.conn});

  @override
  Driver getName() {
    return Driver.mysql;
  }

  /// run query and return map result
  @override
  Future<T> execute<T>(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    dynamic result =
        await conn.run(query, substitutionValues: substitutionValues);
    return result as T;
  }

  /// run query and return map result
  @override
  Future<List<Map<String, dynamic>>> mappedResultsQuery(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  }) async {
    return await conn.execute(
      query,
      primaryKey: primaryKey,
      substitutionValues: substitutionValues,
    );
  }

  /// only run query
  @override
  Future<void> query(
    String query, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    await conn.run(query, substitutionValues: substitutionValues);
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
    List<Object> params = _substitutionValuesToList(substitutionValues);
    sql = sql.replaceAll(RegExp(r'@\w+'), '?');
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

  List<String> _substitutionValuesToList(dynamic params) {
    List<String> list = <String>[];
    if (params != null && (params as Map<String, dynamic>).isNotEmpty) {
      params.forEach((String key, dynamic value) {
        if (value is Map) {
          value = jsonEncode(value);
        } else if (value is DateTime) {
          value = value.toIso8601String().split('.').first;
        } else if (value.toString().endsWith('Z')) {
          try {
            value = DateTime.parse(value).toIso8601String().split('.').first;
          } catch (error) {
            value = value.toString();
          }
        } else {
          value = value.toString();
        }
        list.add(value);
      });
    }
    return list;
  }
}
