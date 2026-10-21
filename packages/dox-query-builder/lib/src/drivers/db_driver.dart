import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:dox_query_builder/src/drivers/mysql_driver.dart';

enum Driver { postgres, mysql }

/// interface for database driver
abstract class DBDriver {
  Driver getName();

  /// run query and return map result
  Future<List<Map<String, dynamic>>> query(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  });

  /// run query, this function do not return any value
  Future<void> execute(String query,
      {Map<String, dynamic>? substitutionValues});

  /// run [callback] in one database transaction.
  /// commit when it ends, rollback when it throws.
  /// all queries inside [callback] (models too) use the transaction.
  Future<R> transaction<R>(Future<R> Function() callback);

  /// quote a table or column name, `"name"` on postgres and `` `name` `` on
  /// mysql. it handles `table.column`, `*` and `column as alias`.
  /// a value with `(` is a raw expression and is not changed.
  String wrap(String value) {
    value = value.trim();
    if (value.contains('(')) {
      return value;
    }
    List<String> alias = value.split(RegExp(r'\s+as\s+', caseSensitive: false));
    if (alias.length == 2) {
      return '${wrap(alias[0])} as ${_wrapPart(alias[1].trim())}';
    }
    return value.split('.').map(_wrapPart).join('.');
  }

  String _wrapPart(String part) {
    if (part == '*') {
      return part;
    }
    String q = getName() == Driver.mysql ? '`' : '"';
    return '$q${part.replaceAll(q, '$q$q')}$q';
  }
}

/// get database driver to run queries
DBDriver getDatabaseDriver(Driver driver, dynamic database) {
  /// checking validation for postgres connection
  if (driver == Driver.postgres) {
    return PostgresDriver(conn: database);
  }

  /// checking validation for mysql connection
  else if (driver == Driver.mysql) {
    return MysqlDriver(conn: database);
  }
  throw Exception('Invalid driver or not supported');
}
